#import "SCIMediaQualityManager.h"

#import "SCIDashParser.h"
#import "SCIMediaFFmpeg.h"
#import "../../AssetUtils.h"
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../Gallery/SCIGallerySaveMetadata.h"
#import "../MediaPreview/SCIFullScreenMediaPlayer.h"
#import "../UI/SCISwitch.h"

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <objc/message.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, SCIMediaOptionKind) {
    SCIMediaOptionKindPhotoProgressive = 0,
    SCIMediaOptionKindVideoProgressive = 1,
    SCIMediaOptionKindVideoDashMerged = 2,
    SCIMediaOptionKindAudioDash = 3,
    SCIMediaOptionKindVideoDashOnly = 4,
};

@interface SCIMediaOption : NSObject
@property (nonatomic) SCIMediaOptionKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *qualityInfo;
@property (nonatomic, strong, nullable) NSURL *primaryURL;
@property (nonatomic, strong, nullable) NSURL *secondaryURL;
@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;
@property (nonatomic) NSInteger bandwidth;
@property (nonatomic) NSInteger audioBandwidth;
@property (nonatomic) NSInteger fileSizeBytes;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, copy, nullable) NSString *codec;
@property (nonatomic, copy, nullable) NSString *audioCodec;
@property (nonatomic) BOOL selectable;
@end

@implementation SCIMediaOption
@end

@interface SCIMediaOptionSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<SCIMediaOption *> *options;
@end

@implementation SCIMediaOptionSection
@end

@interface SCIMediaAnalysis : NSObject
@property (nonatomic) BOOL isVideo;
@property (nonatomic) BOOL ffmpegAvailable;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, strong, nullable) SCIMediaOption *fallbackOption;
@property (nonatomic, copy) NSArray<SCIMediaOption *> *photoOptions;
@property (nonatomic, copy) NSArray<SCIMediaOption *> *progressiveVideoOptions;
@property (nonatomic, copy) NSArray<SCIMediaOption *> *mergedDashOptions;
@property (nonatomic, copy) NSArray<SCIMediaOption *> *audioDashOptions;
@property (nonatomic, copy) NSArray<SCIMediaOption *> *videoDashOnlyOptions;
@property (nonatomic, copy) NSArray<SCIMediaOptionSection *> *videoSections;
@end

@implementation SCIMediaAnalysis
@end

