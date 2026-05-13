#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, SCINotificationTone) {
    SCINotificationToneSuccess = 0,
    SCINotificationToneError = 1,
    SCINotificationToneInfo = 2
};

@interface SCINotificationPillView : UIView

+ (instancetype)progressPill;
+ (instancetype)toastPillWithTitle:(NSString *)title
                           subtitle:(nullable NSString *)subtitle
                               icon:(nullable UIImage *)icon
                               tone:(SCINotificationTone)tone;

- (void)setPresentationTopConstraint:(NSLayoutConstraint *)constraint;

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

/// Called when a progress pill transitions to a visible terminal tone.
@property (nonatomic, copy) void(^onTonePresented)(SCINotificationTone tone);

/// Called after the pill has been fully removed from its superview.
@property (nonatomic, copy) void(^onDidDismiss)(void);

@end
