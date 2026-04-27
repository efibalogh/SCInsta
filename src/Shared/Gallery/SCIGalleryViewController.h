#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIGalleryViewController : UIViewController

+ (void)presentGallery;

/// Initializes the gallery for browsing the given folder path. Pass nil for root.
- (instancetype)initWithFolderPath:(nullable NSString *)folderPath;

@end

NS_ASSUME_NONNULL_END
