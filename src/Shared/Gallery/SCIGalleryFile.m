#import "SCIGalleryFile.h"
#import "SCIGalleryPaths.h"
#import "SCIGalleryCoreDataStack.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>

static CGFloat const kThumbnailSize = 300.0;

static NSCache<NSString *, UIImage *> *SCIGalleryThumbnailCache(void) {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 200;
    });
    return cache;
}

static dispatch_queue_t SCIGalleryThumbnailStateQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.scinsta.gallery.thumbnail-state", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static NSMutableDictionary<NSString *, NSMutableArray<void(^)(BOOL success)> *> *SCIGalleryThumbnailCompletions(void) {
    static NSMutableDictionary<NSString *, NSMutableArray<void(^)(BOOL success)> *> *completions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        completions = [NSMutableDictionary dictionary];
    });
    return completions;
}

static NSString *SCIGalleryNormalizedExtension(NSString * _Nullable origExt, SCIGalleryMediaType mediaType) {
    NSString *e = origExt.length ? origExt.lowercaseString : @"";
    static NSSet<NSString *> *imageExts;
    static NSSet<NSString *> *videoExts;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        imageExts = [NSSet setWithArray:@[ @"jpg", @"jpeg", @"png", @"heic", @"webp", @"gif" ]];
        videoExts = [NSSet setWithArray:@[ @"mp4", @"mov", @"m4v", @"webm" ]];
    });
    if (e.length > 0 && e.length <= 5 && ([imageExts containsObject:e] || [videoExts containsObject:e])) {
        return [e isEqualToString:@"jpeg"] ? @"jpg" : e;
    }
    return (mediaType == SCIGalleryMediaTypeVideo) ? @"mp4" : @"jpg";
}

static NSString *SCIGallerySourceSlug(SCIGallerySource source) {
    switch (source) {
        case SCIGallerySourceFeed:    return @"feed";
        case SCIGallerySourceStories: return @"story";
        case SCIGallerySourceReels:   return @"reel";
        case SCIGallerySourceProfile: return @"profile-photo";
        case SCIGallerySourceDMs:     return @"dms";
        case SCIGallerySourceThumbnail: return @"thumbnail";
        case SCIGallerySourceOther:
        default:                    return @"other";
    }
}

/// Safe single path segment: ASCII-ish, no path separators.
static NSString *SCISanitizedGalleryUsername(NSString *raw) {
    if (!raw.length) {
        return @"";
    }
    NSMutableString *out = [NSMutableString stringWithCapacity:MIN((NSUInteger)48, raw.length)];
    NSUInteger maxLen = 48;
    [raw enumerateSubstringsInRange:NSMakeRange(0, raw.length)
                            options:NSStringEnumerationByComposedCharacterSequences
                         usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        if (out.length >= maxLen) {
            *stop = YES;
            return;
        }
        if (substring.length != 1) {
            [out appendString:@"_"];
            return;
        }
        unichar c = [substring characterAtIndex:0];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.') {
            [out appendString:substring];
        } else if (c == ' ') {
            [out appendString:@"_"];
        } else {
            [out appendString:@"_"];
        }
    }];
    NSString *collapsed = [out stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    while ([collapsed containsString:@"__"]) {
        collapsed = [collapsed stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    collapsed = [collapsed stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"._-"]];
    return collapsed.length ? collapsed : @"user";
}

static BOOL SCIStringLooksLikeUUIDFilename(NSString *baseName) {
    if (baseName.length < 32 || baseName.length > 40) {
        return NO;
    }
    NSUUID *u = [[NSUUID alloc] initWithUUIDString:baseName];
    return u != nil;
}

NSString *SCIFileNameForMedia(NSURL *fileURL,
                              SCIGalleryMediaType mediaType,
                              SCIGallerySaveMetadata * _Nullable metadata) {
    NSString *orig = fileURL.lastPathComponent ?: @"";
    NSString *origExt = orig.pathExtension;
    NSString *ext = SCIGalleryNormalizedExtension(origExt, mediaType);

    static NSDateFormatter *compactDateFmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        compactDateFmt = [[NSDateFormatter alloc] init];
        compactDateFmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        compactDateFmt.timeZone = [NSTimeZone localTimeZone];
        compactDateFmt.dateFormat = @"yyyyMMddHHmmss";
    });
    NSString *dateCompact = [compactDateFmt stringFromDate:[NSDate date]];

    SCIGallerySource src = metadata ? (SCIGallerySource)metadata.source : SCIGallerySourceOther;
    NSString *slug = SCIGallerySourceSlug(src);

    if (metadata.sourceUsername.length > 0) {
        NSString *user = SCISanitizedGalleryUsername(metadata.sourceUsername);
        return [NSString stringWithFormat:@"%@_%@_%@.%@", user, slug, dateCompact, ext];
    }

    NSString *base = [orig stringByDeletingPathExtension];
    if (SCIStringLooksLikeUUIDFilename(base) || base.length == 0) {
        return [NSString stringWithFormat:@"media_%@_%@.%@", slug, dateCompact, ext];
    }

    return [NSString stringWithFormat:@"%@_%@.%@", orig, dateCompact, ext];
}

