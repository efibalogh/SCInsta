#import "SCIGalleryManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>

static NSString * const kLockEnabledKey = @"scinsta_gallery_lock_enabled";
static NSString * const kKeychainService = @"com.socuul.scinsta.gallery.passcode";

@implementation SCIGalleryManager

+ (instancetype)sharedManager {
    static SCIGalleryManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SCIGalleryManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _isUnlocked = NO;
    }
    return self;
}

#pragma mark - Lock state

- (BOOL)isLockEnabled {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kLockEnabledKey]) return NO;
    return [self hasPasscode];
}

- (void)setIsLockEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kLockEnabledKey];
    if (!enabled) {
        _isUnlocked = YES;
    }
}

- (BOOL)hasPasscode {
    return [self getStoredPasscodeHash].length > 0;
}

- (void)lockGallery {
    _isUnlocked = NO;
}

#pragma mark - Passcode hashing

- (NSString *)hashPasscode:(NSString *)passcode saltPrefix:(NSString *)saltPrefix {
    NSString *salted = [NSString stringWithFormat:@"%@_%@_Salt", saltPrefix, passcode];
    NSData *data = [salted dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char md[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, md);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", md[i]];
    }
    return hex;
}

- (NSString *)hashPasscode:(NSString *)passcode {
    return [self hashPasscode:passcode saltPrefix:@"SCIGallery"];
}

#pragma mark - Keychain

- (NSString *)storedHashForService:(NSString *)service {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || result == NULL) return nil;

    NSData *data = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSString *)getStoredPasscodeHash {
    return [self storedHashForService:kKeychainService];
}

- (BOOL)storePasscodeHash:(NSString *)hash {
    [self deleteStoredPasscodeHash];
    NSData *data = [hash dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attrs = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    };
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)attrs, NULL);
    return status == errSecSuccess;
}

- (void)deleteStoredPasscodeHash {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
}

#pragma mark - Passcode operations

- (BOOL)setPasscode:(NSString *)passcode {
    if (passcode.length < 4 || passcode.length > 6) return NO;

    NSString *hash = [self hashPasscode:passcode];
    if (![self storePasscodeHash:hash]) return NO;

    self.isLockEnabled = YES;
    _isUnlocked = YES;
    return YES;
}

- (BOOL)changePasscodeFromOld:(NSString *)oldPasscode toNew:(NSString *)newPasscode {
    if (![self verifyPasscode:oldPasscode]) return NO;
    return [self setPasscode:newPasscode];
}

- (BOOL)verifyPasscode:(NSString *)passcode {
    if (passcode.length == 0) return NO;

    NSString *stored = [self getStoredPasscodeHash];
    if (stored.length == 0) return NO;

    NSString *candidate = [self hashPasscode:passcode];
    BOOL match = [stored isEqualToString:candidate];
    if (match) _isUnlocked = YES;
    return match;
}

- (void)removePasscode {
    [self deleteStoredPasscodeHash];
    self.isLockEnabled = NO;
}

#pragma mark - Biometrics

- (BOOL)isBiometricsAvailable {
    LAContext *ctx = [[LAContext alloc] init];
    NSError *err;
    return [ctx canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&err];
}

- (SCIGalleryBiometryType)biometryType {
    LAContext *ctx = [[LAContext alloc] init];
    NSError *err;
    if (![ctx canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&err]) {
        return SCIGalleryBiometryTypeNone;
    }
    switch (ctx.biometryType) {
        case LABiometryTypeTouchID: return SCIGalleryBiometryTypeTouchID;
        case LABiometryTypeFaceID:  return SCIGalleryBiometryTypeFaceID;
        default:                    return SCIGalleryBiometryTypeOther;
    }
}

- (NSString *)biometryLabel {
    switch ([self biometryType]) {
        case SCIGalleryBiometryTypeTouchID: return @"Touch ID";
        case SCIGalleryBiometryTypeFaceID:  return @"Face ID";
        case SCIGalleryBiometryTypeOther:   return @"Biometrics";
        default:                          return @"";
    }
}

- (void)authenticateWithBiometricsWithCompletion:(void (^)(BOOL, NSError *))completion {
    LAContext *ctx = [[LAContext alloc] init];
    NSError *err;
    if (![ctx canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&err]) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, err); });
        }
        return;
    }

    __weak typeof(self) weakSelf = self;
    [ctx evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
        localizedReason:@"Unlock Gallery"
                  reply:^(BOOL success, NSError *evalErr) {
        if (success) weakSelf.isUnlocked = YES;
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(success, evalErr); });
        }
    }];
}

@end
