#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import "SCIFullScreenImageViewController.h"

@class SCIMediaItem;

NS_ASSUME_NONNULL_BEGIN

@interface SCIFullScreenVideoViewController : UIViewController

@property (nonatomic, strong, readonly) SCIMediaItem *mediaItem;
@property (nonatomic, weak) id<SCIFullScreenContentDelegate> delegate;
@property (nonatomic, strong, readonly, nullable) UIView *contentOverlayView;

- (instancetype)initWithMediaItem:(SCIMediaItem *)item;
- (void)preloadContent;
- (void)prepareForDisplay;
- (void)cleanup;
- (void)setPlayerControlOverlayInsets:(UIEdgeInsets)insets animated:(BOOL)animated;
- (void)play;
- (void)pause;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
