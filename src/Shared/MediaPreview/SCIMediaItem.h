#import <UIKit/UIKit.h>

@class SCIGalleryFile, SCIGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIMediaItemType) {
    SCIMediaItemTypeImage = 1,
    SCIMediaItemTypeVideo = 2,
};

@interface SCIMediaItem : NSObject

@property (nonatomic) SCIMediaItemType mediaType;
@property (nonatomic, strong, nullable) NSURL *fileURL;
@property (nonatomic, strong, nullable) NSURL *resolvedFileURL;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) UIImage *thumbnail;
@property (nonatomic, strong, nullable) id sourceMediaObject;
@property (nonatomic, copy, nullable) NSString *title;
/// When >= 0, `SCIGallerySaveMetadata.source` uses this value (`SCIGallerySource`). Default -1 = not set.
@property (nonatomic, assign) NSInteger gallerySaveSource;
@property (nonatomic, strong, nullable) SCIGallerySaveMetadata *galleryMetadata;
@property (nonatomic, strong, nullable) SCIGalleryFile *galleryFile;
@property (nonatomic, assign) BOOL isFromGallery;

+ (instancetype)itemWithFileURL:(NSURL *)url;
+ (instancetype)itemWithImage:(UIImage *)image;
+ (instancetype)itemWithGalleryFile:(SCIGalleryFile *)file;
+ (SCIMediaItemType)mediaTypeForFileExtension:(NSString *)extension;

@end

NS_ASSUME_NONNULL_END
