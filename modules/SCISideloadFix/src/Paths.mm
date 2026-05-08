#import <objc/runtime.h>

#import "Header.h"

BOOL createDirectoryIfNotExists(NSString *path) {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:path]) {
		NSLog(@"[SCISideloadFix] directory already exists: %@", path);
		return YES;
	}

	NSError *error = nil;
	[fileManager createDirectoryAtPath:path
		   withIntermediateDirectories:YES
							attributes:nil
								 error:&error];

	if (error) {
		NSLog(@"[SCISideloadFix] failed to create directory at path (%@): %@", path, error);
		return NO;
	}

	NSLog(@"[SCISideloadFix] created directory at path: %@", path);
	return YES;
}

NSURL *getAppGroupPathIfExists() {
	static NSURL *cachedAppGroupPath = nil;
	if (cachedAppGroupPath) return cachedAppGroupPath;

	NSLog(@"[SCISideloadFix] fetching app group path...");

	LSBundleProxy *bundleProxy = [objc_getClass("LSBundleProxy") bundleProxyForCurrentProcess];
	if (!bundleProxy) {
		NSLog(@"[SCISideloadFix] failed to retrieve LSBundleProxy for the current process");
		return nil;
	}

	NSDictionary *entitlements = bundleProxy.entitlements;
	if (!entitlements || ![entitlements isKindOfClass:[NSDictionary class]]) {
		NSLog(@"[SCISideloadFix] failed to retrieve entitlements");
		return nil;
	}

	NSArray *appGroups = entitlements[@"com.apple.security.application-groups"];
	if (!appGroups) {
		NSLog(@"[SCISideloadFix] no app groups found in entitlements");
		return nil;
	}

	if (appGroups.count == 0) {
		NSLog(@"[SCISideloadFix] app group entitlement exists, but no app groups are configured");
		return nil;
	}

	NSString *appGroupName = [appGroups firstObject];
	NSLog(@"[SCISideloadFix] app group name: %@", appGroupName);

	NSDictionary *appGroupsPaths = bundleProxy.groupContainerURLs;
	if (!appGroupsPaths || ![appGroupsPaths isKindOfClass:[NSDictionary class]]) {
		NSLog(@"[SCISideloadFix] failed to retrieve group container URLs");
		return nil;
	}

	NSURL *ourAppGroupURL = appGroupsPaths[appGroupName];
	if (ourAppGroupURL) {
		cachedAppGroupPath = ourAppGroupURL;
		NSLog(@"[SCISideloadFix] app group path: %@", cachedAppGroupPath.path);
	} else {
		NSLog(@"[SCISideloadFix] no path found for app group name: %@", appGroupName);
	}
	
	return cachedAppGroupPath;
}
