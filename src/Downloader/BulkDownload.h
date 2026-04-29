#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SCIGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SCIBulkDownloadOperation) {
    SCIBulkDownloadOperationSaveToPhotos = 1,
    SCIBulkDownloadOperationSaveToGallery = 2,
    SCIBulkDownloadOperationShare = 3,
    SCIBulkDownloadOperationCopyMedia = 4,
};

@interface SCIBulkDownloadItem : NSObject

@property (nonatomic, strong, nullable) NSURL *fileURL;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, copy, nullable) NSString *fileExtension;
@property (nonatomic, assign) BOOL video;
@property (nonatomic, strong, nullable) SCIGallerySaveMetadata *galleryMetadata;
@property (nonatomic, copy, nullable) NSString *linkString;

+ (instancetype)itemWithURL:(NSURL *)url
              fileExtension:(nullable NSString *)fileExtension
                    isVideo:(BOOL)isVideo
                   metadata:(nullable SCIGallerySaveMetadata *)metadata
                 linkString:(nullable NSString *)linkString;
+ (instancetype)itemWithImage:(UIImage *)image
                     metadata:(nullable SCIGallerySaveMetadata *)metadata;

@end

@interface SCIBulkDownloadCoordinator : NSObject

+ (void)performOperation:(SCIBulkDownloadOperation)operation
                   items:(NSArray<SCIBulkDownloadItem *> *)items
        actionIdentifier:(NSString *)actionIdentifier
               presenter:(nullable UIViewController *)presenter
              anchorView:(nullable UIView *)anchorView;

@end

NS_ASSUME_NONNULL_END
