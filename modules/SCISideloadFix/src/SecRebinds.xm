#import <Security/Security.h>

#import "Header.h"
#import "../fishhook/fishhook.h"

static OSStatus (*origSecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result);
static OSStatus (*origSecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
static OSStatus (*origSecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
static OSStatus (*origSecItemDelete)(CFDictionaryRef query);

static OSStatus zxSecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
	NSMutableDictionary *mutableAttributes = [(__bridge NSDictionary *)attributes mutableCopy];
	mutableAttributes[(__bridge NSString *)kSecAttrAccessGroup] = accessGroupId;
	return origSecItemAdd((__bridge CFDictionaryRef)mutableAttributes, result);
}

static OSStatus zxSecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
	NSMutableDictionary *mutableQuery = [(__bridge NSDictionary *)query mutableCopy];
	mutableQuery[(__bridge NSString *)kSecAttrAccessGroup] = accessGroupId;
	return origSecItemCopyMatching((__bridge CFDictionaryRef)mutableQuery, result);
}

static OSStatus zxSecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
	NSMutableDictionary *mutableQuery = [(__bridge NSDictionary *)query mutableCopy];
	mutableQuery[(__bridge NSString *)kSecAttrAccessGroup] = accessGroupId;
	return origSecItemUpdate((__bridge CFDictionaryRef)mutableQuery, attributesToUpdate);
}

static OSStatus zxSecItemDelete(CFDictionaryRef query) {
	NSMutableDictionary *mutableQuery = [(__bridge NSDictionary *)query mutableCopy];
	mutableQuery[(__bridge NSString *)kSecAttrAccessGroup] = accessGroupId;
	return origSecItemDelete((__bridge CFDictionaryRef)mutableQuery);
}

void rebindSecFuncs() {
	struct rebinding rebinds[4] = {
		{"SecItemAdd", (void *)zxSecItemAdd, (void **)&origSecItemAdd},
		{"SecItemCopyMatching", (void *)zxSecItemCopyMatching, (void **)&origSecItemCopyMatching},
		{"SecItemUpdate", (void *)zxSecItemUpdate, (void **)&origSecItemUpdate},
		{"SecItemDelete", (void *)zxSecItemDelete, (void **)&origSecItemDelete}
	};
	NSLog(@"[SCISideloadFix] rebind_symbols result: %d", rebind_symbols(rebinds, 4));
}