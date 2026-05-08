#import "Header.h"

NSString *accessGroupId;
NSString *bundleId;

static void setRequiredIDs() {
	NSDictionary *query = @{
		(__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
		(__bridge NSString *)kSecAttrAccount: @"SCISideloadFixGenericEntry",
		(__bridge NSString *)kSecAttrService: @"",
		(__bridge id)kSecReturnAttributes: (id)kCFBooleanTrue
	};
	
	CFDictionaryRef result = nil;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
	if (status == errSecItemNotFound) {
		status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
	}
	if (status != errSecSuccess) {
		return;
	}
	
	bundleId = [[NSBundle mainBundle] bundleIdentifier];
	accessGroupId = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
	if (result) {  // uhh, okay
		CFRelease(result);
	}
}

__attribute__((constructor)) static void init() {
	setRequiredIDs();
	rebindSecFuncs();
}
