#import "SCIVaultFile.h"
#import "SCIVaultPaths.h"
#import "SCIVaultCoreDataStack.h"
#import <AVFoundation/AVFoundation.h>

static CGFloat const kThumbnailSize = 300.0;

@implementation SCIVaultFile

@dynamic identifier;
@dynamic relativePath;
@dynamic mediaType;
@dynamic source;
@dynamic dateAdded;
@dynamic fileSize;
@dynamic isFavorite;

#pragma mark - Save to Vault

+ (SCIVaultFile *)saveFileToVault:(NSURL *)fileURL
                           source:(SCIVaultSource)source
                        mediaType:(SCIVaultMediaType)mediaType
                            error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:fileURL.path]) {
        if (error) {
            *error = [NSError errorWithDomain:@"SCIVault" code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Source file does not exist"}];
        }
        return nil;
    }

    NSString *originalName = fileURL.lastPathComponent;
    long long epochMs = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSString *fileName = [NSString stringWithFormat:@"%lld_%@", epochMs, originalName];
    NSString *destPath = [[SCIVaultPaths vaultMediaDirectory] stringByAppendingPathComponent:fileName];

    NSError *copyError;
    if (![fm copyItemAtPath:fileURL.path toPath:destPath error:&copyError]) {
        NSLog(@"[SCInsta Vault] Failed to copy file: %@", copyError);
        if (error) *error = copyError;
        return nil;
    }

    NSDictionary *attrs = [fm attributesOfItemAtPath:destPath error:nil];
    int64_t size = [attrs[NSFileSize] longLongValue];

    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    SCIVaultFile *file = [NSEntityDescription insertNewObjectForEntityForName:@"SCIVaultFile"
                                                       inManagedObjectContext:ctx];
    file.identifier = [NSUUID UUID].UUIDString;
    file.relativePath = fileName;
    file.mediaType = mediaType;
    file.source = source;
    file.dateAdded = [NSDate date];
    file.fileSize = size;
    file.isFavorite = NO;

    NSError *saveError;
    if (![ctx save:&saveError]) {
        NSLog(@"[SCInsta Vault] Failed to save entity: %@", saveError);
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
        NSLog(@"[SCInsta Vault] Failed to delete entity: %@", saveError);
        if (error) *error = saveError;
        return NO;
    }

    return YES;
}

#pragma mark - Paths

- (NSString *)filePath {
    return [[SCIVaultPaths vaultMediaDirectory] stringByAppendingPathComponent:self.relativePath];
}

- (NSURL *)fileURL {
    return [NSURL fileURLWithPath:[self filePath]];
}

- (BOOL)fileExists {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self filePath]];
}

- (NSString *)thumbnailPath {
    return [[SCIVaultPaths vaultThumbnailsDirectory]
            stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg", self.identifier]];
}

- (BOOL)thumbnailExists {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self thumbnailPath]];
}

#pragma mark - Thumbnails

+ (void)generateThumbnailForFile:(SCIVaultFile *)file completion:(void(^)(BOOL success))completion {
    NSString *filePath = [file filePath];
    NSString *thumbPath = [file thumbnailPath];
    int16_t mediaType = file.mediaType;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        UIImage *thumb = nil;

        if (mediaType == SCIVaultMediaTypeImage) {
            UIImage *full = [UIImage imageWithContentsOfFile:filePath];
            if (full) {
                thumb = [self resizeImage:full toSize:CGSizeMake(kThumbnailSize, kThumbnailSize)];
            }
        } else if (mediaType == SCIVaultMediaTypeVideo) {
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
        }

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(thumb != nil);
            });
        }
    });
}

+ (UIImage *)loadThumbnailForFile:(SCIVaultFile *)file {
    if ([file thumbnailExists]) {
        return [UIImage imageWithContentsOfFile:[file thumbnailPath]];
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
