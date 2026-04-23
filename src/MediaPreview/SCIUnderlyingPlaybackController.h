#import <UIKit/UIKit.h>

#import "SCIFullScreenMediaPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIUnderlyingPlaybackController : NSObject

- (instancetype)initWithPlaybackSource:(SCIFullScreenPlaybackSource)playbackSource
                            sourceView:(nullable UIView *)sourceView
                            controller:(nullable UIViewController *)controller;

- (void)beginSuppressionExcludingPreviewView:(nullable UIView *)previewView;
- (void)refreshAndApplySuppressionExcludingPreviewView:(nullable UIView *)previewView;
- (void)restorePlaybackIfNeeded;
- (BOOL)hasSuppressedSessions;

@end

NS_ASSUME_NONNULL_END
