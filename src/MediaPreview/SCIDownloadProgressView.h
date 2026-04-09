#import <UIKit/UIKit.h>

/**
 * SCIDownloadProgressView
 *
 * A minimal, iOS-native-style pill notification that slides down from the top of the screen.
 * Inspired by the AirPods/Dynamic Island pill indicators.
 *
 * Shows download progress with a thin inline progress bar.
 * On success, it switches to a completed state and callers can choose what to do next.
 * On error, the trailing button turns into retry.
 */
@interface SCIDownloadProgressView : UIView

/// Show the pill in the given view. Returns the instance.
+ (instancetype)showInView:(UIView *)view;

/// Update download progress (0.0 – 1.0).
- (void)setProgress:(float)progress animated:(BOOL)animated;

/// Transition the pill to a success state.
- (void)showSuccess;

/// Transition the pill to an error state and auto-dismiss.
- (void)showError:(NSString *)message;

/// Dismiss immediately.
- (void)dismiss;

/// Called when user taps the xmark while a download is in progress.
@property (nonatomic, copy) void(^onCancel)(void);

/// Called when user taps retry while in error state.
@property (nonatomic, copy) void(^onRetry)(void);

/// Called when user taps the pill body after success state is shown.
@property (nonatomic, copy) void(^onTapWhenCompleted)(void);

@end