@implementation SCIGalleryFile

@dynamic identifier;
@dynamic relativePath;
@dynamic mediaType;
@dynamic source;
@dynamic dateAdded;
@dynamic fileSize;
@dynamic isFavorite;
@dynamic folderPath;
@dynamic customName;
@dynamic sourceUsername;
@dynamic sourceUserPK;
@dynamic sourceProfileURLString;
@dynamic sourceMediaPK;
@dynamic sourceMediaCode;
@dynamic sourceMediaURLString;
@dynamic pixelWidth;
@dynamic pixelHeight;
@dynamic durationSeconds;

#pragma mark - Save to Gallery

+ (SCIGalleryFile *)saveFileToGallery:(NSURL *)fileURL
                           source:(SCIGallerySource)source
                        mediaType:(SCIGalleryMediaType)mediaType
                            error:(NSError **)error {
    return [self saveFileToGallery:fileURL source:source mediaType:mediaType folderPath:nil metadata:nil error:error];
}

+ (SCIGalleryFile *)saveFileToGallery:(NSURL *)fileURL
                           source:(SCIGallerySource)source
                        mediaType:(SCIGalleryMediaType)mediaType
                       folderPath:(NSString *)folderPath
                            error:(NSError **)error {
    return [self saveFileToGallery:fileURL source:source mediaType:mediaType folderPath:folderPath metadata:nil error:error];
}

+ (void)applyMetadata:(nullable SCIGallerySaveMetadata *)metadata toFile:(SCIGalleryFile *)file fallbackSource:(SCIGallerySource)fallbackSource {
    if (metadata) {
        file.source = metadata.source;
        file.sourceUsername = metadata.sourceUsername.length ? metadata.sourceUsername : nil;
        file.sourceUserPK = metadata.sourceUserPK.length ? metadata.sourceUserPK : nil;
        file.sourceProfileURLString = metadata.sourceProfileURLString.length ? metadata.sourceProfileURLString : nil;
        file.sourceMediaPK = metadata.sourceMediaPK.length ? metadata.sourceMediaPK : nil;
        file.sourceMediaCode = metadata.sourceMediaCode.length ? metadata.sourceMediaCode : nil;
        file.sourceMediaURLString = metadata.sourceMediaURLString.length ? metadata.sourceMediaURLString : nil;
        file.pixelWidth = metadata.pixelWidth;
        file.pixelHeight = metadata.pixelHeight;
        file.durationSeconds = metadata.durationSeconds;
    } else {
        file.source = fallbackSource;
        file.sourceUsername = nil;
        file.sourceUserPK = nil;
        file.sourceProfileURLString = nil;
        file.sourceMediaPK = nil;
        file.sourceMediaCode = nil;
        file.sourceMediaURLString = nil;
        file.pixelWidth = 0;
        file.pixelHeight = 0;
        file.durationSeconds = 0;
    }
}

