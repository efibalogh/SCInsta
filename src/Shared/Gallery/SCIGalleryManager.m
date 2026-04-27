#import "SCIGalleryManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonKeyDerivation.h>

static NSString * const kLockEnabledKey = @"scinsta_gallery_lock_enabled";
static NSString * const kKeychainService = @"com.socuul.scinsta.gallery.passcode";
static NSString * const kPBKDF2RecordPrefix = @"pbkdf2-sha256";
static uint32_t const kPBKDF2Rounds = 210000;
static size_t const kPBKDF2SaltLength = 16;
static size_t const kPBKDF2KeyLength = 32;

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

- (NSData *)pbkdf2HashForPasscode:(NSString *)passcode
                             salt:(NSData *)salt
                           rounds:(uint32_t)rounds
                        keyLength:(size_t)keyLength {
    NSData *passcodeData = [passcode dataUsingEncoding:NSUTF8StringEncoding];
    if (passcodeData.length == 0 || salt.length == 0 || rounds == 0 || keyLength == 0) return nil;

    NSMutableData *derivedKey = [NSMutableData dataWithLength:keyLength];
    int status = CCKeyDerivationPBKDF(kCCPBKDF2,
                                      passcodeData.bytes,
                                      passcodeData.length,
                                      salt.bytes,
                                      salt.length,
                                      kCCPRFHmacAlgSHA256,
                                      rounds,
                                      derivedKey.mutableBytes,
                                      keyLength);
    if (status != 0) return nil;
    return derivedKey;
}

- (NSData *)randomSaltData {
    NSMutableData *salt = [NSMutableData dataWithLength:kPBKDF2SaltLength];
    int status = SecRandomCopyBytes(kSecRandomDefault, salt.length, salt.mutableBytes);
    if (status != errSecSuccess) return nil;
    return salt;
}

- (NSString *)pbkdf2RecordForPasscode:(NSString *)passcode {
    NSData *salt = [self randomSaltData];
    if (salt.length == 0) return nil;

    NSData *hash = [self pbkdf2HashForPasscode:passcode
                                          salt:salt
                                        rounds:kPBKDF2Rounds
                                     keyLength:kPBKDF2KeyLength];
    if (hash.length == 0) return nil;

    NSString *saltB64 = [salt base64EncodedStringWithOptions:0];
    NSString *hashB64 = [hash base64EncodedStringWithOptions:0];
    return [NSString stringWithFormat:@"%@$%u$%@$%@", kPBKDF2RecordPrefix, kPBKDF2Rounds, saltB64, hashB64];
}

- (BOOL)parsePBKDF2Record:(NSString *)record
                   rounds:(uint32_t *)rounds
                     salt:(NSData * __autoreleasing *)salt
                     hash:(NSData * __autoreleasing *)hash {
    NSArray<NSString *> *parts = [record componentsSeparatedByString:@"$"];
    if (parts.count != 4) return NO;
    if (![parts[0] isEqualToString:kPBKDF2RecordPrefix]) return NO;

    NSUInteger parsedRounds = (NSUInteger)[parts[1] integerValue];
    if (parsedRounds == 0 || parsedRounds > UINT32_MAX) return NO;

    NSData *parsedSalt = [[NSData alloc] initWithBase64EncodedString:parts[2] options:0];
    NSData *parsedHash = [[NSData alloc] initWithBase64EncodedString:parts[3] options:0];
    if (parsedSalt.length == 0 || parsedHash.length == 0) return NO;

    if (rounds) *rounds = (uint32_t)parsedRounds;
    if (salt) *salt = parsedSalt;
    if (hash) *hash = parsedHash;
    return YES;
}

- (BOOL)isEqualInConstantTime:(NSData *)lhs other:(NSData *)rhs {
    if (lhs.length != rhs.length) return NO;

    const uint8_t *left = lhs.bytes;
    const uint8_t *right = rhs.bytes;
    uint8_t diff = 0;
    for (NSUInteger i = 0; i < lhs.length; i++) {
        diff |= (left[i] ^ right[i]);
    }
    return diff == 0;
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

    NSString *record = [self pbkdf2RecordForPasscode:passcode];
    if (record.length == 0) return NO;
    if (![self storePasscodeHash:record]) return NO;

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

    uint32_t rounds = 0;
    NSData *salt = nil;
    NSData *storedHash = nil;
    if (![self parsePBKDF2Record:stored rounds:&rounds salt:&salt hash:&storedHash]) {
        return NO;
    }

    NSData *candidateHash = [self pbkdf2HashForPasscode:passcode
                                                   salt:salt
                                                 rounds:rounds
                                              keyLength:storedHash.length];
    BOOL match = (candidateHash.length == storedHash.length) && [self isEqualInConstantTime:candidateHash other:storedHash];
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
