#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, SCIFeedbackPillTone) {
    SCIFeedbackPillToneSuccess = 0,
    SCIFeedbackPillToneError = 1,
    SCIFeedbackPillToneInfo = 2
};

typedef NS_ENUM(NSUInteger, SCIFeedbackPillStyle) {
    SCIFeedbackPillStyleColorful = 0,
    SCIFeedbackPillStyleClean = 1,
    SCIFeedbackPillStyleDynamic = 2
};

@interface SCIFeedbackPillView : UIView

/// Shows a progress-style pill in the given view.
+ (instancetype)showInView:(UIView *)view;

/// Shows an auto-dismissing toast-style pill in the given view.
+ (instancetype)showToastInView:(UIView *)view
                       duration:(NSTimeInterval)duration
                          title:(NSString *)title
                       subtitle:(nullable NSString *)subtitle
                           icon:(nullable UIImage *)icon
                           tone:(SCIFeedbackPillTone)tone;

/// Sets the default style used by newly created pills.
+ (void)setDefaultStyle:(SCIFeedbackPillStyle)style;
+ (SCIFeedbackPillStyle)defaultStyle;

/// Updates progress (0.0 – 1.0) for progress-style pills.
- (void)setProgress:(float)progress animated:(BOOL)animated;
- (void)updateProgressTitle:(nullable NSString *)title subtitle:(nullable NSString *)subtitle;

/// Transitions the pill to a success state.
- (void)showSuccess;
- (void)showSuccessWithTitle:(nullable NSString *)title
                    subtitle:(nullable NSString *)subtitle
                        icon:(nullable UIImage *)icon;

/// Transitions the pill to an error state.
- (void)showError:(NSString *)message;
- (void)showErrorWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle
                      icon:(nullable UIImage *)icon;

/// Transitions the pill to an info state (for progress context).
- (void)showInfoWithTitle:(nullable NSString *)title
                 subtitle:(nullable NSString *)subtitle
                     icon:(nullable UIImage *)icon;

/// Dismisses the pill immediately.
- (void)dismiss;

/// Called when user taps the close button while a progress operation is running.
@property (nonatomic, copy) void(^onCancel)(void);

/// Called when user taps the pill body to retry while in error state.
@property (nonatomic, copy) void(^onRetry)(void);

/// Called when user taps the pill body after success state is shown.
@property (nonatomic, copy) void(^onTapWhenCompleted)(void);

/// Called after the pill has been fully removed from its superview.
@property (nonatomic, copy) void(^onDidDismiss)(void);

@end
