#import <UIKit/UIKit.h>

@class SCIMediaItem;

@protocol SCIFullScreenContentDelegate <NSObject>
@optional
- (void)mediaContentDidTap:(UIViewController *)controller;
- (void)mediaContent:(UIViewController *)controller didFailWithError:(NSError *)error;
@end

NS_ASSUME_NONNULL_BEGIN

@interface SCIFullScreenImageViewController : UIViewController

@property (nonatomic, strong, readonly) SCIMediaItem *mediaItem;
@property (nonatomic, weak) id<SCIFullScreenContentDelegate> delegate;
@property (nonatomic, readonly) BOOL isZoomed;

- (instancetype)initWithMediaItem:(SCIMediaItem *)item;
- (void)preloadContent;
- (void)cleanup;
- (void)resetZoomIfNeeded;
- (void)forceResetZoom;

@end

NS_ASSUME_NONNULL_END