static id SCIMediaObjectForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;
    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return nil;
    @try {
        return ((id (*)(id, SEL))objc_msgSend)(target, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id SCIMediaKVCObject(id target, NSString *key) {
    if (!target || key.length == 0) return nil;
    @try {
        return [target valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSNumber *SCIMediaNumberForSelector(id target, NSString *selectorName) {
    id value = SCIMediaObjectForSelector(target, selectorName);
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return @([value doubleValue]);
    }
    return nil;
}

static NSArray *SCIMediaArrayFromCollection(id value) {
    if ([value isKindOfClass:[NSArray class]]) return value;
    if ([value isKindOfClass:[NSOrderedSet class]]) return ((NSOrderedSet *)value).array;
    if ([value isKindOfClass:[NSSet class]]) return ((NSSet *)value).allObjects;
    return nil;
}

static NSURL *SCIMediaURLFromValue(id value) {
    if ([value isKindOfClass:[NSURL class]]) return value;
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return [NSURL URLWithString:value];
    }
    return nil;
}

static NSInteger SCIMediaIntegerValue(id value) {
    if ([value respondsToSelector:@selector(integerValue)]) {
        return [value integerValue];
    }
    return 0;
}

static double SCIMediaDoubleValue(id value) {
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return [value doubleValue];
    }
    return 0.0;
}

static id SCIMediaIvarValue(id target, const char *name) {
    if (!target || !name) return nil;
    @try {
        Ivar ivar = NULL;
        for (Class cls = object_getClass(target); cls && !ivar; cls = class_getSuperclass(cls)) {
            ivar = class_getInstanceVariable(cls, name);
        }
        if (!ivar) return nil;

        const char *encoding = ivar_getTypeEncoding(ivar);
        if (!encoding || encoding[0] != '@') {
            return nil;
        }

        return object_getIvar(target, ivar);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSNumber *SCIMediaFirstNumberFromValues(NSArray *values) {
    for (id value in values) {
        if ([value respondsToSelector:@selector(doubleValue)]) {
            double numericValue = [value doubleValue];
            if (numericValue > 0.0) {
                return @(numericValue);
            }
        }
    }
    return nil;
}

static NSNumber *SCIMediaExtractCandidateFileSize(id rawValue) {
    if ([rawValue respondsToSelector:@selector(longLongValue)] && [rawValue longLongValue] > 0) {
        return @([rawValue longLongValue]);
    }
    if ([rawValue isKindOfClass:[NSArray class]]) {
        for (id item in [(NSArray *)rawValue reverseObjectEnumerator]) {
            NSNumber *nested = SCIMediaExtractCandidateFileSize(item);
            if (nested.longLongValue > 0) {
                return nested;
            }
        }
    } else if ([rawValue isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary *)rawValue;
        NSNumber *nested = SCIMediaFirstNumberFromValues(@[
            dictionary[@"value"] ?: @0,
            dictionary[@"size"] ?: @0,
            dictionary[@"file_size"] ?: @0,
            dictionary[@"bytes"] ?: @0
        ]);
        if (nested.longLongValue > 0) {
            return nested;
        }
    }
    return nil;
}

static NSArray<NSDictionary *> *SCIMediaNormalizedAndSortedVariants(NSArray<NSDictionary *> *variants) {
    if (![variants isKindOfClass:[NSArray class]] || variants.count == 0) return @[];

    NSMutableArray<NSDictionary *> *deduped = [NSMutableArray array];
    NSMutableSet<NSString *> *seenURLs = [NSMutableSet set];
    for (NSDictionary *variant in variants) {
        NSURL *url = variant[@"url"];
        if (![url isKindOfClass:[NSURL class]] || url.absoluteString.length == 0 || [seenURLs containsObject:url.absoluteString]) {
            continue;
        }
        [seenURLs addObject:url.absoluteString];
        [deduped addObject:variant];
    }

    [deduped sortUsingComparator:^NSComparisonResult(NSDictionary *lhs, NSDictionary *rhs) {
        double lhsArea = [lhs[@"width"] doubleValue] * [lhs[@"height"] doubleValue];
        double rhsArea = [rhs[@"width"] doubleValue] * [rhs[@"height"] doubleValue];
        if (lhsArea > rhsArea) return NSOrderedAscending;
        if (lhsArea < rhsArea) return NSOrderedDescending;

        NSInteger lhsFileSize = [lhs[@"fileSizeBytes"] integerValue];
        NSInteger rhsFileSize = [rhs[@"fileSizeBytes"] integerValue];
        if (lhsFileSize > rhsFileSize) return NSOrderedAscending;
        if (lhsFileSize < rhsFileSize) return NSOrderedDescending;

        NSInteger lhsBandwidth = [lhs[@"bandwidth"] integerValue];
        NSInteger rhsBandwidth = [rhs[@"bandwidth"] integerValue];
        if (lhsBandwidth > rhsBandwidth) return NSOrderedAscending;
        if (lhsBandwidth < rhsBandwidth) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return deduped;
}

static id SCIMediaFieldCacheValue(id obj, NSString *key) {
    if (!obj || key.length == 0) return nil;
    Ivar fieldCacheIvar = NULL;
    @try {
        for (Class cls = [obj class]; cls && !fieldCacheIvar; cls = class_getSuperclass(cls)) {
            fieldCacheIvar = class_getInstanceVariable(cls, "_fieldCache");
        }
    } @catch (__unused NSException *exception) {
        return nil;
    }

    if (!fieldCacheIvar) return nil;

    id fieldCache = nil;
    @try {
        fieldCache = object_getIvar(obj, fieldCacheIvar);
    } @catch (__unused NSException *exception) {
        return nil;
    }
    if (![fieldCache isKindOfClass:[NSDictionary class]]) return nil;

    id value = ((NSDictionary *)fieldCache)[key];
    if (!value || [value isKindOfClass:[NSNull class]]) return nil;
    return value;
}

static NSString *SCIMediaDurationString(NSTimeInterval duration) {
    if (duration <= 0.0) return nil;
    NSInteger total = (NSInteger)llround(duration);
    NSInteger seconds = total % 60;
    NSInteger minutes = (total / 60) % 60;
    NSInteger hours = total / 3600;
    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
    }
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}

static NSString *SCIMediaBitrateString(NSInteger bandwidth) {
    if (bandwidth <= 0) return nil;
    if (bandwidth >= 1000000) {
        return [NSString stringWithFormat:@"%.1f Mbps", bandwidth / 1000000.0];
    }
    return [NSString stringWithFormat:@"%ld Kbps", (long)llround(bandwidth / 1000.0)];
}

static NSString *SCIMediaEstimatedSizeString(NSInteger bandwidth, NSTimeInterval duration) {
    if (bandwidth <= 0 || duration <= 0.0) return nil;
    double megabytes = ((double)bandwidth * duration) / 8.0 / 1000.0 / 1000.0;
    if (megabytes >= 100.0) {
        return [NSString stringWithFormat:@"%.0f MB", megabytes];
    }
    if (megabytes >= 10.0) {
        return [NSString stringWithFormat:@"%.1f MB", megabytes];
    }
    return [NSString stringWithFormat:@"%.2f MB", megabytes];
}

static NSString *SCIMediaCodecSummary(NSString *codec) {
    if (codec.length == 0) return nil;
    NSString *head = [codec componentsSeparatedByString:@","].firstObject ?: codec;
    return [head componentsSeparatedByString:@"."].firstObject ?: head;
}

static NSArray *SCIMediaImageVersionsFromPhoto(id photo) {
    if (!photo) return nil;

    NSArray *versions = SCIMediaArrayFromCollection(SCIMediaObjectForSelector(photo, @"imageVersions"));
    if (versions.count > 0) return versions;

    versions = SCIMediaArrayFromCollection([SCIUtils getIvarForObj:photo name:"_originalImageVersions"]);
    if (versions.count > 0) return versions;

    versions = SCIMediaArrayFromCollection(SCIMediaObjectForSelector(photo, @"imageVersionDictionaries"));
    if (versions.count > 0) return versions;

    versions = SCIMediaArrayFromCollection([SCIUtils getIvarForObj:photo name:"_imageVersions"]);
    if (versions.count > 0) return versions;

    versions = SCIMediaArrayFromCollection([SCIUtils getIvarForObj:photo name:"_imageVersionDictionaries"]);
    return versions.count > 0 ? versions : nil;
}

static NSArray *SCIMediaVideoVersionsFromVideo(id video) {
    if (!video) return nil;

    NSArray *versions = SCIMediaArrayFromCollection(SCIMediaObjectForSelector(video, @"videoVersions"));
    if (versions.count > 0) return versions;

    versions = SCIMediaArrayFromCollection(SCIMediaObjectForSelector(video, @"videoVersionDictionaries"));
    if (versions.count > 0) return versions;

    versions = SCIMediaArrayFromCollection([SCIUtils getIvarForObj:video name:"_videoVersions"]);
    if (versions.count > 0) return versions;

    versions = SCIMediaArrayFromCollection([SCIUtils getIvarForObj:video name:"_videoVersionDictionaries"]);
    return versions.count > 0 ? versions : nil;
}

static NSArray<NSDictionary *> *SCIMediaSortedVariantsFromVersions(NSArray *versions) {
    if (![versions isKindOfClass:[NSArray class]] || versions.count == 0) return @[];

    NSMutableArray<NSDictionary *> *variants = [NSMutableArray array];
    for (id version in versions) {
        id rawURL = nil;
        id widthValue = nil;
        id heightValue = nil;
        id bandwidthValue = nil;
        id fileSizeValue = nil;

        if ([version isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dictionary = (NSDictionary *)version;
            rawURL = dictionary[@"url"] ?: dictionary[@"urlString"];
            widthValue = SCIMediaFirstNumberFromValues(@[
                dictionary[@"width"] ?: @0,
                dictionary[@"original_width"] ?: @0,
                dictionary[@"config_width"] ?: @0,
                dictionary[@"source_width"] ?: @0,
                dictionary[@"max_width"] ?: @0,
                dictionary[@"cropped_width"] ?: @0
            ]);
            heightValue = SCIMediaFirstNumberFromValues(@[
                dictionary[@"height"] ?: @0,
                dictionary[@"original_height"] ?: @0,
                dictionary[@"config_height"] ?: @0,
                dictionary[@"source_height"] ?: @0,
                dictionary[@"max_height"] ?: @0,
                dictionary[@"cropped_height"] ?: @0
            ]);
            bandwidthValue = dictionary[@"bandwidth"];
            fileSizeValue = SCIMediaExtractCandidateFileSize(dictionary[@"file_size"] ?: dictionary[@"filesize"] ?: dictionary[@"estimated_file_size"] ?: dictionary[@"estimated_scans_sizes"] ?: dictionary[@"size"]);
        } else {
            rawURL = SCIMediaObjectForSelector(version, @"url")
                ?: SCIMediaObjectForSelector(version, @"urlString")
                ?: SCIMediaKVCObject(version, @"url")
                ?: SCIMediaKVCObject(version, @"urlString")
                ?: SCIMediaIvarValue(version, "_url")
                ?: SCIMediaIvarValue(version, "_urlString");
            widthValue = SCIMediaFirstNumberFromValues(@[
                SCIMediaNumberForSelector(version, @"width") ?: @0,
                SCIMediaNumberForSelector(version, @"originalWidth") ?: @0,
                SCIMediaNumberForSelector(version, @"configWidth") ?: @0,
                SCIMediaNumberForSelector(version, @"sourceWidth") ?: @0,
                SCIMediaNumberForSelector(version, @"maxWidth") ?: @0,
                SCIMediaKVCObject(version, @"width") ?: @0,
                SCIMediaKVCObject(version, @"originalWidth") ?: @0,
                SCIMediaKVCObject(version, @"configWidth") ?: @0,
                SCIMediaKVCObject(version, @"sourceWidth") ?: @0,
                SCIMediaKVCObject(version, @"maxWidth") ?: @0,
                SCIMediaIvarValue(version, "_width") ?: @0,
                SCIMediaIvarValue(version, "_originalWidth") ?: @0,
                SCIMediaIvarValue(version, "_configWidth") ?: @0
            ]);
            heightValue = SCIMediaFirstNumberFromValues(@[
                SCIMediaNumberForSelector(version, @"height") ?: @0,
                SCIMediaNumberForSelector(version, @"originalHeight") ?: @0,
                SCIMediaNumberForSelector(version, @"configHeight") ?: @0,
                SCIMediaNumberForSelector(version, @"sourceHeight") ?: @0,
                SCIMediaNumberForSelector(version, @"maxHeight") ?: @0,
                SCIMediaKVCObject(version, @"height") ?: @0,
                SCIMediaKVCObject(version, @"originalHeight") ?: @0,
                SCIMediaKVCObject(version, @"configHeight") ?: @0,
                SCIMediaKVCObject(version, @"sourceHeight") ?: @0,
                SCIMediaKVCObject(version, @"maxHeight") ?: @0,
                SCIMediaIvarValue(version, "_height") ?: @0,
                SCIMediaIvarValue(version, "_originalHeight") ?: @0,
                SCIMediaIvarValue(version, "_configHeight") ?: @0
            ]);
            bandwidthValue = SCIMediaNumberForSelector(version, @"bandwidth")
                ?: SCIMediaKVCObject(version, @"bandwidth")
                ?: SCIMediaIvarValue(version, "_bandwidth");
            fileSizeValue = SCIMediaExtractCandidateFileSize(
                SCIMediaObjectForSelector(version, @"fileSize")
                ?: SCIMediaObjectForSelector(version, @"estimatedFileSize")
                ?: SCIMediaObjectForSelector(version, @"estimatedScansSizes")
                ?: SCIMediaKVCObject(version, @"fileSize")
                ?: SCIMediaKVCObject(version, @"estimatedFileSize")
                ?: SCIMediaKVCObject(version, @"estimatedScansSizes")
                ?: SCIMediaKVCObject(version, @"size")
                ?: SCIMediaIvarValue(version, "_fileSize")
                ?: SCIMediaIvarValue(version, "_estimatedFileSize")
            );
        }

        NSURL *url = SCIMediaURLFromValue(rawURL);
        if (!url.absoluteString.length) continue;
        [variants addObject:@{
            @"url": url,
            @"width": @(SCIMediaDoubleValue(widthValue)),
            @"height": @(SCIMediaDoubleValue(heightValue)),
            @"bandwidth": @(SCIMediaIntegerValue(bandwidthValue)),
            @"fileSizeBytes": @(SCIMediaIntegerValue(fileSizeValue))
        }];
    }
    return SCIMediaNormalizedAndSortedVariants(variants);
}

static NSArray<NSDictionary *> *SCIMediaPhotoVariantDictionaries(id mediaObject) {
    NSMutableArray<NSDictionary *> *variants = [NSMutableArray array];
    id imageVersions = SCIMediaFieldCacheValue(mediaObject, @"image_versions2");
    id candidates = [imageVersions isKindOfClass:[NSDictionary class]] ? ((NSDictionary *)imageVersions)[@"candidates"] : nil;
    if (!candidates) {
        candidates = SCIMediaFieldCacheValue(mediaObject, @"candidates");
    }
    if ([candidates isKindOfClass:[NSArray class]]) {
        [variants addObjectsFromArray:SCIMediaSortedVariantsFromVersions(candidates)];
    }

    id photoObject = SCIMediaObjectForSelector(mediaObject, @"photo") ?: SCIMediaObjectForSelector(mediaObject, @"rawPhoto");
    if (photoObject) {
        [variants addObjectsFromArray:SCIMediaSortedVariantsFromVersions(SCIMediaImageVersionsFromPhoto(photoObject))];
    }
    return SCIMediaNormalizedAndSortedVariants(variants);
}

static NSArray<NSDictionary *> *SCIMediaVideoVariantDictionaries(id mediaObject) {
    NSMutableArray<NSDictionary *> *variants = [NSMutableArray array];
    id fieldCacheVariants = SCIMediaFieldCacheValue(mediaObject, @"video_versions");
    if ([fieldCacheVariants isKindOfClass:[NSArray class]]) {
        [variants addObjectsFromArray:SCIMediaSortedVariantsFromVersions(fieldCacheVariants)];
    }

    id videoObject = SCIMediaObjectForSelector(mediaObject, @"video") ?: SCIMediaObjectForSelector(mediaObject, @"rawVideo");
    if (videoObject) {
        [variants addObjectsFromArray:SCIMediaSortedVariantsFromVersions(SCIMediaVideoVersionsFromVideo(videoObject))];
    }
    return SCIMediaNormalizedAndSortedVariants(variants);
}

static NSTimeInterval SCIMediaDurationForObject(id mediaObject) {
    for (NSString *selectorName in @[@"videoDuration", @"videoDurationSeconds", @"duration", @"durationSeconds"]) {
        NSNumber *value = SCIMediaNumberForSelector(mediaObject, selectorName);
        if (value.doubleValue > 0.0) return value.doubleValue;
    }

    id videoObject = SCIMediaObjectForSelector(mediaObject, @"video");
    for (NSString *selectorName in @[@"duration", @"videoDuration", @"durationSeconds"]) {
        NSNumber *value = SCIMediaNumberForSelector(videoObject, selectorName);
        if (value.doubleValue > 0.0) return value.doubleValue;
    }

    id fieldValue = SCIMediaFieldCacheValue(mediaObject, @"video_duration");
    if ([fieldValue respondsToSelector:@selector(doubleValue)] && [fieldValue doubleValue] > 0.0) {
        return [fieldValue doubleValue];
    }

    return 0.0;
}

static NSString *SCIMediaResolutionLabel(NSInteger width, NSInteger height) {
    if (width <= 0 || height <= 0) return nil;
    NSInteger shortEdge = MIN(width, height);
    if (shortEdge > 0) {
        return [NSString stringWithFormat:@"%ldp", (long)shortEdge];
    }
    return [NSString stringWithFormat:@"%ld×%ld", (long)width, (long)height];
}

static NSString *SCIMediaSubtitle(NSInteger width, NSInteger height, NSInteger bandwidth, NSTimeInterval duration, NSString *codec, NSString *trailing) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (width > 0 && height > 0) {
        [parts addObject:[NSString stringWithFormat:@"%ld×%ld", (long)width, (long)height]];
    }
    NSString *bitrate = SCIMediaBitrateString(bandwidth);
    if (bitrate.length > 0) [parts addObject:bitrate];
    NSString *size = SCIMediaEstimatedSizeString(bandwidth, duration);
    if (size.length > 0) [parts addObject:size];
    NSString *codecSummary = SCIMediaCodecSummary(codec);
    if (codecSummary.length > 0) [parts addObject:codecSummary];
    if (trailing.length > 0) [parts addObject:trailing];
    return [parts componentsJoinedByString:@" • "];
}

static NSString *SCIMediaFileSizeString(NSInteger fileSizeBytes) {
    if (fileSizeBytes <= 0) return nil;
    return [NSByteCountFormatter stringFromByteCount:fileSizeBytes countStyle:NSByteCountFormatterCountStyleFile];
}

static NSString *SCIMediaPhotoSubtitle(NSInteger width, NSInteger height, NSInteger fileSizeBytes) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *size = SCIMediaFileSizeString(fileSizeBytes);
    if (size.length > 0) {
        [parts addObject:size];
    }
    return [parts componentsJoinedByString:@" • "];
}

static NSString *SCIMediaQualityInfoForOption(SCIMediaOption *option) {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (option.title.length > 0) [lines addObject:option.title];
    if (option.subtitle.length > 0) [lines addObject:option.subtitle];
    if (option.primaryURL.absoluteString.length > 0) [lines addObject:[NSString stringWithFormat:@"URL: %@", option.primaryURL.absoluteString]];
    if (option.secondaryURL.absoluteString.length > 0) [lines addObject:[NSString stringWithFormat:@"Audio URL: %@", option.secondaryURL.absoluteString]];
    return [lines componentsJoinedByString:@"\n"];
}

static UIImage *SCIMediaIcon(NSString *name, CGFloat pointSize) {
    return [SCIAssetUtils instagramIconNamed:name pointSize:pointSize renderingMode:UIImageRenderingModeAlwaysTemplate];
}

static CGFloat const kSCIMediaOptionIconPointSize = 22.0;
static CGFloat const kSCIMediaOptionControlSize = 40.0;

static NSArray<SCIMediaOption *> *SCIMediaBuildPhotoOptions(id mediaObject, NSURL *fallbackURL, NSTimeInterval duration) {
    NSMutableArray<SCIMediaOption *> *options = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (NSDictionary *variant in SCIMediaPhotoVariantDictionaries(mediaObject)) {
        NSURL *url = variant[@"url"];
        if (!url.absoluteString.length || [seen containsObject:url.absoluteString]) continue;
        [seen addObject:url.absoluteString];

        SCIMediaOption *option = [[SCIMediaOption alloc] init];
        option.kind = SCIMediaOptionKindPhotoProgressive;
        option.primaryURL = url;
        option.width = [variant[@"width"] integerValue];
        option.height = [variant[@"height"] integerValue];
        option.fileSizeBytes = [variant[@"fileSizeBytes"] integerValue];
        option.duration = duration;
        option.title = (option.width > 0 && option.height > 0)
            ? [NSString stringWithFormat:@"%ld×%ld", (long)option.width, (long)option.height]
            : (SCIMediaResolutionLabel(option.width, option.height) ?: @"Image");
        option.subtitle = SCIMediaPhotoSubtitle(option.width, option.height, option.fileSizeBytes);
        option.selectable = YES;
        option.qualityInfo = SCIMediaQualityInfoForOption(option);
        [options addObject:option];
    }

    if (fallbackURL.absoluteString.length > 0 && ![seen containsObject:fallbackURL.absoluteString]) {
        SCIMediaOption *fallback = [[SCIMediaOption alloc] init];
        fallback.kind = SCIMediaOptionKindPhotoProgressive;
        fallback.primaryURL = fallbackURL;
        fallback.title = @"Image";
        fallback.subtitle = @"Fallback source";
        fallback.selectable = YES;
        fallback.qualityInfo = SCIMediaQualityInfoForOption(fallback);
        [options addObject:fallback];
    }

    return options;
}

static NSArray<SCIMediaOption *> *SCIMediaBuildProgressiveVideoOptions(id mediaObject, NSURL *fallbackURL, NSTimeInterval duration) {
    NSMutableArray<SCIMediaOption *> *options = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (NSDictionary *variant in SCIMediaVideoVariantDictionaries(mediaObject)) {
        NSURL *url = variant[@"url"];
        if (!url.absoluteString.length || [seen containsObject:url.absoluteString]) continue;
        [seen addObject:url.absoluteString];

        SCIMediaOption *option = [[SCIMediaOption alloc] init];
        option.kind = SCIMediaOptionKindVideoProgressive;
        option.primaryURL = url;
        option.width = [variant[@"width"] integerValue];
        option.height = [variant[@"height"] integerValue];
        option.bandwidth = [variant[@"bandwidth"] integerValue];
        option.duration = duration;
        option.title = SCIMediaResolutionLabel(option.width, option.height) ?: @"Video";
        option.subtitle = SCIMediaSubtitle(option.width, option.height, option.bandwidth, duration, nil, @"progressive");
        option.selectable = YES;
        option.qualityInfo = SCIMediaQualityInfoForOption(option);
        [options addObject:option];
    }

    if (fallbackURL.absoluteString.length > 0 && ![seen containsObject:fallbackURL.absoluteString]) {
        SCIMediaOption *fallback = [[SCIMediaOption alloc] init];
        fallback.kind = SCIMediaOptionKindVideoProgressive;
        fallback.primaryURL = fallbackURL;
        fallback.duration = duration;
        fallback.title = @"Video";
        fallback.subtitle = @"Fallback progressive";
        fallback.selectable = YES;
        fallback.qualityInfo = SCIMediaQualityInfoForOption(fallback);
        [options addObject:fallback];
    }

    return options;
}

static NSArray<SCIDashRepresentation *> *SCIMediaRepresentationsForType(NSArray<SCIDashRepresentation *> *reps, NSString *type) {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(SCIDashRepresentation *evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        (void)bindings;
        return [evaluatedObject.contentType isEqualToString:type];
    }];
    return [reps filteredArrayUsingPredicate:predicate];
}

static NSArray<SCIMediaOption *> *SCIMediaBuildMergedDashOptions(NSArray<SCIDashRepresentation *> *videoReps,
                                                                 SCIDashRepresentation *bestAudio,
                                                                 NSTimeInterval duration,
                                                                 BOOL ffmpegAvailable) {
    NSMutableArray<SCIMediaOption *> *options = [NSMutableArray array];
    for (SCIDashRepresentation *videoRep in videoReps) {
        if (!videoRep.url) continue;
        SCIMediaOption *option = [[SCIMediaOption alloc] init];
        option.kind = SCIMediaOptionKindVideoDashMerged;
        option.primaryURL = videoRep.url;
        option.secondaryURL = bestAudio.url;
        option.width = videoRep.width;
        option.height = videoRep.height;
        option.bandwidth = videoRep.bandwidth;
        option.audioBandwidth = bestAudio.bandwidth;
        option.duration = duration;
        option.codec = videoRep.codecs;
        option.audioCodec = bestAudio.codecs;
        option.title = SCIMediaResolutionLabel(videoRep.width, videoRep.height) ?: @"Merged video";
        option.subtitle = SCIMediaSubtitle(videoRep.width,
                                           videoRep.height,
                                           videoRep.bandwidth + bestAudio.bandwidth,
                                           duration,
                                           videoRep.codecs,
                                           bestAudio.url ? @"video + audio" : @"video");
        option.selectable = ffmpegAvailable;
        option.qualityInfo = SCIMediaQualityInfoForOption(option);
        [options addObject:option];
    }
    return options;
}

static NSArray<SCIMediaOption *> *SCIMediaBuildVideoOnlyDashOptions(NSArray<SCIDashRepresentation *> *videoReps, NSTimeInterval duration) {
    NSMutableArray<SCIMediaOption *> *options = [NSMutableArray array];
    for (SCIDashRepresentation *videoRep in videoReps) {
        if (!videoRep.url) continue;
        SCIMediaOption *option = [[SCIMediaOption alloc] init];
        option.kind = SCIMediaOptionKindVideoDashOnly;
        option.primaryURL = videoRep.url;
        option.width = videoRep.width;
        option.height = videoRep.height;
        option.bandwidth = videoRep.bandwidth;
        option.duration = duration;
        option.codec = videoRep.codecs;
        option.title = SCIMediaResolutionLabel(videoRep.width, videoRep.height) ?: @"Video only";
        option.subtitle = SCIMediaSubtitle(videoRep.width, videoRep.height, videoRep.bandwidth, duration, videoRep.codecs, @"silent");
        option.selectable = YES;
        option.qualityInfo = SCIMediaQualityInfoForOption(option);
        [options addObject:option];
    }
    return options;
}

static NSArray<SCIMediaOption *> *SCIMediaBuildAudioDashOptions(NSArray<SCIDashRepresentation *> *audioReps, NSTimeInterval duration, BOOL includeAudio) {
    NSMutableArray<SCIMediaOption *> *options = [NSMutableArray array];
    for (SCIDashRepresentation *audioRep in audioReps) {
        if (!audioRep.url) continue;
        SCIMediaOption *option = [[SCIMediaOption alloc] init];
        option.kind = SCIMediaOptionKindAudioDash;
        option.primaryURL = audioRep.url;
        option.bandwidth = audioRep.bandwidth;
        option.duration = duration;
        option.codec = audioRep.codecs;
        option.title = @"Audio only";
        option.subtitle = SCIMediaSubtitle(0, 0, audioRep.bandwidth, duration, audioRep.codecs, nil);
        option.selectable = includeAudio;
        option.qualityInfo = SCIMediaQualityInfoForOption(option);
        [options addObject:option];
    }
    return options;
}

static NSInteger SCIMediaAudioCodecPreferenceScore(NSString *codec) {
    NSString *lower = codec.lowercaseString ?: @"";
    // Prefer AAC-LC and avoid xHE-AAC (mp4a.40.42), which fails on current FFmpeg build.
    if ([lower containsString:@"mp4a.40.2"]) return 300;
    if ([lower containsString:@"mp4a.40.5"]) return 220;
    if ([lower containsString:@"mp4a.40.29"]) return 200;
    if ([lower containsString:@"mp4a.40.42"]) return -1000;
    if ([lower containsString:@"mp4a"]) return 120;
    return 0;
}

static void SCIDebugModeLog(NSString *runId,
                            NSString *hypothesisId,
                            NSString *location,
                            NSString *message,
                            NSDictionary *data) {
    NSString *logPath = @"/Users/efi/dev/SCInsta/.cursor/debug-ec62e7.log";
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"sessionId"] = @"ec62e7";
    payload[@"runId"] = runId ?: @"unknown";
    payload[@"hypothesisId"] = hypothesisId ?: @"";
    payload[@"location"] = location ?: @"";
    payload[@"message"] = message ?: @"";
    payload[@"data"] = data ?: @{};
    payload[@"timestamp"] = @((long long)([[NSDate date] timeIntervalSince1970] * 1000.0));

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (jsonData.length == 0) return;

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (!handle) {
        [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    }
    if (!handle) return;

    @try {
        [handle seekToEndOfFile];
        [handle writeData:jsonData];
        [handle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    } @catch (__unused NSException *exception) {
        @try {
            [handle closeFile];
        } @catch (__unused NSException *closeException) {}
    }
}

static SCIDashRepresentation *SCIMediaBestMergeAudioRepresentation(NSArray<SCIDashRepresentation *> *audioReps) {
    if (audioReps.count == 0) return nil;

    NSArray<SCIDashRepresentation *> *sorted = [audioReps sortedArrayUsingComparator:^NSComparisonResult(SCIDashRepresentation *lhs, SCIDashRepresentation *rhs) {
        NSInteger lhsScore = SCIMediaAudioCodecPreferenceScore(lhs.codecs);
        NSInteger rhsScore = SCIMediaAudioCodecPreferenceScore(rhs.codecs);
        if (lhsScore > rhsScore) return NSOrderedAscending;
        if (lhsScore < rhsScore) return NSOrderedDescending;

        // Within same codec preference, pick higher bitrate.
        if (lhs.bandwidth > rhs.bandwidth) return NSOrderedAscending;
        if (lhs.bandwidth < rhs.bandwidth) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return sorted.firstObject;
}

static SCIMediaOptionSection *SCIMediaSection(NSString *title, NSArray<SCIMediaOption *> *options) {
    SCIMediaOptionSection *section = [[SCIMediaOptionSection alloc] init];
    section.title = title ?: @"";
    section.options = options ?: @[];
    return section;
}

static SCIMediaAnalysis *SCIMediaAnalyze(id mediaObject, NSURL *photoURL, NSURL *videoURL, DownloadAction action, BOOL includeAudioOptions) {
    (void)action;
    SCIMediaAnalysis *analysis = [[SCIMediaAnalysis alloc] init];
    analysis.ffmpegAvailable = [SCIMediaFFmpeg isAvailable];
    analysis.duration = SCIMediaDurationForObject(mediaObject);

    NSArray<SCIMediaOption *> *photoOptions = SCIMediaBuildPhotoOptions(mediaObject, photoURL, analysis.duration);
    NSArray<SCIMediaOption *> *progressiveVideoOptions = SCIMediaBuildProgressiveVideoOptions(mediaObject, videoURL, analysis.duration);

    NSString *manifest = [SCIDashParser dashManifestForMedia:mediaObject];
    NSArray<SCIDashRepresentation *> *representations = [SCIDashParser parseManifest:manifest ?: @""];
    NSArray<SCIDashRepresentation *> *dashVideo = SCIMediaRepresentationsForType(representations, @"video");
    NSArray<SCIDashRepresentation *> *dashAudio = SCIMediaRepresentationsForType(representations, @"audio");
    NSMutableArray<NSDictionary *> *audioCandidates = [NSMutableArray array];
    for (SCIDashRepresentation *rep in dashAudio) {
        [audioCandidates addObject:@{
            @"codec": rep.codecs ?: @"",
            @"bandwidth": @(rep.bandwidth)
        }];
    }
    SCIDashRepresentation *bestAudio = SCIMediaBestMergeAudioRepresentation(dashAudio);
    // #region agent log
    SCIDebugModeLog(@"media-analyze",
                    @"H5",
                    @"SCIMediaQualityManager.m:SCIMediaAnalyze",
                    @"audio candidate list for merge",
                    @{
                        @"count": @((long)dashAudio.count),
                        @"candidates": audioCandidates,
                        @"selectedCodec": bestAudio.codecs ?: @"",
                        @"selectedBandwidth": @(bestAudio.bandwidth)
                    });
    // #endregion
    // #region agent log
    SCILog(@"[DBG ec62e7 H5] selected merge-audio codec=%@ bw=%ld reps=%ld",
           bestAudio.codecs ?: @"",
           (long)bestAudio.bandwidth,
           (long)dashAudio.count);
    // #endregion

    NSArray<SCIMediaOption *> *mergedOptions = SCIMediaBuildMergedDashOptions(dashVideo, bestAudio, analysis.duration, analysis.ffmpegAvailable);
    NSArray<SCIMediaOption *> *videoOnlyOptions = SCIMediaBuildVideoOnlyDashOptions(dashVideo, analysis.duration);
    NSArray<SCIMediaOption *> *audioOptions = SCIMediaBuildAudioDashOptions(dashAudio, analysis.duration, includeAudioOptions);

    analysis.photoOptions = photoOptions;
    analysis.progressiveVideoOptions = progressiveVideoOptions;
    analysis.mergedDashOptions = mergedOptions;
    analysis.audioDashOptions = audioOptions;
    analysis.videoDashOnlyOptions = videoOnlyOptions;
    analysis.isVideo = (progressiveVideoOptions.count > 0 || mergedOptions.count > 0 || videoOnlyOptions.count > 0 || videoURL != nil);
    analysis.fallbackOption = analysis.isVideo ? progressiveVideoOptions.firstObject : photoOptions.firstObject;

    NSMutableArray<SCIMediaOptionSection *> *sections = [NSMutableArray array];
    if (progressiveVideoOptions.count > 0) [sections addObject:SCIMediaSection(@"Ready-to-play", progressiveVideoOptions)];
    if (mergedOptions.count > 0) [sections addObject:SCIMediaSection(@"Merge Video + Audio (DASH)", mergedOptions)];
    if (audioOptions.count > 0 && includeAudioOptions) [sections addObject:SCIMediaSection(@"Audio Only (DASH)", audioOptions)];
    if (videoOnlyOptions.count > 0) [sections addObject:SCIMediaSection(@"Video Only (DASH)", videoOnlyOptions)];
    analysis.videoSections = sections;

    return analysis;
}

static SCIMediaOption *SCIMediaTieredOption(NSArray<SCIMediaOption *> *options, NSString *quality) {
    if (options.count == 0) return nil;
    if ([quality isEqualToString:@"high"]) return options.firstObject;
    if ([quality isEqualToString:@"medium"]) return options[(options.count - 1) / 2];
    if ([quality isEqualToString:@"low"]) return options.lastObject;
    return nil;
}

static SCIMediaOption *SCIMediaResolveDefaultOption(SCIMediaAnalysis *analysis) {
    NSString *preferenceKey = analysis.isVideo ? @"media_video_quality_default" : @"media_photo_quality_default";
    NSString *quality = [SCIUtils getStringPref:preferenceKey];
    if (quality.length == 0) {
        quality = analysis.isVideo ? @"always_ask" : @"high";
    }

    if ([quality isEqualToString:@"always_ask"]) {
        return nil;
    }

    if (!analysis.isVideo) {
        return SCIMediaTieredOption(analysis.photoOptions, quality) ?: analysis.photoOptions.firstObject;
    }

    if ([quality isEqualToString:@"high_ignore_dash"]) {
        return analysis.progressiveVideoOptions.firstObject ?: analysis.mergedDashOptions.firstObject ?: analysis.videoDashOnlyOptions.firstObject;
    }

    if ([quality isEqualToString:@"high"]) {
        return analysis.mergedDashOptions.firstObject ?: analysis.progressiveVideoOptions.firstObject ?: analysis.videoDashOnlyOptions.firstObject;
    }

    NSArray<SCIMediaOption *> *preferred = analysis.mergedDashOptions.count > 0 ? analysis.mergedDashOptions : analysis.progressiveVideoOptions;
    return SCIMediaTieredOption(preferred, quality) ?: analysis.progressiveVideoOptions.firstObject ?: analysis.mergedDashOptions.firstObject ?: analysis.videoDashOnlyOptions.firstObject;
}

@interface SCIMediaSingleDownloadJob : NSObject <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, copy) void (^progressBlock)(double progress);
@property (nonatomic, copy) void (^completionBlock)(NSURL * _Nullable fileURL, NSError * _Nullable error);
@property (nonatomic, copy) NSString *fileExtension;
@end

@implementation SCIMediaSingleDownloadJob

- (void)startWithURL:(NSURL *)url
       defaultExtension:(NSString *)defaultExtension
               progress:(void (^)(double progress))progress
             completion:(void (^)(NSURL * _Nullable fileURL, NSError * _Nullable error))completion {
    self.progressBlock = progress;
    self.completionBlock = completion;
    self.fileExtension = url.pathExtension.length > 0 ? url.pathExtension.lowercaseString : (defaultExtension.length > 0 ? defaultExtension : @"mp4");
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:nil];
    self.task = [self.session downloadTaskWithURL:url];
    [self.task resume];
}

- (void)cancel {
    [self.task cancel];
    [self.session invalidateAndCancel];
    self.task = nil;
    self.session = nil;
}

- (NSURL *)cacheMoveURLForLocation:(NSURL *)location {
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject ?: NSTemporaryDirectory();
    NSURL *destination = [[NSURL fileURLWithPath:cachePath isDirectory:YES] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, self.fileExtension ?: @"mp4"]];
    [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:destination error:&error]) {
        return nil;
    }
    return destination;
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
 totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    (void)session;
    (void)downloadTask;
    if (totalBytesExpectedToWrite <= 0) return;
    double progress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
    if (self.progressBlock) {
        self.progressBlock(MAX(0.0, MIN(1.0, progress)));
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    (void)session;
    (void)downloadTask;
    NSURL *destination = [self cacheMoveURLForLocation:location];
    if (!destination && self.completionBlock) {
        self.completionBlock(nil, [SCIUtils errorWithDescription:@"Failed to move downloaded media"]);
    } else if (self.completionBlock) {
        self.completionBlock(destination, nil);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    (void)session;
    (void)task;
    if (!error) return;
    if (self.completionBlock) {
        self.completionBlock(nil, error);
    }
}

@end

@interface _SCIMediaOptionCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *previewButton;
@property (nonatomic, strong) UIButton *menuButton;
@end

@implementation _SCIMediaOptionCell

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SCIUtils SCIColor_InstagramPressedBackground];
    return view;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.selectedBackgroundView = [self selectionBackgroundView];

    _previewButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _previewButton.translatesAutoresizingMaskIntoConstraints = NO;
    _previewButton.tintColor = [SCIUtils SCIColor_InstagramPrimaryText];
    [self.contentView addSubview:_previewButton];

    _menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _menuButton.translatesAutoresizingMaskIntoConstraints = NO;
    _menuButton.tintColor = [SCIUtils SCIColor_InstagramSecondaryText];
    _menuButton.showsMenuAsPrimaryAction = YES;
    [_menuButton setImage:SCIMediaIcon(@"more", kSCIMediaOptionIconPointSize) forState:UIControlStateNormal];
    [self.contentView addSubview:_menuButton];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont monospacedDigitSystemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    [self.contentView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [UIFont systemFontOfSize:11.0];
    _subtitleLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
    _subtitleLabel.numberOfLines = 2;
    [self.contentView addSubview:_subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_previewButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12.0],
        [_previewButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_previewButton.widthAnchor constraintEqualToConstant:kSCIMediaOptionControlSize],
        [_previewButton.heightAnchor constraintEqualToConstant:kSCIMediaOptionControlSize],

        [_menuButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8.0],
        [_menuButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_menuButton.widthAnchor constraintEqualToConstant:kSCIMediaOptionControlSize],
        [_menuButton.heightAnchor constraintEqualToConstant:kSCIMediaOptionControlSize],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_previewButton.trailingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_menuButton.leadingAnchor constant:-10.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_menuButton.leadingAnchor constant:-10.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2.0],
        [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10.0]
    ]];

    return self;
}