+ (void)probeMediaAtPath:(NSString *)path mediaType:(SCIGalleryMediaType)mediaType file:(SCIGalleryFile *)file {
    if (mediaType == SCIGalleryMediaTypeImage) {
        CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
        if (!src) {
            return;
        }
        CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(src, 0, NULL);
        CFRelease(src);
        if (!props) {
            return;
        }
        NSNumber *w = CFDictionaryGetValue(props, kCGImagePropertyPixelWidth);
        NSNumber *h = CFDictionaryGetValue(props, kCGImagePropertyPixelHeight);
        if (file.pixelWidth <= 0 && [w respondsToSelector:@selector(intValue)]) {
            file.pixelWidth = (int32_t)w.intValue;
        }
        if (file.pixelHeight <= 0 && [h respondsToSelector:@selector(intValue)]) {
            file.pixelHeight = (int32_t)h.intValue;
        }
        CFRelease(props);
        return;
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    CMTime dur = asset.duration;
    if (file.durationSeconds <= 0.05 && CMTIME_IS_NUMERIC(dur)) {
        double sec = CMTimeGetSeconds(dur);
        if (sec > 0.05 && !isnan(sec)) {
            file.durationSeconds = sec;
        }
    }
    NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (tracks.count == 0) {
        return;
    }
    AVAssetTrack *track = tracks.firstObject;
    CGSize natural = track.naturalSize;
    CGAffineTransform tx = track.preferredTransform;
    CGSize rendered = CGSizeApplyAffineTransform(natural, tx);
    int32_t w = (int32_t)lround(fabs(rendered.width));
    int32_t h = (int32_t)lround(fabs(rendered.height));
    if (file.pixelWidth <= 0) {
        file.pixelWidth = w;
    }
    if (file.pixelHeight <= 0) {
        file.pixelHeight = h;
    }
}

+ (SCIGalleryFile *)saveFileToGallery:(NSURL *)fileURL
                           source:(SCIGallerySource)source
                        mediaType:(SCIGalleryMediaType)mediaType
                       folderPath:(NSString *)folderPath
                         metadata:(SCIGallerySaveMetadata *)metadata
                            error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:fileURL.path]) {
        if (error) {
            *error = [NSError errorWithDomain:@"SCIGallery" code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Source file does not exist"}];
        }
        return nil;
    }

    NSString *fileName = SCIFileNameForMedia(fileURL, mediaType, metadata);
    NSString *destPath = [[SCIGalleryPaths galleryMediaDirectory] stringByAppendingPathComponent:fileName];

    if ([fm fileExistsAtPath:destPath]) {
        NSString *stem = [fileName stringByDeletingPathExtension];
        NSString *ext = fileName.pathExtension;
        for (int n = 1; n < 100; n++) {
            NSString *candidate = [NSString stringWithFormat:@"%@-%d.%@", stem, n, ext];
            NSString *candidatePath = [[SCIGalleryPaths galleryMediaDirectory] stringByAppendingPathComponent:candidate];
            if (![fm fileExistsAtPath:candidatePath]) {
                fileName = candidate;
                destPath = candidatePath;
                break;
            }
        }
    }

    NSError *copyError;
    if (![fm copyItemAtPath:fileURL.path toPath:destPath error:&copyError]) {
        NSLog(@"[SCInsta Gallery] Failed to copy file: %@", copyError);
        if (error) *error = copyError;
        return nil;
    }

    NSDictionary *attrs = [fm attributesOfItemAtPath:destPath error:nil];
    int64_t size = [attrs[NSFileSize] longLongValue];

    NSManagedObjectContext *ctx = [SCIGalleryCoreDataStack shared].viewContext;
    SCIGalleryFile *file = [NSEntityDescription insertNewObjectForEntityForName:@"SCIGalleryFile"
                                                       inManagedObjectContext:ctx];
    file.identifier = [NSUUID UUID].UUIDString;
    file.relativePath = fileName;
    file.mediaType = mediaType;
    file.dateAdded = [NSDate date];
    file.fileSize = size;
    file.isFavorite = NO;
    file.folderPath = folderPath;

    [self applyMetadata:metadata toFile:file fallbackSource:source];
    [self probeMediaAtPath:destPath mediaType:mediaType file:file];

    NSError *saveError;
    if (![ctx save:&saveError]) {
        NSLog(@"[SCInsta Gallery] Failed to save entity: %@", saveError);
        [fm removeItemAtPath:destPath error:nil];
        if (error) *error = saveError;
        return nil;
    }

    [self generateThumbnailForFile:file completion:nil];

    return file;
}

