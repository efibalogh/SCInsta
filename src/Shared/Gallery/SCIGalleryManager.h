#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIGalleryBiometryType) {
    SCIGalleryBiometryTypeNone = 0,
    SCIGalleryBiometryTypeTouchID,
    SCIGalleryBiometryTypeFaceID,
    SCIGalleryBiometryTypeOther
};

/// Manages the gallery passcode lock and biometric unlock.
///
/// Passcode hashes are stored in the keychain under service
/// `com.socuul.scinsta.gallery.passcode`, using PBKDF2-HMAC-SHA256 with per-passcode random salt.
/// The "enabled" flag is stored in NSUserDefaults under `scinsta_gallery_lock_enabled`.
@interface SCIGalleryManager : NSObject

+ (instancetype)sharedManager;

/// Whether the gallery lock is enabled. Setting to NO removes the passcode and unlocks the gallery.
@property (nonatomic, assign) BOOL isLockEnabled;

/// Whether the gallery is currently unlocked for this app session.
@property (nonatomic, assign) BOOL isUnlocked;

/// YES if a passcode hash is currently stored in the keychain.
- (BOOL)hasPasscode;

/// Convenience — sets `isUnlocked = NO`.
- (void)lockGallery;

// MARK: - Passcode

/// Stores a new passcode. Passcode length must be between 4 and 6 characters.
/// Also enables the lock.
- (BOOL)setPasscode:(NSString *)passcode;

/// Replaces the stored passcode with a new one, after verifying the old one.
- (BOOL)changePasscodeFromOld:(NSString *)oldPasscode toNew:(NSString *)newPasscode;

/// Returns YES if the passcode matches the stored hash. Sets `isUnlocked = YES` on success.
- (BOOL)verifyPasscode:(NSString *)passcode;

/// Removes the stored passcode hash and disables the lock.
- (void)removePasscode;

// MARK: - Biometrics

- (BOOL)isBiometricsAvailable;
- (SCIGalleryBiometryType)biometryType;

/// The user-visible label for the current biometry type, e.g. "Face ID", "Touch ID".
- (NSString *)biometryLabel;

/// Authenticates with biometrics. Calls `completion` on the main queue with success + optional error.
- (void)authenticateWithBiometricsWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