@end

@interface SCIMediaTextFieldViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, copy) NSString *defaultsKey;
@property (nonatomic, copy) NSString *placeholderText;
@property (nonatomic, copy) NSString *footerText;
@property (nonatomic, strong) UITextField *textField;
@end

@implementation SCIMediaTextFieldViewController

- (instancetype)initWithTitle:(NSString *)title defaultsKey:(NSString *)defaultsKey placeholder:(NSString *)placeholder footer:(NSString *)footer {
    self = [super init];
    if (!self) return nil;
    self.title = title;
    self.defaultsKey = defaultsKey;
    self.placeholderText = placeholder ?: @"";
    self.footerText = footer ?: @"";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];

    UILabel *footerLabel = [[UILabel alloc] init];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
    footerLabel.numberOfLines = 0;
    footerLabel.font = [UIFont systemFontOfSize:13.0];
    footerLabel.text = self.footerText;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    card.layer.cornerRadius = 14.0;

    self.textField = [[UITextField alloc] init];
    self.textField.translatesAutoresizingMaskIntoConstraints = NO;
    self.textField.borderStyle = UITextBorderStyleRoundedRect;
    self.textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textField.placeholder = self.placeholderText;
    self.textField.delegate = self;
    self.textField.text = [SCIUtils getStringPref:self.defaultsKey];

    [card addSubview:self.textField];
    [self.view addSubview:card];
    [self.view addSubview:footerLabel];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24.0],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],

        [self.textField.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [self.textField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.textField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [self.textField.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],

        [footerLabel.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:16.0],
        [footerLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [footerLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor]
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save"
                                                                               style:UIBarButtonItemStyleDone
                                                                              target:self
                                                                              action:@selector(saveTapped)];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.textField becomeFirstResponder];
}

