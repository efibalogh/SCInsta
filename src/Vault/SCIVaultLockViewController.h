#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIVaultLockMode) {
    SCIVaultLockModeUnlock = 0,          // Verify the existing passcode.
    SCIVaultLockModeSetPasscode,         // Enter + confirm a new passcode.
    SCIVaultLockModeChangePasscode,      // Verify old + enter + confirm a new passcode.
};

/// Modal 4-6 digit passcode keypad used to unlock the vault or set/change the passcode.
@interface SCIVaultLockViewController : UIViewController

@property (nonatomic, assign) SCIVaultLockMode mode;

/// Called with YES when the user successfully completes the flow, NO if cancelled.
@property (nonatomic, copy, nullable) void (^completion)(BOOL success);

/// Presents the unlock flow, trying biometrics first if available, otherwise the passcode keypad.
+ (void)presentUnlockFromViewController:(UIViewController *)presenter
                             completion:(void (^)(BOOL success))completion;

/// Presents the passcode keypad for the given mode.
+ (void)presentMode:(SCIVaultLockMode)mode
   fromViewController:(UIViewController *)presenter
           completion:(void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
