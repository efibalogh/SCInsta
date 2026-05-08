#import "Header.h"

static NSURL *redirectedAppGroupURL(NSString *groupIdentifier) {
	if (![groupIdentifier hasPrefix:@"group"]) return nil;

	if (NSURL *appGroupURL = getAppGroupPathIfExists()) {
		return [appGroupURL URLByAppendingPathComponent:groupIdentifier];
	}

	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsPath = [paths lastObject];
	if (!documentsPath) return nil;

	NSString *fakePath = [documentsPath stringByAppendingPathComponent:groupIdentifier];
	return [NSURL fileURLWithPath:fakePath];
}

%hook CKContainer
- (id)_setupWithContainerID:(id)a options:(id)b { return nil; }
- (id)_initWithContainerIdentifier:(id)a { return nil; }
%end

%hook CKEntitlements
- (id)initWithEntitlementsDict:(NSDictionary *)entitlements {
	NSMutableDictionary *mutEntitlements = [entitlements mutableCopy];
	[mutEntitlements removeObjectForKey:@"com.apple.developer.icloud-container-environment"];
	[mutEntitlements removeObjectForKey:@"com.apple.developer.icloud-services"];
	return %orig([mutEntitlements copy]);  // why? whatever
}
%end

%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
	if (NSURL *fakeAppGroupURL = redirectedAppGroupURL(groupIdentifier)) {
		createDirectoryIfNotExists(fakeAppGroupURL.path);
		return fakeAppGroupURL;
	}

	return %orig(groupIdentifier);
}
%end

static BOOL isAppExtensionProcess(void) {
	static BOOL cached = NO;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		cached = ([[NSBundle mainBundle] infoDictionary][@"NSExtension"] != nil);
	});
	return cached;
}

%hook NSUserDefaults
- (id)_initWithSuiteName:(NSString *)suiteName container:(NSURL *)container {
	NSLog(@"[SCISideloadFix] hooking NSUserDefaults init...");

	if (!isAppExtensionProcess()) {
		NSLog(@"[SCISideloadFix] main app process, defaulting to original defaults container");
		return %orig(suiteName, container);
	}

	if (![suiteName hasPrefix:@"group"]) {
		NSLog(@"[SCISideloadFix] suite name '%@' does not start with 'group' ,, defaulting to original container", suiteName);
		return %orig(suiteName, container);
	}

	if (NSURL *customContainerURL = redirectedAppGroupURL(suiteName)) {
		NSLog(@"[SCISideloadFix] using custom container URL: %@", customContainerURL);
		createDirectoryIfNotExists(customContainerURL.path);
		return %orig(suiteName, customContainerURL);
	}

	NSLog(@"[SCISideloadFix] failed to construct valid URL for suite '%@' in app group container", suiteName);
	return %orig(suiteName, container);
}
%end