- (void)saveTapped {
    NSString *value = [self.textField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [[NSUserDefaults standardUserDefaults] setObject:value ?: @"" forKey:self.defaultsKey];
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    (void)textField;
    [self saveTapped];
    return YES;
}

@end

@interface SCIMediaEncodingSettingsViewController : UITableViewController
@end

@implementation SCIMediaEncodingSettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) return nil;
    self.title = @"Encoding Settings";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
}

- (NSArray<NSString *> *)activeRows {
    NSMutableArray<NSString *> *rows = [NSMutableArray array];
    if ([SCIUtils getBoolPref:@"media_advanced_encoding_enabled"]) {
        // Advanced mode: toggle first, then codec-specific controls.
        [rows addObject:@"advanced"];
        [rows addObjectsFromArray:@[
            @"codec", @"preset", @"profile", @"level", @"crf", @"video_bitrate", @"max_resolution",
            @"audio_bitrate", @"audio_channels", @"pixel_format", @"faststart"
        ]];
    } else {
        // Default mode: speed picker + advanced toggle
        [rows addObject:@"speed"];
        [rows addObject:@"advanced"];
    }
    return rows;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return self.activeRows.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    if ([SCIUtils getBoolPref:@"media_advanced_encoding_enabled"]) {
        return @"Advanced Encoding exposes codec, preset, bitrate, CRF, resolution, and audio overrides. In advanced mode, the selected video codec is used for DASH merges while audio remains copied.";
    }
    return @"Controls the default DASH bitrate tier. Ultrafast uses the smallest output, while Slower uses the largest and highest-quality output.";
}

