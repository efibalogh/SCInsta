#import "SCIVaultManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>

static NSString * const kLockEnabledKey = @"scinsta_vault_lock_enabled";
static NSString * const kKeychainService = @"com.socuul.scinsta.vault.passcode";

@implementation SCIVaultManager

+ (instancetype)sharedManager {
    static SCIVaultManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SCIVaultManager alloc] init];
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

- (void)lockVault {
    _isUnlocked = NO;
}

#pragma mark - Passcode hashing

- (NSString *)hashPasscode:(NSString *)passcode {
    NSString *salted = [NSString stringWithFormat:@"SCIVault_%@_Salt", passcode];
    NSData *data = [salted dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char md[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, md);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", md[i]];
    }
    return hex;
}

#pragma mark - Keychain

- (NSString *)getStoredPasscodeHash {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || result == NULL) return nil;

    NSData *data = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
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

- (SCIVaultBiometryType)biometryType {
    LAContext *ctx = [[LAContext alloc] init];
    NSError *err;
    if (![ctx canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&err]) {
        return SCIVaultBiometryTypeNone;
    }
    switch (ctx.biometryType) {
        case LABiometryTypeTouchID: return SCIVaultBiometryTypeTouchID;
        case LABiometryTypeFaceID:  return SCIVaultBiometryTypeFaceID;
        default:                    return SCIVaultBiometryTypeOther;
    }
}

- (NSString *)biometryLabel {
    switch ([self biometryType]) {
        case SCIVaultBiometryTypeTouchID: return @"Touch ID";
        case SCIVaultBiometryTypeFaceID:  return @"Face ID";
        case SCIVaultBiometryTypeOther:   return @"Biometrics";
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
        localizedReason:@"Unlock Media Vault"
                  reply:^(BOOL success, NSError *evalErr) {
        if (success) weakSelf.isUnlocked = YES;
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(success, evalErr); });
        }
    }];
}

@end