#pragma mark - Remove

- (BOOL)removeWithError:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *mediaPath = [self filePath];
    if ([fm fileExistsAtPath:mediaPath]) {
        [fm removeItemAtPath:mediaPath error:nil];
    }

    NSString *thumbPath = [self thumbnailPath];
    if ([fm fileExistsAtPath:thumbPath]) {
        [fm removeItemAtPath:thumbPath error:nil];
    }

    NSManagedObjectContext *ctx = self.managedObjectContext;
    [ctx deleteObject:self];

    NSError *saveError;
    if (![ctx save:&saveError]) {
        NSLog(@"[SCInsta Gallery] Failed to delete entity: %@", saveError);
        if (error) *error = saveError;
        return NO;
    }

    return YES;
}

#pragma mark - Paths

- (NSString *)filePath {
    return [[SCIGalleryPaths galleryMediaDirectory] stringByAppendingPathComponent:self.relativePath];
}

- (NSURL *)fileURL {
    return [NSURL fileURLWithPath:[self filePath]];
}

- (BOOL)fileExists {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self filePath]];
}

- (NSString *)thumbnailPath {
    return [[SCIGalleryPaths galleryThumbnailsDirectory]
            stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg", self.identifier]];
}

- (BOOL)thumbnailExists {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self thumbnailPath]];
}

#pragma mark - Display helpers

- (NSString *)displayName {
    if (self.customName.length > 0) return self.customName;

    // relativePath: "<epochMs>_<rest>" — rest may be "user_slug_date.ext" or legacy "originalFilename".
    NSString *rel = self.relativePath ?: @"";
    NSRange sep = [rel rangeOfString:@"_"];
    if (sep.location != NSNotFound && sep.location + 1 < rel.length) {
        return [rel substringFromIndex:sep.location + 1];
    }
    return rel;
}

- (NSString *)sourceLabel {
    return [SCIGalleryFile labelForSource:(SCIGallerySource)self.source];
}

- (NSString *)shortSourceLabel {
    return [SCIGalleryFile shortLabelForSource:(SCIGallerySource)self.source];
}

- (NSString *)listPrimaryTitle {
    if (self.sourceUsername.length) {
        return self.sourceUsername;
    }
    return [self displayName];
}

- (NSString *)listFormattedDuration {
    if (self.durationSeconds <= 0.05) {
        return @"";
    }
    NSInteger total = (NSInteger)llround(self.durationSeconds);
    NSInteger m = total / 60;
    NSInteger s = total % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)m, (long)s];
}

- (NSString *)listBitrateString {
    if (self.mediaType != SCIGalleryMediaTypeVideo) {
        return @"";
    }
    if (self.durationSeconds < 0.5 || self.fileSize <= 0) {
        return @"";
    }
    double mbps = (double)self.fileSize * 8.0 / self.durationSeconds / 1e6;
    if (mbps < 0.01) {
        return @"";
    }
    return [NSString stringWithFormat:@"%.1f Mbps", mbps];
}

- (NSString *)listTechnicalLine {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    BOOL isVideo = self.mediaType == SCIGalleryMediaTypeVideo;
    if (isVideo) {
        NSString *d = [self listFormattedDuration];
        if (d.length) {
            [parts addObject:d];
        }
    }
    NSString *sz = [NSByteCountFormatter stringFromByteCount:self.fileSize
                                                    countStyle:NSByteCountFormatterCountStyleFile];
    if (sz.length) {
        [parts addObject:sz];
    }
    if (self.pixelWidth > 0 && self.pixelHeight > 0) {
        [parts addObject:[NSString stringWithFormat:@"%dx%d", self.pixelWidth, self.pixelHeight]];
    }
    if (isVideo) {
        NSString *br = [self listBitrateString];
        if (br.length) {
            [parts addObject:br];
        }
    }
    return [parts componentsJoinedByString:@" · "];
}