- (NSString *)valueLabelForRow:(NSString *)row {
    NSDictionary<NSString *, NSString *> *menuLabels = @{
        @"medium": @"Medium",
        @"low": @"Low",
        @"high": @"High",
        @"ultrafast": @"Ultrafast",
        @"superfast": @"Superfast",
        @"veryfast": @"Very Fast",
        @"faster": @"Faster",
        @"fast": @"Fast",
        @"slow": @"Slow",
        @"slower": @"Slower",
        @"veryslow": @"Very Slow",
        @"videotoolbox": @"VideoToolbox",
        @"libx264": @"libx264",
        @"auto": @"Auto",
        @"baseline": @"Baseline",
        @"main": @"Main",
        @"original": @"Original",
        @"480": @"480p",
        @"720": @"720p",
        @"1080": @"1080p",
        @"default": @"Default",
        @"yuv420p": @"yuv420p",
        @"nv12": @"nv12",
        @"mono": @"Mono",
        @"stereo": @"Stereo"
    };

    if ([row isEqualToString:@"advanced"]) {
        return [SCIUtils getBoolPref:@"media_advanced_encoding_enabled"] ? @"On" : @"Off";
    }
    if ([row isEqualToString:@"faststart"]) {
        return [SCIUtils getBoolPref:@"media_encoding_faststart"] ? @"On" : @"Off";
    }
    if ([row isEqualToString:@"crf"]) {
        NSString *value = [SCIUtils getStringPref:@"media_encoding_crf"];
        return value.length > 0 ? value : @"Auto";
    }
    if ([row isEqualToString:@"video_bitrate"]) {
        NSString *value = [SCIUtils getStringPref:@"media_encoding_video_bitrate_kbps"];
        return value.length > 0 ? [NSString stringWithFormat:@"%@ kbps", value] : @"Auto";
    }
    if ([row isEqualToString:@"audio_bitrate"]) {
        NSString *value = [SCIUtils getStringPref:@"media_encoding_audio_bitrate_kbps"];
        return value.length > 0 ? [NSString stringWithFormat:@"%@ kbps", value] : @"128 kbps";
    }

    NSDictionary<NSString *, NSString *> *prefKeys = @{
        @"speed": @"media_encoding_speed",
        @"codec": @"media_encoding_video_codec",
        @"preset": @"media_encoding_preset",
        @"profile": @"media_encoding_h264_profile",
        @"level": @"media_encoding_h264_level",
        @"max_resolution": @"media_encoding_max_resolution",
        @"audio_channels": @"media_encoding_audio_channels",
        @"pixel_format": @"media_encoding_pixel_format"
    };

    NSString *value = [SCIUtils getStringPref:prefKeys[row]];
    NSString *label = menuLabels[value];
    return label.length > 0 ? label : value.capitalizedString;
}

