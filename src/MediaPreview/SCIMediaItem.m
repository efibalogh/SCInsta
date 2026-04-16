#import "SCIMediaItem.h"
#import "../Vault/SCIVaultFile.h"

@implementation SCIMediaItem

+ (instancetype)itemWithFileURL:(NSURL *)url {
    SCIMediaItem *item = [[SCIMediaItem alloc] init];
    item.fileURL = url;
    item.mediaType = [self mediaTypeForFileExtension:url.pathExtension];
    return item;
}

+ (instancetype)itemWithImage:(UIImage *)image {
    SCIMediaItem *item = [[SCIMediaItem alloc] init];
    item.image = image;
    item.mediaType = SCIMediaItemTypeImage;
    return item;
}

+ (instancetype)itemWithVaultFile:(SCIVaultFile *)file {
    SCIMediaItem *item = [[SCIMediaItem alloc] init];
    item.vaultFile = file;
    item.isFromVault = YES;
    item.fileURL = [file fileURL];
    item.mediaType = (file.mediaType == SCIVaultMediaTypeVideo) ? SCIMediaItemTypeVideo : SCIMediaItemTypeImage;

    UIImage *thumb = [SCIVaultFile loadThumbnailForFile:file];
    if (thumb) {
        item.thumbnail = thumb;
    }

    return item;
}

+ (SCIMediaItemType)mediaTypeForFileExtension:(NSString *)extension {
    NSString *ext = extension.lowercaseString;
    if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] ||
        [ext isEqualToString:@"m4v"] || [ext isEqualToString:@"avi"] ||
        [ext isEqualToString:@"webm"]) {
        return SCIMediaItemTypeVideo;
    }
    return SCIMediaItemTypeImage;
}

@end
