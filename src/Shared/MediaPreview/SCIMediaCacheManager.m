#import "SCIMediaCacheManager.h"

#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>

#import "SCIMediaItem.h"

static NSString *SCISHA256String(NSString *value) {
    if (value.length == 0) return @"";

    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

static NSString *SCIFileKeyForURL(NSURL *url) {
    return url.absoluteString ?: url.path ?: @"";
}

@interface SCIMediaCacheManager ()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *imageCache;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *thumbnailCache;
@property (nonatomic, strong) dispatch_queue_t stateQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<void (^)(NSURL * _Nullable, NSError * _Nullable)> *> *downloadCompletions;

@end

@implementation SCIMediaCacheManager

+ (instancetype)sharedManager {
    static SCIMediaCacheManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SCIMediaCacheManager alloc] initPrivate];
    });
    return manager;
}

- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException format:@"Use +sharedManager"];
    return nil;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
        config.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:(24 * 1024 * 1024)
                                                        diskCapacity:(200 * 1024 * 1024)
                                                            diskPath:@"com.scinsta.media-preview.url-cache"];
        _session = [NSURLSession sessionWithConfiguration:config];

        _imageCache = [[NSCache alloc] init];
        _imageCache.name = @"com.scinsta.media-preview.image-cache";
        _imageCache.countLimit = 64;

        _thumbnailCache = [[NSCache alloc] init];
        _thumbnailCache.name = @"com.scinsta.media-preview.thumbnail-cache";
        _thumbnailCache.countLimit = 64;

        _stateQueue = dispatch_queue_create("com.scinsta.media-preview.cache-state", DISPATCH_QUEUE_SERIAL);
        _downloadCompletions = [NSMutableDictionary dictionary];

        [self ensureDirectoriesExist];
    }
    return self;
}

- (NSURL *)cacheRootURL {
    NSURL *caches = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
    return [caches URLByAppendingPathComponent:@"SCInstaMediaPreview" isDirectory:YES];
}

- (NSURL *)fileCacheDirectoryURL {
    return [[self cacheRootURL] URLByAppendingPathComponent:@"Files" isDirectory:YES];
}

- (void)ensureDirectoriesExist {
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:[self fileCacheDirectoryURL]
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&error];
}

- (nullable NSURL *)bestAvailableFileURLForItem:(SCIMediaItem *)item {
    if (!item) return nil;

    NSURL *resolvedURL = item.resolvedFileURL;
    if (resolvedURL.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:resolvedURL.path]) {
        return resolvedURL;
    }

    NSURL *fileURL = item.fileURL;
    if (fileURL.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        item.resolvedFileURL = fileURL;
        return fileURL;
    }

    NSURL *cachedURL = [self cachedFileURLForRemoteURL:fileURL];
    if (cachedURL) {
        item.resolvedFileURL = cachedURL;
        return cachedURL;
    }

    return nil;
}

- (nullable NSURL *)cachedFileURLForRemoteURL:(NSURL *)url {
    if (!url || url.isFileURL) return nil;

    NSString *key = SCIFileKeyForURL(url);
    if (key.length == 0) return nil;

    NSString *hash = SCISHA256String(key);
    NSString *ext = url.pathExtension.lowercaseString;
    if (ext.length == 0) {
        ext = [self inferredDefaultExtensionForURL:url];
    }

    NSString *fileName = ext.length > 0 ? [NSString stringWithFormat:@"%@.%@", hash, ext] : hash;
    NSURL *candidate = [[self fileCacheDirectoryURL] URLByAppendingPathComponent:fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:candidate.path]) {
        return candidate;
    }
    return nil;
}

- (NSString *)inferredDefaultExtensionForURL:(NSURL *)url {
    NSString *path = url.path.lowercaseString ?: @"";
    if ([path containsString:@".mp4"] || [path containsString:@".mov"] || [path containsString:@".m4v"]) {
        return @"mp4";
    }
    return @"jpg";
}

