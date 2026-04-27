#import "SCIMediaItem.h"
#import "../Gallery/SCIGalleryFile.h"
#import "../Gallery/SCIGallerySaveMetadata.h"

@implementation SCIMediaItem

- (instancetype)init {
    if ((self = [super init])) {
        _gallerySaveSource = -1;
    }
    return self;
}

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

+ (instancetype)itemWithGalleryFile:(SCIGalleryFile *)file {
    SCIMediaItem *item = [[SCIMediaItem alloc] init];
    item.galleryFile = file;
    item.isFromGallery = YES;
    item.fileURL = [file fileURL];
    item.mediaType = (file.mediaType == SCIGalleryMediaTypeVideo) ? SCIMediaItemTypeVideo : SCIMediaItemTypeImage;
    SCIGallerySaveMetadata *meta = [[SCIGallerySaveMetadata alloc] init];
    meta.source = file.source;
    meta.sourceUsername = file.sourceUsername;
    meta.sourceUserPK = file.sourceUserPK;
    meta.sourceProfileURLString = file.sourceProfileURLString;
    meta.sourceMediaPK = file.sourceMediaPK;
    meta.sourceMediaCode = file.sourceMediaCode;
    meta.sourceMediaURLString = file.sourceMediaURLString;
    item.galleryMetadata = meta;

    UIImage *thumb = [SCIGalleryFile loadThumbnailForFile:file];
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
