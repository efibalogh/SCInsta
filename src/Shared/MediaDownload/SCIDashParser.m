#import "SCIDashParser.h"

#import <objc/message.h>
#import <objc/runtime.h>

@implementation SCIDashRepresentation
@end

static id SCIDashFieldCache(id obj, NSString *key) {
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

static NSDictionary *SCIDashFieldCacheDictionary(id obj) {
    if (!obj) return nil;

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

    return [fieldCache isKindOfClass:[NSDictionary class]] ? fieldCache : nil;
}

static NSString *SCIDashManifestString(id value) {
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 10) {
        return value;
    }

    if ([value isKindOfClass:[NSData class]] && [(NSData *)value length] > 10) {
        NSString *string = [[NSString alloc] initWithData:(NSData *)value encoding:NSUTF8StringEncoding];
        if (string.length > 10) {
            return string;
        }
    }

    return nil;
}

static BOOL SCIDashLooksLikeManifest(id value) {
    NSString *string = SCIDashManifestString(value);
    if (string.length == 0) return NO;

    NSString *head = [string substringToIndex:MIN((NSUInteger)16, string.length)];
    return [head containsString:@"<MPD"] || [head containsString:@"<?xml"] || [head hasPrefix:@"http"];
}

static NSString *SCIDashRecursiveManifestSearch(NSDictionary *dictionary, NSInteger depth) {
    if (![dictionary isKindOfClass:[NSDictionary class]] || depth > 4) {
        return nil;
    }

    for (NSString *key in dictionary) {
        id value = dictionary[key];
        NSString *lower = key.lowercaseString;
        if (([lower containsString:@"dash"] || [lower containsString:@"manifest"]) && SCIDashLooksLikeManifest(value)) {
            return SCIDashManifestString(value);
        }

        if ([value isKindOfClass:[NSDictionary class]]) {
            NSString *found = SCIDashRecursiveManifestSearch(value, depth + 1);
            if (found.length > 0) return found;
        } else if ([value isKindOfClass:[NSArray class]]) {
            for (id item in (NSArray *)value) {
                if ([item isKindOfClass:[NSDictionary class]]) {
                    NSString *found = SCIDashRecursiveManifestSearch(item, depth + 1);
                    if (found.length > 0) return found;
                }
            }
        }
    }

    return nil;
}

static NSString *SCIDashRegexCapture(NSString *source, NSRegularExpression *regex) {
    if (source.length == 0 || !regex) return nil;
    NSTextCheckingResult *match = [regex firstMatchInString:source options:0 range:NSMakeRange(0, source.length)];
    if (!match || [match rangeAtIndex:1].location == NSNotFound) return nil;
    return [source substringWithRange:[match rangeAtIndex:1]];
}

@implementation SCIDashParser

+ (NSString *)dashManifestForMedia:(id)media {
    if (!media) return nil;

    NSArray<NSString *> *keys = @[
        @"video_dash_manifest",
        @"dash_manifest",
        @"video_dash_manifest_url",
        @"dash_manifest_url"
    ];

    for (NSString *key in keys) {
        NSString *manifest = SCIDashManifestString(SCIDashFieldCache(media, key));
        if (manifest.length > 0) {
            return manifest;
        }
    }

    @try {
        if ([media respondsToSelector:@selector(videoDashManifest)]) {
            NSString *manifest = SCIDashManifestString(((id (*)(id, SEL))objc_msgSend)(media, @selector(videoDashManifest)));
            if (manifest.length > 0) return manifest;
        }
    } @catch (__unused NSException *exception) {
    }

    id video = nil;
    @try {
        if ([media respondsToSelector:@selector(video)]) {
            video = ((id (*)(id, SEL))objc_msgSend)(media, @selector(video));
        }
    } @catch (__unused NSException *exception) {
        video = nil;
    }

    if (video) {
        for (NSString *key in keys) {
            NSString *manifest = SCIDashManifestString(SCIDashFieldCache(video, key));
            if (manifest.length > 0) {
                return manifest;
            }
        }

        @try {
            if ([video respondsToSelector:@selector(dashManifestData)]) {
                NSString *manifest = SCIDashManifestString(((id (*)(id, SEL))objc_msgSend)(video, @selector(dashManifestData)));
                if (manifest.length > 0) return manifest;
            }
        } @catch (__unused NSException *exception) {
        }

        @try {
            Ivar ivar = NULL;
            for (Class cls = [video class]; cls && !ivar; cls = class_getSuperclass(cls)) {
                ivar = class_getInstanceVariable(cls, "_dashManifestData");
            }
            if (ivar) {
                NSString *manifest = SCIDashManifestString(object_getIvar(video, ivar));
                if (manifest.length > 0) return manifest;
            }
        } @catch (__unused NSException *exception) {
        }
    }

    NSDictionary *fieldCache = SCIDashFieldCacheDictionary(media);
    NSString *recursive = SCIDashRecursiveManifestSearch(fieldCache, 0);
    if (recursive.length > 0) {
        return recursive;
    }

    return nil;
}