- (void)fetchLocalFileURLForItem:(SCIMediaItem *)item
                      completion:(void (^)(NSURL * _Nullable localURL, NSError * _Nullable error))completion {
    if (!item) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"SCIMediaCacheManager"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"Missing media item"}]);
        }
        return;
    }

    NSURL *existingURL = [self bestAvailableFileURLForItem:item];
    if (existingURL) {
        if (completion) completion(existingURL, nil);
        return;
    }

    NSURL *remoteURL = item.fileURL;
    if (!remoteURL || remoteURL.isFileURL) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SCIMediaCacheManager"
                                                            code:-2
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Missing remote media URL"}]);
        return;
    }

    NSString *key = SCIFileKeyForURL(remoteURL);
    if (key.length == 0) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SCIMediaCacheManager"
                                                            code:-3
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Invalid remote media URL"}]);
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.stateQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSMutableArray *existingCompletions = strongSelf.downloadCompletions[key];
        void (^wrappedCompletion)(NSURL * _Nullable, NSError * _Nullable) = ^(NSURL * _Nullable localURL, NSError * _Nullable error) {
            if (localURL) {
                item.resolvedFileURL = localURL;
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(localURL, error);
                });
            }
        };

        if (existingCompletions) {
            [existingCompletions addObject:[wrappedCompletion copy]];
            return;
        }

        strongSelf.downloadCompletions[key] = [NSMutableArray arrayWithObject:[wrappedCompletion copy]];

        NSURLRequest *request = [NSURLRequest requestWithURL:remoteURL
                                                 cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                             timeoutInterval:60.0];

        NSURLSessionDownloadTask *task = [strongSelf.session downloadTaskWithRequest:request
                                                                   completionHandler:^(NSURL *tempURL, NSURLResponse *response, NSError *error) {
            NSURL *finalURL = nil;
            NSError *finalError = error;

            if (!finalError && tempURL) {
                NSString *hash = SCISHA256String(key);
                NSString *ext = remoteURL.pathExtension.lowercaseString;
                if (ext.length == 0) {
                    ext = response.suggestedFilename.pathExtension.lowercaseString;
                }
                if (ext.length == 0) {
                    ext = [strongSelf inferredDefaultExtensionForURL:remoteURL];
                }

                NSString *fileName = ext.length > 0 ? [NSString stringWithFormat:@"%@.%@", hash, ext] : hash;
                NSURL *destinationURL = [[strongSelf fileCacheDirectoryURL] URLByAppendingPathComponent:fileName];
                [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
                if ([[NSFileManager defaultManager] moveItemAtURL:tempURL toURL:destinationURL error:&finalError]) {
                    finalURL = destinationURL;
                }
            }

            dispatch_async(strongSelf.stateQueue, ^{
                NSArray<void (^)(NSURL * _Nullable, NSError * _Nullable)> *callbacks = [strongSelf.downloadCompletions[key] copy] ?: @[];
                [strongSelf.downloadCompletions removeObjectForKey:key];
                for (void (^callback)(NSURL * _Nullable, NSError * _Nullable) in callbacks) {
                    callback(finalURL, finalError);
                }
            });
        }];
        [task resume];
    });
}

- (void)loadImageForItem:(SCIMediaItem *)item
              completion:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion {
    if (!item) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SCIMediaCacheManager"
                                                            code:-4
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Missing media item"}]);
        return;
    }

    if (item.image) {
        if (completion) completion(item.image, nil);
        return;
    }

    NSURL *bestURL = [self bestAvailableFileURLForItem:item];
    NSString *cacheKey = SCIFileKeyForURL(bestURL ?: item.fileURL);
    if (cacheKey.length > 0) {
        UIImage *cachedImage = [self.imageCache objectForKey:cacheKey];
        if (cachedImage) {
            item.image = cachedImage;
            if (completion) completion(cachedImage, nil);
            return;
        }
    }

    __weak typeof(self) weakSelf = self;
    void (^decodeImageAtURL)(NSURL *) = ^(NSURL *localURL) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            UIImage *image = nil;
            if (localURL.isFileURL) {
                image = [UIImage imageWithContentsOfFile:localURL.path];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (image) {
                    item.image = image;
                    if (cacheKey.length > 0) {
                        [strongSelf.imageCache setObject:image forKey:cacheKey];
                    }
                    if (completion) completion(image, nil);
                } else if (completion) {
                    completion(nil, [NSError errorWithDomain:@"SCIMediaCacheManager"
                                                        code:-5
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode image"}]);
                }
            });
        });
    };

    if (bestURL.isFileURL) {
        decodeImageAtURL(bestURL);
        return;
    }

    [self fetchLocalFileURLForItem:item completion:^(NSURL * _Nullable localURL, NSError * _Nullable error) {
        if (!localURL || error) {
            if (completion) completion(nil, error);
            return;
        }
        decodeImageAtURL(localURL);
    }];
}

- (void)loadThumbnailForVideoItem:(SCIMediaItem *)item
                       completion:(void (^)(UIImage * _Nullable image))completion {
    if (!item || item.mediaType != SCIMediaItemTypeVideo) {
        if (completion) completion(nil);
        return;
    }

    if (item.thumbnail) {
        if (completion) completion(item.thumbnail);
        return;
    }

    NSString *cacheKey = SCIFileKeyForURL(item.fileURL);
    if (cacheKey.length > 0) {
        UIImage *cachedImage = [self.thumbnailCache objectForKey:cacheKey];
        if (cachedImage) {
            item.thumbnail = cachedImage;
            if (completion) completion(cachedImage);
            return;
        }
    }

    NSURL *sourceURL = [self bestAvailableFileURLForItem:item] ?: item.fileURL;
    if (!sourceURL) {
        if (completion) completion(nil);
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        AVAsset *asset = [AVAsset assetWithURL:sourceURL];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.maximumSize = CGSizeMake(720.0, 720.0);

        NSError *error = nil;
        CGImageRef imageRef = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:&error];
        UIImage *thumbnail = imageRef ? [UIImage imageWithCGImage:imageRef] : nil;
        if (imageRef) {
            CGImageRelease(imageRef);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (thumbnail) {
                item.thumbnail = thumbnail;
                if (cacheKey.length > 0) {
                    [self.thumbnailCache setObject:thumbnail forKey:cacheKey];
                }
            }
            if (completion) completion(thumbnail);
        });
    });
}

- (void)prefetchItem:(SCIMediaItem *)item {
    if (!item) return;

    if (item.mediaType == SCIMediaItemTypeImage) {
        [self loadImageForItem:item completion:^(__unused UIImage *image, __unused NSError *error) {
        }];
        return;
    }

    [self fetchLocalFileURLForItem:item completion:^(__unused NSURL *localURL, __unused NSError *error) {
    }];
    [self loadThumbnailForVideoItem:item completion:^(__unused UIImage *image) {
    }];
}

@end