- (UIMenu *)menuForRow:(NSString *)row {
    NSArray<NSDictionary *> *items = nil;
    NSString *prefKey = nil;
    if ([row isEqualToString:@"speed"]) {
        prefKey = @"media_encoding_speed";
        items = @[
            @{@"value": @"ultrafast", @"label": @"Ultrafast"},
            @{@"value": @"faster", @"label": @"Faster"},
            @{@"value": @"medium", @"label": @"Medium"},
            @{@"value": @"slower", @"label": @"Slower"},
        ];
    } else if ([row isEqualToString:@"codec"]) {
        prefKey = @"media_encoding_video_codec";
        items = @[@{@"value": @"videotoolbox", @"label": @"VideoToolbox"}, @{@"value": @"libx264", @"label": @"libx264"}];
    } else if ([row isEqualToString:@"preset"]) {
        prefKey = @"media_encoding_preset";
        items = @[
            @{@"value": @"ultrafast", @"label": @"Ultrafast"},
            @{@"value": @"superfast", @"label": @"Superfast"},
            @{@"value": @"veryfast", @"label": @"Very Fast"},
            @{@"value": @"faster", @"label": @"Faster"},
            @{@"value": @"fast", @"label": @"Fast"},
            @{@"value": @"medium", @"label": @"Medium"},
            @{@"value": @"slow", @"label": @"Slow"},
            @{@"value": @"slower", @"label": @"Slower"},
            @{@"value": @"veryslow", @"label": @"Very Slow"},
        ];
    } else if ([row isEqualToString:@"profile"]) {
        prefKey = @"media_encoding_h264_profile";
        items = @[@{@"value": @"baseline", @"label": @"Baseline"}, @{@"value": @"main", @"label": @"Main"}, @{@"value": @"high", @"label": @"High"}];
    } else if ([row isEqualToString:@"level"]) {
        prefKey = @"media_encoding_h264_level";
        items = @[@{@"value": @"auto", @"label": @"Auto"}, @{@"value": @"3.1", @"label": @"3.1"}, @{@"value": @"4.0", @"label": @"4.0"}, @{@"value": @"4.1", @"label": @"4.1"}, @{@"value": @"5.0", @"label": @"5.0"}];
    } else if ([row isEqualToString:@"max_resolution"]) {
        prefKey = @"media_encoding_max_resolution";
        items = @[@{@"value": @"original", @"label": @"Original"}, @{@"value": @"480", @"label": @"480p"}, @{@"value": @"720", @"label": @"720p"}, @{@"value": @"1080", @"label": @"1080p"}];
    } else if ([row isEqualToString:@"audio_channels"]) {
        prefKey = @"media_encoding_audio_channels";
        items = @[@{@"value": @"original", @"label": @"Original"}, @{@"value": @"stereo", @"label": @"Stereo"}, @{@"value": @"mono", @"label": @"Mono"}];
    } else if ([row isEqualToString:@"pixel_format"]) {
        prefKey = @"media_encoding_pixel_format";
        items = @[@{@"value": @"default", @"label": @"Default"}, @{@"value": @"yuv420p", @"label": @"yuv420p"}, @{@"value": @"nv12", @"label": @"nv12"}];
    }

    if (items.count == 0 || prefKey.length == 0) return nil;

    NSString *currentValue = [SCIUtils getStringPref:prefKey];
    NSMutableArray<UIMenuElement *> *children = [NSMutableArray array];
    for (NSDictionary *item in items) {
        NSString *value = item[@"value"];
        NSString *label = item[@"label"];
        UIAction *action = [UIAction actionWithTitle:label image:nil identifier:nil handler:^(__unused UIAction *action) {
            [[NSUserDefaults standardUserDefaults] setObject:value forKey:prefKey];
            [self.tableView reloadData];
        }];
        action.state = [currentValue isEqualToString:value] ? UIMenuElementStateOn : UIMenuElementStateOff;
        [children addObject:action];
    }
    return [UIMenu menuWithChildren:children];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *row = self.activeRows[indexPath.row];

    // --- Toggle rows (advanced, faststart) ---
    if ([row isEqualToString:@"advanced"] || [row isEqualToString:@"faststart"]) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
        cell.textLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
        cell.detailTextLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
        SCISwitch *toggle = [[SCISwitch alloc] init];
        toggle.on = [row isEqualToString:@"advanced"] ? [SCIUtils getBoolPref:@"media_advanced_encoding_enabled"] : [SCIUtils getBoolPref:@"media_encoding_faststart"];
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        toggle.tag = [row isEqualToString:@"advanced"] ? 1 : 2;
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = [row isEqualToString:@"advanced"] ? @"Advanced Encoding" : @"Fast Start";
        cell.detailTextLabel.text = [row isEqualToString:@"advanced"]
            ? @"Override the default merge tuning with manual codec and bitrate controls."
            : @"Move MP4 metadata to the front for faster opening and sharing.";
        return cell;
    }

    // --- Text input rows (CRF, video bitrate, audio bitrate) ---
    if ([row isEqualToString:@"crf"] || [row isEqualToString:@"video_bitrate"] || [row isEqualToString:@"audio_bitrate"]) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
        cell.textLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        NSDictionary<NSString *, NSString *> *titles = @{@"crf": @"CRF", @"video_bitrate": @"Video Bitrate", @"audio_bitrate": @"Audio Bitrate"};
        NSDictionary<NSString *, NSString *> *prefKeys = @{@"crf": @"media_encoding_crf", @"video_bitrate": @"media_encoding_video_bitrate_kbps", @"audio_bitrate": @"media_encoding_audio_bitrate_kbps"};
        NSDictionary<NSString *, NSString *> *placeholders = @{@"crf": @"Auto", @"video_bitrate": @"Auto", @"audio_bitrate": @"128"};

        cell.textLabel.text = titles[row];

        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 34)];
        textField.textAlignment = NSTextAlignmentRight;
        textField.font = [UIFont systemFontOfSize:16];
        textField.textColor = [SCIUtils SCIColor_Primary];
        textField.placeholder = placeholders[row];
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [SCIUtils getStringPref:prefKeys[row]];
        textField.accessibilityIdentifier = prefKeys[row];
        [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingDidEnd];
        cell.accessoryView = textField;
        return cell;
    }

    // --- Menu picker rows (no detailTextLabel — value shown only in the button to avoid duplicate) ---
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.textLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSDictionary<NSString *, NSString *> *titles = @{
        @"speed": @"Encoding Speed",
        @"codec": @"Video Codec",
        @"preset": @"Preset",
        @"profile": @"H.264 Profile",
        @"level": @"H.264 Level",
        @"max_resolution": @"Max Resolution",
        @"audio_channels": @"Audio Channels",
        @"pixel_format": @"Pixel Format"
    };
    cell.textLabel.text = titles[row];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:[self valueLabelForRow:row] forState:UIControlStateNormal];
    [button sizeToFit];
    button.menu = [self menuForRow:row];
    button.showsMenuAsPrimaryAction = YES;
    cell.accessoryView = button;
    return cell;
}

- (void)textFieldDidChange:(UITextField *)textField {
    NSString *prefKey = textField.accessibilityIdentifier;
    if (prefKey.length > 0) {
        NSString *value = [textField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [[NSUserDefaults standardUserDefaults] setObject:value ?: @"" forKey:prefKey];
    }
}

- (void)toggleChanged:(UISwitch *)toggle {
    if (toggle.tag == 1) {
        [[NSUserDefaults standardUserDefaults] setBool:toggle.isOn forKey:@"media_advanced_encoding_enabled"];
        [self.tableView reloadData];
    } else if (toggle.tag == 2) {
        [[NSUserDefaults standardUserDefaults] setBool:toggle.isOn forKey:@"media_encoding_faststart"];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

@end

@interface SCIMediaOptionsSheetViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SCIMediaAnalysis *analysis;
@property (nonatomic) DownloadAction action;
@property (nonatomic, copy) void (^selectionHandler)(SCIMediaOption *option);
@end

@implementation SCIMediaOptionsSheetViewController

- (instancetype)initWithAnalysis:(SCIMediaAnalysis *)analysis action:(DownloadAction)action selectionHandler:(void (^)(SCIMediaOption *option))selectionHandler {
    self = [super init];
    if (!self) return nil;
    self.analysis = analysis;
    self.action = action;
    self.selectionHandler = selectionHandler;
    self.title = analysis.isVideo ? @"Video Quality" : @"Photo Quality";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 76.0;
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
    [self.tableView registerClass:_SCIMediaOptionCell.class forCellReuseIdentifier:@"option"];
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeTapped)];
}

- (NSArray<SCIMediaOptionSection *> *)sections {
    if (self.analysis.isVideo) {
        return self.analysis.videoSections;
    }
    return self.analysis.photoOptions.count > 0 ? @[SCIMediaSection(@"Photos", self.analysis.photoOptions)] : @[];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].options.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return self.sections[section].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    SCIMediaOptionSection *infoSection = self.sections[section];
    if ([infoSection.title isEqualToString:@"Merge Video + Audio (DASH)"] && !self.analysis.ffmpegAvailable) {
        return @"FFmpegKit is not available in the active build, so merged DASH rows are disabled. View Encoding Logs includes the loader failure details.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    _SCIMediaOptionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"option" forIndexPath:indexPath];
    SCIMediaOption *option = self.sections[indexPath.section].options[indexPath.row];
    cell.titleLabel.text = option.title;
    cell.subtitleLabel.text = option.subtitle;
    cell.previewButton.tag = (indexPath.section << 16) | indexPath.row;
    [cell.previewButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.previewButton addTarget:self action:@selector(previewTapped:) forControlEvents:UIControlEventTouchUpInside];
    NSString *previewIconName = option.kind == SCIMediaOptionKindPhotoProgressive ? @"photo" : option.kind == SCIMediaOptionKindAudioDash ? @"audio" : @"video";
    [cell.previewButton setImage:SCIMediaIcon(previewIconName, kSCIMediaOptionIconPointSize) forState:UIControlStateNormal];
    cell.menuButton.menu = [self menuForOption:option];
    cell.userInteractionEnabled = YES;
    cell.titleLabel.alpha = option.selectable ? 1.0 : 0.65;
    cell.subtitleLabel.alpha = option.selectable ? 1.0 : 0.65;
    cell.accessoryType = option.selectable ? UITableViewCellAccessoryNone : UITableViewCellAccessoryNone;
    return cell;
}

- (void)previewTapped:(UIButton *)button {
    NSInteger sectionIndex = (button.tag >> 16) & 0xFFFF;
    NSInteger rowIndex = button.tag & 0xFFFF;
    if (sectionIndex >= self.sections.count) return;
    SCIMediaOptionSection *section = self.sections[sectionIndex];
    if (rowIndex >= section.options.count) return;
    [self previewOption:section.options[rowIndex]];
}

- (void)previewOption:(SCIMediaOption *)option {
    if (option.kind == SCIMediaOptionKindPhotoProgressive) {
        [SCIFullScreenMediaPlayer showRemoteImageURL:option.primaryURL];
        return;
    }

    AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
    controller.player = [AVPlayer playerWithURL:option.primaryURL];
    [self presentViewController:controller animated:YES completion:^{
        [controller.player play];
    }];
}

- (UIMenu *)menuForOption:(SCIMediaOption *)option {
    NSMutableArray<UIMenuElement *> *children = [NSMutableArray array];

    if (option.primaryURL.absoluteString.length > 0) {
        NSString *title = option.kind == SCIMediaOptionKindPhotoProgressive ? @"Copy URL" : option.kind == SCIMediaOptionKindAudioDash ? @"Copy Audio URL" : @"Copy Video URL";
        [children addObject:[UIAction actionWithTitle:title image:SCIMediaIcon(@"link", kSCIMediaOptionIconPointSize) identifier:nil handler:^(__unused UIAction *action) {
            [UIPasteboard generalPasteboard].string = option.primaryURL.absoluteString;
            [SCIUtils showToastForDuration:1.5 title:@"URL copied"];
        }]];
    }

    if (option.secondaryURL.absoluteString.length > 0) {
        [children addObject:[UIAction actionWithTitle:@"Copy Audio URL" image:SCIMediaIcon(@"audio", kSCIMediaOptionIconPointSize) identifier:nil handler:^(__unused UIAction *action) {
            [UIPasteboard generalPasteboard].string = option.secondaryURL.absoluteString;
            [SCIUtils showToastForDuration:1.5 title:@"Audio URL copied"];
        }]];
    }

    [children addObject:[UIAction actionWithTitle:@"Copy Quality Info" image:SCIMediaIcon(@"copy", kSCIMediaOptionIconPointSize) identifier:nil handler:^(__unused UIAction *action) {
        [UIPasteboard generalPasteboard].string = option.qualityInfo ?: @"";
        [SCIUtils showToastForDuration:1.5 title:@"Quality info copied"];
    }]];

    if (option.kind == SCIMediaOptionKindPhotoProgressive) {
        [children addObject:[UIAction actionWithTitle:@"View Image" image:SCIMediaIcon(@"photo", kSCIMediaOptionIconPointSize) identifier:nil handler:^(__unused UIAction *action) {
            [SCIFullScreenMediaPlayer showRemoteImageURL:option.primaryURL];
        }]];
    } else {
        NSString *playTitle = option.kind == SCIMediaOptionKindAudioDash ? @"Play Audio" : @"Play Video";
        [children addObject:[UIAction actionWithTitle:playTitle image:SCIMediaIcon(option.kind == SCIMediaOptionKindAudioDash ? @"audio" : @"video", kSCIMediaOptionIconPointSize) identifier:nil handler:^(__unused UIAction *action) {
            [self previewOption:option];
        }]];

        [children addObject:[UIAction actionWithTitle:@"Extract Thumbnail" image:SCIMediaIcon(@"photo_gallery", kSCIMediaOptionIconPointSize) identifier:nil handler:^(__unused UIAction *action) {
            AVAsset *asset = [AVURLAsset URLAssetWithURL:option.primaryURL options:nil];
            AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            generator.appliesPreferredTrackTransform = YES;
            CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(MAX(option.duration > 0.5 ? MIN(1.0, option.duration / 3.0) : 0.0, 0.0), 600) actualTime:nil error:nil];
            if (!imageRef) {
                [SCIUtils showToastForDuration:2.0 title:@"Unable to extract thumbnail"];
                return;
            }
            UIImage *image = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
            [SCIFullScreenMediaPlayer showImage:image];
        }]];
    }

    return [UIMenu menuWithChildren:children];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SCIMediaOption *option = self.sections[indexPath.section].options[indexPath.row];
    if (!option.selectable) {
        NSString *reason = option.kind == SCIMediaOptionKindAudioDash ? @"Audio-only export is currently limited to Share." : @"This option requires FFmpegKit in the active build.";
        [SCIUtils showToastForDuration:2.0 title:@"Option unavailable" subtitle:reason];
        return;
    }
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.selectionHandler) {
            self.selectionHandler(option);
        }
    }];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

