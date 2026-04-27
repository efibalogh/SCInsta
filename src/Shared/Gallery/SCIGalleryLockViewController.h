#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIGalleryLockMode) {
    SCIGalleryLockModeUnlock = 0,          // Verify the existing passcode.
    SCIGalleryLockModeSetPasscode,         // Enter + confirm a new passcode.
    SCIGalleryLockModeChangePasscode,      // Verify old + enter + confirm a new passcode.
};

/// Modal 4-6 digit passcode keypad used to unlock the gallery or set/change the passcode.
@interface SCIGalleryLockViewController : UIViewController

@property (nonatomic, assign) SCIGalleryLockMode mode;

/// Called with YES when the user successfully completes the flow, NO if cancelled.
@property (nonatomic, copy, nullable) void (^completion)(BOOL success);

/// Presents the unlock flow, trying biometrics first if available, otherwise the passcode keypad.
+ (void)presentUnlockFromViewController:(UIViewController *)presenter
                             completion:(void (^)(BOOL success))completion;

/// Presents the passcode keypad for the given mode.
+ (void)presentMode:(SCIGalleryLockMode)mode
   fromViewController:(UIViewController *)presenter
           completion:(void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