- (NSString *)listDownloadDateString {
    static NSDateFormatter *fmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"MMM d 'at' h:mm a";
    });
    return self.dateAdded ? [fmt stringFromDate:self.dateAdded] : @"";
}

- (NSURL *)preferredProfileURL {
    if (self.sourceProfileURLString.length > 0) {
        NSURL *url = [NSURL URLWithString:self.sourceProfileURLString];
        if (url) return url;
    }
    if (self.sourceUsername.length > 0) {
        NSString *encodedUsername = [self.sourceUsername stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        if (encodedUsername.length > 0) {
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"instagram://user?username=%@", encodedUsername]];
            if (url) return url;
        }
    }
    return nil;
}

- (NSURL *)preferredOriginalMediaURL {
    if (self.sourceMediaURLString.length > 0) {
        NSURL *url = [NSURL URLWithString:self.sourceMediaURLString];
        NSString *scheme = url.scheme.lowercaseString ?: @"";
        if (url && ([scheme isEqualToString:@"http"] ||
                    [scheme isEqualToString:@"https"] ||
                    [scheme isEqualToString:@"instagram"])) {
            return url;
        }
    }
    if (self.sourceMediaCode.length > 0) {
        NSString *pathComponent = (self.source == SCIGallerySourceReels) ? @"reel" : @"p";
        return [NSURL URLWithString:[NSString stringWithFormat:@"https://www.instagram.com/%@/%@/", pathComponent, self.sourceMediaCode]];
    }
    if (self.sourceMediaPK.length > 0) {
        NSString *encodedPK = [self.sourceMediaPK stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        if (encodedPK.length > 0) {
            return [NSURL URLWithString:[NSString stringWithFormat:@"instagram://media?id=%@", encodedPK]];
        }
    }
    return nil;
}

- (BOOL)hasOpenableProfile {
    return [self preferredProfileURL] != nil;
}

- (BOOL)hasOpenableOriginalMedia {
    return [self preferredOriginalMediaURL] != nil;
}

+ (NSString *)labelForSource:(SCIGallerySource)source {
    switch (source) {
        case SCIGallerySourceFeed:      return @"Feed";
        case SCIGallerySourceStories:   return @"Stories";
        case SCIGallerySourceReels:     return @"Reels";
        case SCIGallerySourceProfile:   return @"Profile";
        case SCIGallerySourceDMs:       return @"DMs";
        case SCIGallerySourceThumbnail: return @"Thumb";
        case SCIGallerySourceOther:
        default:                      return @"Other";
    }
}

+ (NSString *)shortLabelForSource:(SCIGallerySource)source {
    switch (source) {
        case SCIGallerySourceFeed:      return @"Feed";
        case SCIGallerySourceStories:   return @"Story";
        case SCIGallerySourceReels:     return @"Reel";
        case SCIGallerySourceProfile:   return @"Profile";
        case SCIGallerySourceDMs:       return @"DMs";
        case SCIGallerySourceThumbnail: return @"Thumb";
        case SCIGallerySourceOther:
        default:                      return @"Other";
    }
}

+ (NSString *)symbolNameForSource:(SCIGallerySource)source {
    switch (source) {
        case SCIGallerySourceFeed:    return @"feed";
        case SCIGallerySourceStories: return @"story";
        case SCIGallerySourceReels:   return @"reels";
        case SCIGallerySourceProfile: return @"profile";
        case SCIGallerySourceDMs:     return @"messages";
        case SCIGallerySourceThumbnail: return @"photo";
        case SCIGallerySourceOther:
        default:                    return @"media";
    }
}

#pragma mark - Thumbnails

+ (void)generateThumbnailForFile:(SCIGalleryFile *)file completion:(void(^)(BOOL success))completion {
    NSString *filePath = [file filePath];
    NSString *thumbPath = [file thumbnailPath];
    int16_t mediaType = file.mediaType;
    NSCache<NSString *, UIImage *> *cache = SCIGalleryThumbnailCache();

    UIImage *cachedThumb = [cache objectForKey:thumbPath];
    if (cachedThumb || [file thumbnailExists]) {
        if (!cachedThumb) {
            cachedThumb = [UIImage imageWithContentsOfFile:thumbPath];
            if (cachedThumb) {
                [cache setObject:cachedThumb forKey:thumbPath];
            }
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(cachedThumb != nil);
            });
        }
        return;
    }

    __block BOOL shouldGenerate = NO;
    dispatch_sync(SCIGalleryThumbnailStateQueue(), ^{
        NSMutableDictionary<NSString *, NSMutableArray<void(^)(BOOL success)> *> *pending = SCIGalleryThumbnailCompletions();
        NSMutableArray<void(^)(BOOL success)> *callbacks = pending[thumbPath];
        if (callbacks) {
            if (completion) {
                [callbacks addObject:[completion copy]];
            }
            return;
        }

        shouldGenerate = YES;
        callbacks = [NSMutableArray array];
        if (completion) {
            [callbacks addObject:[completion copy]];
        }
        pending[thumbPath] = callbacks;
    });

    if (!shouldGenerate) {
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        UIImage *thumb = nil;

        if (mediaType == SCIGalleryMediaTypeImage) {
            UIImage *full = [UIImage imageWithContentsOfFile:filePath];
            if (full) {
                thumb = [self resizeImage:full toSize:CGSizeMake(kThumbnailSize, kThumbnailSize)];
            }
        } else if (mediaType == SCIGalleryMediaTypeVideo) {
            NSURL *videoURL = [NSURL fileURLWithPath:filePath];
            AVAsset *asset = [AVAsset assetWithURL:videoURL];
            AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            gen.appliesPreferredTrackTransform = YES;
            gen.maximumSize = CGSizeMake(kThumbnailSize, kThumbnailSize);

            NSError *err;
            CGImageRef cgImage = [gen copyCGImageAtTime:CMTimeMake(1, 2) actualTime:NULL error:&err];
            if (cgImage) {
                thumb = [UIImage imageWithCGImage:cgImage];
                CGImageRelease(cgImage);
            }
        }

        if (thumb) {
            NSData *jpegData = UIImageJPEGRepresentation(thumb, 0.8);
            [jpegData writeToFile:thumbPath atomically:YES];
            [cache setObject:thumb forKey:thumbPath];
        }

        __block NSArray<void(^)(BOOL success)> *callbacks = nil;
        dispatch_sync(SCIGalleryThumbnailStateQueue(), ^{
            callbacks = [[SCIGalleryThumbnailCompletions()[thumbPath] copy] ?: @[] copy];
            [SCIGalleryThumbnailCompletions() removeObjectForKey:thumbPath];
        });

        if (callbacks.count == 0) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL success = (thumb != nil);
            for (void (^callback)(BOOL success) in callbacks) {
                callback(success);
            }
        });
    });
}

+ (UIImage *)loadThumbnailForFile:(SCIGalleryFile *)file {
    NSString *thumbPath = [file thumbnailPath];
    UIImage *cached = [SCIGalleryThumbnailCache() objectForKey:thumbPath];
    if (cached) {
        return cached;
    }
    if ([file thumbnailExists]) {
        UIImage *image = [UIImage imageWithContentsOfFile:thumbPath];
        if (image) {
            [SCIGalleryThumbnailCache() setObject:image forKey:thumbPath];
        }
        return image;
    }
    return nil;
}

+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)targetSize {
    CGFloat scale = MIN(targetSize.width / image.size.width, targetSize.height / image.size.height);
    CGSize newSize = CGSizeMake(image.size.width * scale, image.size.height * scale);

    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return resized;
}

@end