static void SCIMediaPresentOptionsSheet(UIViewController *presenter, UIView *sourceView, SCIMediaAnalysis *analysis, DownloadAction action, void (^selectionHandler)(SCIMediaOption *option)) {
    SCIMediaOptionsSheetViewController *controller = [[SCIMediaOptionsSheetViewController alloc] initWithAnalysis:analysis action:action selectionHandler:selectionHandler];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = nav.sheetPresentationController;
    if (sheet) {
        sheet.detents = @[
            [UISheetPresentationControllerDetent mediumDetent]
        ];
        sheet.prefersGrabberVisible = YES;
        sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
    }
    if (nav.popoverPresentationController && sourceView) {
        nav.popoverPresentationController.sourceView = sourceView;
        nav.popoverPresentationController.sourceRect = sourceView.bounds;
    }
    [presenter presentViewController:nav animated:YES completion:nil];
}

static NSString *SCIMediaExtensionForOption(SCIMediaOption *option) {
    switch (option.kind) {
        case SCIMediaOptionKindPhotoProgressive:
            return option.primaryURL.pathExtension.length > 0 ? option.primaryURL.pathExtension : @"jpg";
        case SCIMediaOptionKindAudioDash:
            return @"m4a";
        default:
            return @"mp4";
    }
}

static void SCIMediaCopyLocalFileToPasteboard(NSURL *fileURL) {
    if (!fileURL) {
        [SCIUtils showToastForDuration:2.0 title:@"Nothing to copy" subtitle:nil iconResource:@"error_filled" tone:SCIFeedbackPillToneError];
        return;
    }

    NSString *extension = fileURL.pathExtension.lowercaseString;
    if ([extension isEqualToString:@"m4a"] || [extension isEqualToString:@"aac"] || [extension isEqualToString:@"mp3"]) {
        NSData *data = [NSData dataWithContentsOfURL:fileURL];
        if (data) {
            [[UIPasteboard generalPasteboard] setData:data forPasteboardType:@"public.audio"];
            [SCIUtils showToastForDuration:1.5 title:@"Copied audio to clipboard" subtitle:nil iconResource:@"circle_check_filled" tone:SCIFeedbackPillToneSuccess];
            return;
        }
    } else if ([[SCIDownloadDelegate class] isVideoFileAtURL:fileURL]) {
        NSData *data = [NSData dataWithContentsOfURL:fileURL];
        if (data) {
            [[UIPasteboard generalPasteboard] setData:data forPasteboardType:@"public.mpeg-4"];
            [SCIUtils showToastForDuration:1.5 title:@"Copied video to clipboard" subtitle:nil iconResource:@"circle_check_filled" tone:SCIFeedbackPillToneSuccess];
            return;
        }
    } else {
        NSData *imageData = [NSData dataWithContentsOfURL:fileURL];
        UIImage *image = imageData ? [UIImage imageWithData:imageData] : nil;
        if (image) {
            [[UIPasteboard generalPasteboard] setImage:image];
            [SCIUtils showToastForDuration:1.5 title:@"Copied photo to clipboard" subtitle:nil iconResource:@"circle_check_filled" tone:SCIFeedbackPillToneSuccess];
            return;
        }
    }

    [SCIUtils showToastForDuration:2.0 title:@"Copy failed" subtitle:@"Unable to read the selected file." iconResource:@"error_filled" tone:SCIFeedbackPillToneError];
}

static NSString *SCIMediaSuggestedBasename(id mediaObject, SCIMediaOption *option) {
    NSString *identifier = nil;
    for (NSString *selectorName in @[@"pk", @"mediaID", @"id"]) {
        id value = SCIMediaObjectForSelector(mediaObject, selectorName) ?: SCIMediaKVCObject(mediaObject, selectorName);
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
            identifier = value;
            break;
        }
        if ([value respondsToSelector:@selector(stringValue)]) {
            identifier = [value stringValue];
            if (identifier.length > 0) break;
        }
    }
    if (identifier.length == 0) {
        identifier = NSUUID.UUID.UUIDString;
    }
    NSString *suffix = option.kind == SCIMediaOptionKindPhotoProgressive ? @"photo" :
                       option.kind == SCIMediaOptionKindAudioDash ? @"audio" : @"video";
    return [NSString stringWithFormat:@"scinsta_%@_%@", identifier, suffix];
}

static BOOL SCIMediaShouldSkipDuplicateStart(SCIMediaOption *option, DownloadAction action) {
    static NSString *lastKey = nil;
    static CFTimeInterval lastStartTime = 0.0;
    static dispatch_queue_t guardQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        guardQueue = dispatch_queue_create("com.scinsta.media.start-guard", DISPATCH_QUEUE_SERIAL);
    });

    __block BOOL shouldSkip = NO;
    NSString *key = [NSString stringWithFormat:@"%ld|%@|%@|%ld",
                     (long)option.kind,
                     option.primaryURL.absoluteString ?: @"",
                     option.secondaryURL.absoluteString ?: @"",
                     (long)action];

    dispatch_sync(guardQueue, ^{
        CFTimeInterval now = CACurrentMediaTime();
        BOOL sameRequest = [lastKey isEqualToString:key];
        BOOL withinWindow = (now - lastStartTime) < 1.0;
        shouldSkip = sameRequest && withinWindow;
        if (!shouldSkip) {
            lastKey = [key copy];
            lastStartTime = now;
        }
    });
    return shouldSkip;
}