+ (NSArray<SCIDashRepresentation *> *)parseManifest:(NSString *)xmlString {
    if (xmlString.length == 0) return @[];

    NSError *error = nil;
    NSRegularExpression *adaptationRegex = [NSRegularExpression regularExpressionWithPattern:@"(<AdaptationSet[^>]*>)(.*?)</AdaptationSet>"
                                                                                    options:NSRegularExpressionDotMatchesLineSeparators
                                                                                      error:&error];
    if (error || !adaptationRegex) {
        return @[];
    }

    NSRegularExpression *contentTypeRegex = [NSRegularExpression regularExpressionWithPattern:@"contentType=\"(video|audio)\""
                                                                                       options:NSRegularExpressionCaseInsensitive
                                                                                         error:nil];
    NSRegularExpression *mimeTypeRegex = [NSRegularExpression regularExpressionWithPattern:@"mimeType=\"(video|audio)/[^\"]*\""
                                                                                    options:NSRegularExpressionCaseInsensitive
                                                                                      error:nil];
    NSRegularExpression *representationRegex = [NSRegularExpression regularExpressionWithPattern:@"<Representation[^>]*>"
                                                                                          options:0
                                                                                            error:nil];
    NSRegularExpression *baseURLRegex = [NSRegularExpression regularExpressionWithPattern:@"<BaseURL>(.*?)</BaseURL>"
                                                                                  options:0
                                                                                    error:nil];
    NSRegularExpression *bandwidthRegex = [NSRegularExpression regularExpressionWithPattern:@"bandwidth=\"(\\d+)\""
                                                                                     options:0
                                                                                       error:nil];
    NSRegularExpression *widthRegex = [NSRegularExpression regularExpressionWithPattern:@"(?:^|\\s)width=\"(\\d+)\""
                                                                                 options:0
                                                                                   error:nil];
    NSRegularExpression *heightRegex = [NSRegularExpression regularExpressionWithPattern:@"(?:^|\\s)height=\"(\\d+)\""
                                                                                  options:0
                                                                                    error:nil];
    NSRegularExpression *labelRegex = [NSRegularExpression regularExpressionWithPattern:@"FBQualityLabel=\"([^\"]+)\""
                                                                                 options:0
                                                                                   error:nil];
    NSRegularExpression *fpsRegex = [NSRegularExpression regularExpressionWithPattern:@"frameRate=\"([0-9./]+)\""
                                                                               options:0
                                                                                 error:nil];
    NSRegularExpression *codecsRegex = [NSRegularExpression regularExpressionWithPattern:@"codecs=\"([^\"]+)\""
                                                                                  options:0
                                                                                    error:nil];

    NSMutableArray<SCIDashRepresentation *> *representations = [NSMutableArray array];

    [adaptationRegex enumerateMatchesInString:xmlString
                                      options:0
                                        range:NSMakeRange(0, xmlString.length)
                                   usingBlock:^(NSTextCheckingResult * _Nullable adaptationMatch, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        (void)flags;
        (void)stop;
        if (!adaptationMatch) return;

        NSString *adaptationTag = [xmlString substringWithRange:[adaptationMatch rangeAtIndex:1]];
        NSString *adaptationBody = [xmlString substringWithRange:[adaptationMatch rangeAtIndex:2]];

        NSString *contentType = [SCIDashRegexCapture(adaptationTag, contentTypeRegex) lowercaseString];
        if (contentType.length == 0) {
            contentType = [SCIDashRegexCapture(adaptationTag, mimeTypeRegex) lowercaseString];
        }
        if (contentType.length == 0) {
            return;
        }

        NSArray<NSTextCheckingResult *> *representationMatches = [representationRegex matchesInString:adaptationBody
                                                                                               options:0
                                                                                                 range:NSMakeRange(0, adaptationBody.length)];
        NSArray<NSTextCheckingResult *> *urlMatches = [baseURLRegex matchesInString:adaptationBody
                                                                             options:0
                                                                               range:NSMakeRange(0, adaptationBody.length)];
        NSUInteger count = MIN(representationMatches.count, urlMatches.count);
        for (NSUInteger idx = 0; idx < count; idx++) {
            NSString *representationTag = [adaptationBody substringWithRange:representationMatches[idx].range];
            NSString *baseURL = [adaptationBody substringWithRange:[urlMatches[idx] rangeAtIndex:1]];
            if (baseURL.length == 0) continue;

            SCIDashRepresentation *representation = [[SCIDashRepresentation alloc] init];
            representation.contentType = contentType;
            representation.url = [NSURL URLWithString:[baseURL stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
            representation.qualityLabel = SCIDashRegexCapture(representationTag, labelRegex);
            representation.codecs = SCIDashRegexCapture(representationTag, codecsRegex);
            representation.bandwidth = [SCIDashRegexCapture(representationTag, bandwidthRegex) integerValue];
            representation.width = [SCIDashRegexCapture(representationTag, widthRegex) integerValue];
            representation.height = [SCIDashRegexCapture(representationTag, heightRegex) integerValue];

            NSString *fpsString = SCIDashRegexCapture(representationTag, fpsRegex);
            if ([fpsString containsString:@"/"]) {
                NSArray<NSString *> *parts = [fpsString componentsSeparatedByString:@"/"];
                if (parts.count == 2) {
                    double denominator = parts[1].doubleValue;
                    if (denominator > 0.0) {
                        representation.frameRate = parts[0].doubleValue / denominator;
                    }
                }
            } else {
                representation.frameRate = fpsString.doubleValue;
            }

            if (representation.url) {
                [representations addObject:representation];
            }
        }
    }];

    [representations sortUsingComparator:^NSComparisonResult(SCIDashRepresentation *lhs, SCIDashRepresentation *rhs) {
        if ([lhs.contentType isEqualToString:rhs.contentType] == NO) {
            return [lhs.contentType compare:rhs.contentType];
        }

        NSInteger lhsArea = lhs.width * lhs.height;
        NSInteger rhsArea = rhs.width * rhs.height;
        if (lhsArea > rhsArea) return NSOrderedAscending;
        if (lhsArea < rhsArea) return NSOrderedDescending;

        if (lhs.bandwidth > rhs.bandwidth) return NSOrderedAscending;
        if (lhs.bandwidth < rhs.bandwidth) return NSOrderedDescending;

        return NSOrderedSame;
    }];

    return representations;
}

@end