static void SCIMediaPerformOptionDownload(SCIMediaOption *option,
                                          id mediaObject,
                                          SCIGallerySaveMetadata *galleryMetadata,
                                          DownloadAction action,
                                          BOOL copyToClipboard,
                                          BOOL showProgress) {
    // #region agent log
    SCILog(@"[DBG ec62e7 H3] option kind=%ld title=%@ vCodec=%@ aCodec=%@ bw=%ld abw=%ld vURL=%@ aURL=%@",
           (long)option.kind,
           option.title ?: @"",
           option.codec ?: @"",
           option.audioCodec ?: @"",
           (long)option.bandwidth,
           (long)option.audioBandwidth,
           option.primaryURL.absoluteString ?: @"",
           option.secondaryURL.absoluteString ?: @"");
    // #endregion
    if (SCIMediaShouldSkipDuplicateStart(option, action)) {
        // #region agent log
        SCILog(@"[DBG ec62e7 H6] duplicate option start suppressed kind=%ld vURL=%@ aURL=%@",
               (long)option.kind,
               option.primaryURL.absoluteString ?: @"",
               option.secondaryURL.absoluteString ?: @"");
        // #endregion
        return;
    }

    DownloadAction resolvedAction = copyToClipboard ? downloadOnly : action;
    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:resolvedAction showProgress:showProgress];
    delegate.pendingGallerySaveMetadata = galleryMetadata;
    if (copyToClipboard) {
        delegate.completionBlock = ^(NSURL * _Nullable fileURL, NSError * _Nullable error) {
            if (error || !fileURL) {
                [SCIUtils showToastForDuration:2.0 title:@"Copy failed" subtitle:error.localizedDescription iconResource:@"error_filled" tone:SCIFeedbackPillToneError];
                return;
            }
            SCIMediaCopyLocalFileToPasteboard(fileURL);
        };
    }

    if (option.kind == SCIMediaOptionKindPhotoProgressive || option.kind == SCIMediaOptionKindVideoProgressive) {
        [delegate downloadFileWithURL:option.primaryURL fileExtension:SCIMediaExtensionForOption(option) hudLabel:nil];
        return;
    }

    if (option.kind == SCIMediaOptionKindAudioDash && !copyToClipboard && action != share) {
        [SCIUtils showToastForDuration:2.0 title:@"Audio-only export is only supported for Share"];
        return;
    }

    [delegate beginCustomProgressWithTitle:@"Preparing media options" subtitle:nil];

    __block SCIMediaSingleDownloadJob *videoJob = nil;
    __block SCIMediaSingleDownloadJob *audioJob = nil;
    __block dispatch_block_t ffmpegCancel = nil;
    __weak SCIDownloadDelegate *weakDelegate = delegate;
    delegate.customCancelHandler = ^{
        [videoJob cancel];
        [audioJob cancel];
        if (ffmpegCancel) {
            ffmpegCancel();
        }
    };

    NSString *basename = SCIMediaSuggestedBasename(mediaObject, option);

    void (^fail)(NSString *, NSString *) = ^(NSString *title, NSString *subtitle) {
        [weakDelegate showCustomErrorWithTitle:title subtitle:subtitle];
    };

    void (^finishFile)(NSURL *) = ^(NSURL *fileURL) {
        [weakDelegate updateCustomProgress:0.95f title:@"Finalizing file" subtitle:nil];
        [weakDelegate finishWithLocalFileURL:fileURL];
    };

    void (^downloadAudioThenFinish)(NSURL *) = ^(NSURL *videoFileURL) {
        if (!option.secondaryURL) {
            finishFile(videoFileURL);
            return;
        }

        audioJob = [[SCIMediaSingleDownloadJob alloc] init];
        [weakDelegate updateCustomProgress:0.46f title:@"Downloading audio" subtitle:nil];
        [audioJob startWithURL:option.secondaryURL
               defaultExtension:@"m4a"
                       progress:^(double progress) {
            [weakDelegate updateCustomProgress:(float)(0.46 + (progress * 0.22)) title:@"Downloading audio" subtitle:nil];
        }
                     completion:^(NSURL * _Nullable audioFileURL, NSError * _Nullable error) {
            if (error || !audioFileURL) {
                fail(@"Audio download failed", error.localizedDescription ?: @"Unable to download DASH audio");
                return;
            }

            [weakDelegate updateCustomProgress:0.72f title:@"Merging video and audio" subtitle:nil];
            [SCIMediaFFmpeg mergeVideoFileURL:videoFileURL
                                 audioFileURL:audioFileURL
                            preferredBasename:basename
                             estimatedDuration:option.duration
                                         width:option.width
                                        height:option.height
                                 sourceBitrate:option.bandwidth
                                      progress:^(double progress, NSString *stage) {
                NSString *title = [stage isEqualToString:@"re-encoding"] ? @"Re-encoding" : @"Merging video and audio";
                [weakDelegate updateCustomProgress:(float)(0.72 + (progress * 0.2)) title:title subtitle:nil];
            }
                                    completion:^(NSURL * _Nullable outputURL, NSError * _Nullable error) {
                if (error || !outputURL) {
                    fail(@"Merge failed", error.localizedDescription ?: @"Unable to merge video and audio");
                    return;
                }
                finishFile(outputURL);
            }
                                     cancelOut:^(dispatch_block_t cancelBlock) {
                ffmpegCancel = [cancelBlock copy];
            }];
        }];
    };

    if (option.kind == SCIMediaOptionKindAudioDash) {
        audioJob = [[SCIMediaSingleDownloadJob alloc] init];
        [weakDelegate updateCustomProgress:0.1f title:@"Downloading audio" subtitle:nil];
        [audioJob startWithURL:option.primaryURL
               defaultExtension:@"m4a"
                       progress:^(double progress) {
            [weakDelegate updateCustomProgress:(float)(0.1 + (progress * 0.65)) title:@"Downloading audio" subtitle:nil];
        }
                     completion:^(NSURL * _Nullable audioFileURL, NSError * _Nullable error) {
            if (error || !audioFileURL) {
                fail(@"Audio download failed", error.localizedDescription ?: @"Unable to download DASH audio");
                return;
            }
            [weakDelegate updateCustomProgress:0.8f title:@"Finalizing file" subtitle:nil];
            [SCIMediaFFmpeg extractAudioFileURL:audioFileURL
                               preferredBasename:basename
                                        progress:^(double progress, NSString *stage) {
                [weakDelegate updateCustomProgress:(float)(0.8 + (progress * 0.15)) title:[stage isEqualToString:@"re-encoding"] ? @"Re-encoding" : @"Finalizing file" subtitle:nil];
            }
                                      completion:^(NSURL * _Nullable outputURL, NSError * _Nullable error) {
                if (error || !outputURL) {
                    finishFile(audioFileURL);
                    return;
                }
                finishFile(outputURL);
            }
                                       cancelOut:^(dispatch_block_t cancelBlock) {
                ffmpegCancel = [cancelBlock copy];
            }];
        }];
        return;
    }

    videoJob = [[SCIMediaSingleDownloadJob alloc] init];
    [weakDelegate updateCustomProgress:0.12f title:@"Downloading video" subtitle:nil];
    [videoJob startWithURL:option.primaryURL
          defaultExtension:@"mp4"
                  progress:^(double progress) {
        [weakDelegate updateCustomProgress:(float)(0.12 + (progress * (option.secondaryURL ? 0.28 : 0.7))) title:@"Downloading video" subtitle:nil];
    }
                completion:^(NSURL * _Nullable videoFileURL, NSError * _Nullable error) {
        if (error || !videoFileURL) {
            fail(@"Video download failed", error.localizedDescription ?: @"Unable to download video");
            return;
        }
        if (option.kind == SCIMediaOptionKindVideoDashOnly) {
            finishFile(videoFileURL);
            return;
        }
        downloadAudioThenFinish(videoFileURL);
    }];
}

@implementation SCIMediaQualityManager

+ (BOOL)handleDownloadAction:(DownloadAction)action
                  identifier:(NSString *)identifier
                   presenter:(UIViewController *)presenter
                  sourceView:(UIView *)sourceView
                   mediaObject:(id)mediaObject
                     photoURL:(NSURL *)photoURL
                     videoURL:(NSURL *)videoURL
              galleryMetadata:(SCIGallerySaveMetadata *)galleryMetadata
                showProgress:(BOOL)showProgress {
    (void)identifier;
    BOOL includeAudioOptions = (action == share);
    SCIMediaAnalysis *analysis = SCIMediaAnalyze(mediaObject, photoURL, videoURL, action, includeAudioOptions);
    if (analysis.photoOptions.count == 0 && analysis.progressiveVideoOptions.count == 0 && analysis.mergedDashOptions.count == 0 && analysis.videoDashOnlyOptions.count == 0 && analysis.audioDashOptions.count == 0) {
        return NO;
    }

    UIViewController *resolvedPresenter = presenter ?: topMostController();
    if (!resolvedPresenter) {
        return NO;
    }

    SCIMediaOption *resolvedOption = SCIMediaResolveDefaultOption(analysis);
    if (resolvedOption) {
        SCIMediaPerformOptionDownload(resolvedOption, mediaObject, galleryMetadata, action, NO, showProgress);
        return YES;
    }

    SCIMediaPresentOptionsSheet(resolvedPresenter, sourceView, analysis, action, ^(SCIMediaOption *option) {
        SCIMediaPerformOptionDownload(option, mediaObject, galleryMetadata, action, NO, showProgress);
    });
    return YES;
}

+ (BOOL)handleCopyActionWithIdentifier:(NSString *)identifier
                             presenter:(UIViewController *)presenter
                            sourceView:(UIView *)sourceView
                             mediaObject:(id)mediaObject
                               photoURL:(NSURL *)photoURL
                               videoURL:(NSURL *)videoURL
                          showProgress:(BOOL)showProgress {
    (void)identifier;
    SCIMediaAnalysis *analysis = SCIMediaAnalyze(mediaObject, photoURL, videoURL, downloadOnly, YES);
    if (analysis.photoOptions.count == 0 && analysis.progressiveVideoOptions.count == 0 && analysis.mergedDashOptions.count == 0 && analysis.videoDashOnlyOptions.count == 0 && analysis.audioDashOptions.count == 0) {
        return NO;
    }

    UIViewController *resolvedPresenter = presenter ?: topMostController();
    if (!resolvedPresenter) {
        return NO;
    }

    SCIMediaOption *resolvedOption = SCIMediaResolveDefaultOption(analysis);
    if (resolvedOption) {
        SCIMediaPerformOptionDownload(resolvedOption, mediaObject, nil, downloadOnly, YES, showProgress);
        return YES;
    }

    SCIMediaPresentOptionsSheet(resolvedPresenter, sourceView, analysis, downloadOnly, ^(SCIMediaOption *option) {
        SCIMediaPerformOptionDownload(option, mediaObject, nil, downloadOnly, YES, showProgress);
    });
    return YES;
}

+ (UIViewController *)encodingSettingsViewController {
    return [[SCIMediaEncodingSettingsViewController alloc] init];
}

@end
