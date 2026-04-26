#import "Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "Shared/MediaPreview/SCIMediaCacheManager.h"
#import "Shared/Vault/SCIVaultPaths.h"

static NSNumber *SCINumericValueForSelector(id target, NSString *selectorName) {
    if (!target || !selectorName.length) return nil;

    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return nil;

    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    const char *returnType = signature.methodReturnType;
    if (!returnType || !returnType[0]) return nil;

    switch (returnType[0]) {
        case '@': {
            id value = ((id (*)(id, SEL))objc_msgSend)(target, selector);
            if ([value respondsToSelector:@selector(doubleValue)]) {
                return @([value doubleValue]);
            }
            return nil;
        }
        case 'd':
            return @(((double (*)(id, SEL))objc_msgSend)(target, selector));
        case 'f':
            return @((double)((float (*)(id, SEL))objc_msgSend)(target, selector));
        case 'q':
            return @((double)((long long (*)(id, SEL))objc_msgSend)(target, selector));
        case 'Q':
            return @((double)((unsigned long long (*)(id, SEL))objc_msgSend)(target, selector));
        case 'i':
            return @((double)((int (*)(id, SEL))objc_msgSend)(target, selector));
        case 'I':
            return @((double)((unsigned int (*)(id, SEL))objc_msgSend)(target, selector));
        case 'l':
            return @((double)((long (*)(id, SEL))objc_msgSend)(target, selector));
        case 'L':
            return @((double)((unsigned long (*)(id, SEL))objc_msgSend)(target, selector));
        case 's':
            return @((double)((short (*)(id, SEL))objc_msgSend)(target, selector));
        case 'S':
            return @((double)((unsigned short (*)(id, SEL))objc_msgSend)(target, selector));
        case 'c':
            return @((double)((char (*)(id, SEL))objc_msgSend)(target, selector));
        case 'C':
            return @((double)((unsigned char (*)(id, SEL))objc_msgSend)(target, selector));
        case 'B':
            return @((double)((BOOL (*)(id, SEL))objc_msgSend)(target, selector));
        default:
            return nil;
    }
}

static id SCIObjectForSelector(id target, NSString *selectorName) {
    if (!target || !selectorName.length) return nil;

    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return nil;

    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static id SCIKVCObject(id target, NSString *key) {
    if (!target || !key.length) return nil;

    @try {
        return [target valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSURL *SCIURLFromStringOrURL(id value) {
    if (!value) return nil;

    if ([value isKindOfClass:[NSURL class]]) {
        return value;
    }

    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return [NSURL URLWithString:(NSString *)value];
    }

    return nil;
}

static double SCIDoubleValue(id value) {
    if (!value) return 0.0;

    if ([value respondsToSelector:@selector(doubleValue)]) {
        return [value doubleValue];
    }

    return 0.0;
}

static NSInteger SCIIntegerValue(id value) {
    if (!value) return 0;

    if ([value respondsToSelector:@selector(integerValue)]) {
        return [value integerValue];
    }

    return 0;
}

static NSArray *SCIArrayFromCollection(id collection) {
    if (!collection ||
        [collection isKindOfClass:[NSDictionary class]] ||
        [collection isKindOfClass:[NSString class]] ||
        [collection isKindOfClass:[NSURL class]]) {
        return nil;
    }

    if ([collection isKindOfClass:[NSArray class]]) {
        return collection;
    }

    if ([collection isKindOfClass:[NSOrderedSet class]]) {
        return [(NSOrderedSet *)collection array];
    }

    if ([collection isKindOfClass:[NSSet class]]) {
        return [(NSSet *)collection allObjects];
    }

    if ([collection conformsToProtocol:@protocol(NSFastEnumeration)]) {
        NSMutableArray *items = [NSMutableArray array];
        for (id item in collection) {
            [items addObject:item];
        }
        return items;
    }

    return nil;
}

static NSString * const kSCICacheAutoClearModeKey = @"cache_auto_clear_mode";
static NSString * const kSCICacheLastClearedAtKey = @"cache_last_cleared_at";

static UIWindow *SCIFeedbackPresentationWindow(void) {
    UIViewController *topController = topMostController();
    UIWindow *window = topController.view.window;
    if (window && !window.hidden) {
        return window;
    }

    UIApplication *application = [UIApplication sharedApplication];
    if (application.keyWindow && !application.keyWindow.hidden) {
        return application.keyWindow;
    }

    for (UIWindow *candidate in [application.windows reverseObjectEnumerator]) {
        if (!candidate.hidden && candidate.alpha > 0.01 && candidate.windowLevel <= UIWindowLevelAlert) {
            return candidate;
        }
    }

    return application.windows.firstObject;
}

static UIView *SCIFeedbackPresentationView(void) {
    UIWindow *window = SCIFeedbackPresentationWindow();
    if (window) {
        return window;
    }

    UIViewController *topController = topMostController();
    return topController.view;
}

static NSTimeInterval const kSCISuccessToastDuration = 1.8;

static SCIFeedbackPillStyle SCIFeedbackPillStyleFromPreferenceString(NSString *stylePreference) {
    if ([stylePreference isEqualToString:@"colorful"]) {
        return SCIFeedbackPillStyleColorful;
    }

    return SCIFeedbackPillStyleClean;
}

static void SCIApplyFeedbackPillStylePreference(void) {
    NSString *stylePreference = [SCIUtils getStringPref:@"feedback_pill_style"];
    [SCIFeedbackPillView setDefaultStyle:SCIFeedbackPillStyleFromPreferenceString(stylePreference)];
}

static void SCIMigrateLiquidGlassPrefsIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        if ([ud objectForKey:@"liquid_glass"] == nil) {
            return;
        }
        BOOL unified = [ud boolForKey:@"liquid_glass"];
        if ([ud objectForKey:@"liquid_glass_surfaces"] == nil) {
            [ud setBool:unified forKey:@"liquid_glass_surfaces"];
        }
        if ([ud objectForKey:@"liquid_glass_buttons"] == nil) {
            [ud setBool:unified forKey:@"liquid_glass_buttons"];
        }
        [ud removeObjectForKey:@"liquid_glass"];
    });
}

/// Launcher keys that mirror `origin/main`’s `liquidGlassEnabledBool:` when the per-key pref is unset.
static NSSet<NSString *> *SCILiquidGlassLauncherKeysUsingSurfacesFallback(void) {
    static NSSet<NSString *> *set;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSSet setWithArray:@[
            @"liquid_glass_in_app_notifications",
            @"liquid_glass_context_menus",
            @"liquid_glass_toasts",
            @"liquid_glass_toast_peek",
            @"liquid_glass_alert_dialogs",
        ]];
    });
    return set;
}

static NSArray<NSString *> *SCIAllLiquidGlassPreferenceKeys(void) {
    static NSArray<NSString *> *keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[
            @"liquid_glass_surfaces",
            @"liquid_glass_buttons",
            @"liquid_glass_in_app_notifications",
            @"liquid_glass_context_menus",
            @"liquid_glass_toasts",
            @"liquid_glass_toast_peek",
            @"liquid_glass_alert_dialogs",
            @"liquid_glass_icon_bar_buttons",
            @"liquid_glass_internal_debugger",
            @"liquid_glass_core_class",
            @"liquid_glass_nav_is_enabled",
            @"liquid_glass_nav_default_value_set",
            @"liquid_glass_nav_home_feed_header",
            @"liquid_glass_swizzle_toggle",
            @"liquid_glass_badged_nav_button",
            @"liquid_glass_video_back_button",
            @"liquid_glass_video_camera_button",
            @"liquid_glass_alert_dialog_actions",
            @"liquid_glass_interactive_tab_bar",
        ];
    });
    return keys;
}

static NSArray *SCIImageVersionsFromPhoto(IGPhoto *photo) {
    if (!photo) return nil;

    NSArray *versions = SCIArrayFromCollection(SCIObjectForSelector(photo, @"imageVersions"));
    if (versions.count > 0) return versions;

    versions = SCIArrayFromCollection([SCIUtils getIvarForObj:photo name:"_originalImageVersions"]);
    if (versions.count > 0) return versions;

    versions = SCIArrayFromCollection(SCIObjectForSelector(photo, @"imageVersionDictionaries"));
    if (versions.count > 0) return versions;

    versions = SCIArrayFromCollection([SCIUtils getIvarForObj:photo name:"_imageVersions"]);
    if (versions.count > 0) return versions;

    versions = SCIArrayFromCollection([SCIUtils getIvarForObj:photo name:"_imageVersionDictionaries"]);
    return versions.count > 0 ? versions : nil;
}

static NSArray *SCIVideoVersionsFromVideo(IGVideo *video) {
    if (!video) return nil;

    NSArray *versions = SCIArrayFromCollection(SCIObjectForSelector(video, @"videoVersions"));
    if (versions.count > 0) return versions;

    versions = SCIArrayFromCollection(SCIObjectForSelector(video, @"videoVersionDictionaries"));
    if (versions.count > 0) return versions;

    versions = SCIArrayFromCollection([SCIUtils getIvarForObj:video name:"_videoVersions"]);
    if (versions.count > 0) return versions;

    versions = SCIArrayFromCollection([SCIUtils getIvarForObj:video name:"_videoVersionDictionaries"]);
    return versions.count > 0 ? versions : nil;
}

static NSArray<NSDictionary *> *SCISortedMediaVariantsFromVersions(NSArray *versions) {
    if (![versions isKindOfClass:[NSArray class]] || versions.count == 0) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *variants = [NSMutableArray array];
    NSMutableSet<NSString *> *seenURLs = [NSMutableSet set];

    for (id version in versions) {
        id rawURL = nil;
        id widthValue = nil;
        id heightValue = nil;
        id bandwidthValue = nil;

        if ([version isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)version;
            rawURL = dict[@"url"] ?: dict[@"urlString"];
            widthValue = dict[@"width"];
            heightValue = dict[@"height"];
            bandwidthValue = dict[@"bandwidth"];
        } else {
            rawURL = SCIObjectForSelector(version, @"url");
            if (!rawURL) {
                rawURL = SCIObjectForSelector(version, @"urlString");
            }
            widthValue = SCINumericValueForSelector(version, @"width");
            heightValue = SCINumericValueForSelector(version, @"height");
            bandwidthValue = SCINumericValueForSelector(version, @"bandwidth");
        }

        NSURL *url = SCIURLFromStringOrURL(rawURL);
        if (!url) continue;

        NSString *absolute = url.absoluteString;
        if (absolute.length == 0 || [seenURLs containsObject:absolute]) {
            continue;
        }
        [seenURLs addObject:absolute];

        [variants addObject:@{
            @"url": url,
            @"width": @(SCIDoubleValue(widthValue)),
            @"height": @(SCIDoubleValue(heightValue)),
            @"bandwidth": @(SCIIntegerValue(bandwidthValue))
        }];
    }

    [variants sortUsingComparator:^NSComparisonResult(NSDictionary *lhs, NSDictionary *rhs) {
        double lhsArea = [lhs[@"width"] doubleValue] * [lhs[@"height"] doubleValue];
        double rhsArea = [rhs[@"width"] doubleValue] * [rhs[@"height"] doubleValue];

        if (lhsArea > rhsArea) return NSOrderedAscending;
        if (lhsArea < rhsArea) return NSOrderedDescending;

        NSInteger lhsBandwidth = [lhs[@"bandwidth"] integerValue];
        NSInteger rhsBandwidth = [rhs[@"bandwidth"] integerValue];
        if (lhsBandwidth > rhsBandwidth) return NSOrderedAscending;
        if (lhsBandwidth < rhsBandwidth) return NSOrderedDescending;

        return NSOrderedSame;
    }];

    return variants;
}

static NSURL *SCIHighestQualityURLFromVersions(NSArray *versions) {
    NSArray<NSDictionary *> *variants = SCISortedMediaVariantsFromVersions(versions);
    if (variants.count == 0) return nil;

    id value = variants.firstObject[@"url"];
    return [value isKindOfClass:[NSURL class]] ? value : nil;
}

static NSURL *SCIURLFromVideoURLCollection(id collection) {
    if (!collection) return nil;

    NSArray *items = SCIArrayFromCollection(collection);

    if (!items) {
        return SCIURLFromStringOrURL(collection);
    }

    for (id item in items) {
        NSURL *url = nil;

        if ([item isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)item;
            url = SCIURLFromStringOrURL(dict[@"url"] ?: dict[@"urlString"]);
        } else {
            url = SCIURLFromStringOrURL(item);
        }

        if (url) return url;
    }

    return nil;
}

static NSURL *SCIProfilePictureURLFromInfo(id info) {
    if (!info) return nil;

    NSURL *url = SCIURLFromStringOrURL(SCIObjectForSelector(info, @"url"));
    if (url) return url;

    url = SCIURLFromStringOrURL(SCIObjectForSelector(info, @"urlString"));
    if (url) return url;

    if ([info isKindOfClass:[NSDictionary class]]) {
        NSDictionary *infoDictionary = (NSDictionary *)info;
        url = SCIURLFromStringOrURL(infoDictionary[@"url"] ?: infoDictionary[@"urlString"]);
        if (url) return url;
    }

    return nil;
}

static NSURL *SCIHDProfilePicURL(id user) {
    if (!user) return nil;

    NSURL *url = SCIProfilePictureURLFromInfo(SCIObjectForSelector(user, @"hdProfilePicUrlInfo"));
    if (url) return url;

    url = SCIURLFromStringOrURL(SCIObjectForSelector(user, @"HDProfilePicURL"));
    if (url) return url;

    url = SCIProfilePictureURLFromInfo(SCIObjectForSelector(user, @"_private_hdProfilePicUrlInfo"));
    if (url) return url;

    url = SCIProfilePictureURLFromInfo(SCIObjectForSelector(user, @"HDProfilePicURLInfo"));
    if (url) return url;

    url = SCIURLFromStringOrURL(SCIObjectForSelector(user, @"profile_pic_url_hd"));
    if (url) return url;

    return SCIURLFromStringOrURL(SCIKVCObject(user, @"profile_pic_url_hd"));
}

static NSURL *SCIThumbProfilePicURL(id user) {
    if (!user) return nil;

    NSURL *url = SCIURLFromStringOrURL(SCIObjectForSelector(user, @"derivedProfilePicURL"));
    if (url) return url;

    url = SCIURLFromStringOrURL(SCIObjectForSelector(user, @"profilePicURLString"));
    if (url) return url;

    url = SCIURLFromStringOrURL(SCIObjectForSelector(user, @"profilePicURL"));
    if (url) return url;

    url = SCIURLFromStringOrURL(SCIObjectForSelector(user, @"_private_profilePicURLString"));
    if (url) return url;

    url = SCIURLFromStringOrURL(SCIObjectForSelector(user, @"_private_profilePicUrl"));
    if (url) return url;

    url = SCIURLFromStringOrURL(SCIObjectForSelector(user, @"profile_pic_url"));
    if (url) return url;

    return SCIURLFromStringOrURL(SCIKVCObject(user, @"profile_pic_url"));
}

static BOOL SCIInstagramHostMatchesCanonical(NSString *host) {
    if (host.length == 0) return NO;
    NSString *lower = host.lowercaseString;
    return [lower isEqualToString:@"instagram.com"]
        || [lower isEqualToString:@"www.instagram.com"]
        || [lower isEqualToString:@"instagr.am"]
        || [lower hasSuffix:@".instagram.com"];
}

static BOOL SCIInstagramPathUsesSharePrefix(NSArray<NSString *> *segments) {
    if (segments.count < 2) return NO;
    NSString *candidate = segments[1].lowercaseString;
    return [candidate isEqualToString:@"p"]
        || [candidate isEqualToString:@"reel"]
        || [candidate isEqualToString:@"reels"]
        || [candidate isEqualToString:@"tv"];
}

static NSArray<NSString *> *SCISanitizedInstagramPathSegments(NSArray<NSString *> *segments) {
    if (segments.count >= 3 && SCIInstagramPathUsesSharePrefix(segments)) {
        return [segments subarrayWithRange:NSMakeRange(1, segments.count - 1)];
    }
    return segments;
}

static NSArray<NSURLQueryItem *> *SCISanitizedInstagramQueryItems(NSArray<NSURLQueryItem *> *items) {
    if (items.count == 0) return nil;

    static NSSet<NSString *> *blockedKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockedKeys = [NSSet setWithArray:@[
            @"igsh", @"igshid", @"ig_rid", @"ig_mid",
            @"utm_source", @"utm_medium", @"utm_campaign", @"utm_term", @"utm_content",
            @"fbclid"
        ]];
    });

    NSMutableArray<NSURLQueryItem *> *kept = [NSMutableArray array];
    for (NSURLQueryItem *item in items) {
        if (![blockedKeys containsObject:item.name.lowercaseString]) {
            [kept addObject:item];
        }
    }
    return kept.count > 0 ? kept : nil;
}

@implementation SCIUtils

+ (BOOL)getBoolPref:(NSString *)key {
    if (![key length] || [[NSUserDefaults standardUserDefaults] objectForKey:key] == nil) return false;

    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}
+ (double)getDoublePref:(NSString *)key {
    if (![key length] || [[NSUserDefaults standardUserDefaults] objectForKey:key] == nil) return 0;

    return [[NSUserDefaults standardUserDefaults] doubleForKey:key];
}
+ (NSString *)getStringPref:(NSString *)key {
    if (![key length] || [[NSUserDefaults standardUserDefaults] objectForKey:key] == nil) return @"";

    return [[NSUserDefaults standardUserDefaults] stringForKey:key];
}

// MARK: Misc

+ (NSString *)IGVersionString {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
};
+ (BOOL)isNotch {
    return [[[UIApplication sharedApplication] keyWindow] safeAreaInsets].bottom > 0;
};

+ (BOOL)existingLongPressGestureRecognizerForView:(UIView *)view {
    NSArray *allRecognizers = view.gestureRecognizers;

    for (UIGestureRecognizer *recognizer in allRecognizers) {
        if ([[recognizer class] isSubclassOfClass:[UILongPressGestureRecognizer class]]) {
            return YES;
        }
    }

    return NO;
}

+ (void)sci_normalizeLiquidGlassPreferences {
    SCIMigrateLiquidGlassPrefsIfNeeded();
}

+ (_Bool)sci_liquidGlassLauncherPrefKey:(NSString *)key orig:(_Bool)fallback {
    SCIMigrateLiquidGlassPrefsIfNeeded();
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:key] != nil) {
        if ([ud boolForKey:key]) {
            return YES;
        }
        return fallback;
    }
    if ([SCILiquidGlassLauncherKeysUsingSurfacesFallback() containsObject:key]) {
        BOOL surfaces = [SCIUtils getBoolPref:@"liquid_glass_surfaces"];
        return surfaces ? YES : fallback;
    }
    return fallback;
}

+ (BOOL)sci_liquidGlassHookPrefKey:(NSString *)key orig:(SCILiquidGlassBoolMsg)orig selfPtr:(id)selfPtr sel:(SEL)sel {
    SCIMigrateLiquidGlassPrefsIfNeeded();
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL origVal = orig ? orig(selfPtr, sel) : NO;
    if ([ud objectForKey:key] == nil) {
        return origVal;
    }
    if ([ud boolForKey:key]) {
        return YES;
    }
    return origVal;
}

+ (BOOL)sci_anyLiquidGlassEnabled {
    SCIMigrateLiquidGlassPrefsIfNeeded();
    for (NSString *key in SCIAllLiquidGlassPreferenceKeys()) {
        if ([SCIUtils getBoolPref:key]) {
            return YES;
        }
    }
    return NO;
}

+ (void)applyLiquidGlassNavigationExperimentOverride {
    Class navHelper = objc_getClass("IGLiquidGlassExperimentHelper.IGLiquidGlassNavigationExperimentHelper");
    if (!navHelper || ![navHelper respondsToSelector:@selector(shared)]) {
        return;
    }

    id shared = ((id (*)(id, SEL))objc_msgSend)(navHelper, @selector(shared));
    if (!shared || ![shared respondsToSelector:@selector(overrideIsEnabled:)]) {
        return;
    }

    BOOL on = [SCIUtils sci_anyLiquidGlassEnabled];
    ((void (*)(id, SEL, BOOL))objc_msgSend)(shared, @selector(overrideIsEnabled:), on);
}

+ (void)cleanCache {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<NSError *> *deletionErrors = [NSMutableArray array];

    // Temp folder
    // * disabled bc app crashed trying to delete certain files inside it
    // todo: remove the above disclaimer if this new code doesn't cause crashing
    NSArray *tempFolderContents = [fileManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:NSTemporaryDirectory()] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

    for (NSURL *fileURL in tempFolderContents) {
        NSError *cacheItemDeletionError;
        [fileManager removeItemAtURL:fileURL error:&cacheItemDeletionError];

        if (cacheItemDeletionError) [deletionErrors addObject:cacheItemDeletionError];
    }

    // Analytics folder
    NSString *analyticsFolder = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Application Support/com.burbn.instagram/analytics"];
    NSArray *analyticsFolderContents = [fileManager contentsOfDirectoryAtURL:[[NSURL alloc] initFileURLWithPath:analyticsFolder] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

    for (NSURL *fileURL in analyticsFolderContents) {
        NSError *cacheItemDeletionError;
        [fileManager removeItemAtURL:fileURL error:&cacheItemDeletionError];

        if (cacheItemDeletionError) [deletionErrors addObject:cacheItemDeletionError];
    }
    
    // Caches folder
    NSString *cachesFolder = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Caches"];
    NSArray *cachesFolderContents = [fileManager contentsOfDirectoryAtURL:[[NSURL alloc] initFileURLWithPath:cachesFolder] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    for (NSURL *fileURL in cachesFolderContents) {
        NSError *cacheItemDeletionError;
        [fileManager removeItemAtURL:fileURL error:&cacheItemDeletionError];

        if (cacheItemDeletionError) [deletionErrors addObject:cacheItemDeletionError];
    }

    NSURL *previewCacheURL = [[[SCIMediaCacheManager sharedManager] valueForKey:@"cacheRootURL"] copy];
    if (previewCacheURL) {
        NSError *previewCacheDeletionError = nil;
        [fileManager removeItemAtURL:previewCacheURL error:&previewCacheDeletionError];
        if (previewCacheDeletionError) [deletionErrors addObject:previewCacheDeletionError];
    }

    // Log errors
    if (deletionErrors.count > 1) {

        for (NSError *error in deletionErrors) {
            NSLog(@"[SCInsta] File Deletion Error: %@", error);
        }

    }

    [SCIUtils markCacheClearedNow];
}

+ (NSString *)cacheAutoClearMode {
    NSString *mode = [SCIUtils getStringPref:kSCICacheAutoClearModeKey];
    return mode.length > 0 ? mode : @"never";
}

+ (BOOL)shouldAutomaticallyClearCacheNow {
    NSString *mode = [self cacheAutoClearMode];
    if ([mode isEqualToString:@"never"]) return NO;
    if ([mode isEqualToString:@"always"]) return YES;

    NSDate *lastClearedAt = [[NSUserDefaults standardUserDefaults] objectForKey:kSCICacheLastClearedAtKey];
    if (![lastClearedAt isKindOfClass:[NSDate class]]) return YES;

    NSTimeInterval interval = 0.0;
    if ([mode isEqualToString:@"daily"]) interval = 24.0 * 60.0 * 60.0;
    else if ([mode isEqualToString:@"weekly"]) interval = 7.0 * 24.0 * 60.0 * 60.0;
    else if ([mode isEqualToString:@"monthly"]) interval = 30.0 * 24.0 * 60.0 * 60.0;
    else return NO;

    return [[NSDate date] timeIntervalSinceDate:lastClearedAt] >= interval;
}

+ (void)markCacheClearedNow {
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kSCICacheLastClearedAtKey];
}

+ (void)evaluateAutomaticCacheClearIfNeeded {
    if (![self shouldAutomaticallyClearCacheNow]) return;
    NSLog(@"[SCInsta] Automatically clearing cache...");
    [self cleanCache];
}

// MARK: Display View Controllers
+ (void)showMediaPreview:(NSURL *)fileURL {
    [SCIFullScreenMediaPlayer showFileURL:fileURL];
}
+ (void)showShareVC:(id)item {
    UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
    if (is_iPad()) {
        acVC.popoverPresentationController.sourceView = topMostController().view;
        acVC.popoverPresentationController.sourceRect = CGRectMake(topMostController().view.bounds.size.width / 2.0, topMostController().view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    [topMostController() presentViewController:acVC animated:true completion:nil];
}
+ (void)showSettingsVC:(UIWindow *)window {
    UIViewController *rootController = [window rootViewController];
    SCISettingsViewController *settingsViewController = [SCISettingsViewController new];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    
    [rootController presentViewController:navigationController animated:YES completion:nil];
}

+ (void)showSettingsForTopicTitle:(NSString *)title {
    SCISettingsViewController *settingsViewController = [SCISettingsViewController new];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];

    NSArray *rootSections = [SCITweakSettings sections];
    NSArray *topicRows = rootSections.count > 0 ? rootSections[0][@"rows"] : nil;
    NSArray *targetSections = nil;
    for (SCISetting *row in topicRows) {
        if (![row isKindOfClass:[SCISetting class]]) continue;
        if (![row.title isEqualToString:title]) continue;
        if (row.navSections.count > 0) {
            targetSections = row.navSections;
            break;
        }
    }

    UIViewController *presenter = topMostController();
    [presenter presentViewController:navigationController animated:YES completion:^{
        if (targetSections.count > 0) {
            UIViewController *vc = [[SCISettingsViewController alloc] initWithTitle:title sections:targetSections reduceMargin:NO];
            vc.title = title;
            [navigationController pushViewController:vc animated:NO];
        }
    }];
}

// MARK: Colours
+ (UIColor *)SCIColor_Primary {
    return [UIColor colorWithRed:0/255.0 green:152/255.0 blue:254/255.0 alpha:1];
};

// MARK: Errors
+ (NSError *)errorWithDescription:(NSString *)errorDesc {
    return [self errorWithDescription:errorDesc code:1];
}
+ (NSError *)errorWithDescription:(NSString *)errorDesc code:(NSInteger)errorCode {
    NSError *error = [ NSError errorWithDomain:@"com.socuul.scinsta" code:errorCode userInfo:@{ NSLocalizedDescriptionKey: errorDesc } ];
    return error;
}
+ (BOOL)openURL:(NSURL *)url {
    if (!url) return NO;
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    return YES;
}

+ (BOOL)openURLThroughApplicationDelegate:(NSURL *)url {
    if (!url) return NO;
    UIApplication *application = [UIApplication sharedApplication];
    id<UIApplicationDelegate> delegate = application.delegate;
    if ([delegate respondsToSelector:@selector(application:openURL:options:)]) {
        [delegate application:application openURL:url options:@{}];
        return YES;
    }
    return NO;
}

+ (BOOL)openInstagramProfileForUsername:(NSString *)username {
    NSString *encodedUsername = [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (encodedUsername.length == 0) return NO;

    NSURL *appURL = [NSURL URLWithString:[NSString stringWithFormat:@"instagram://user?username=%@", encodedUsername]];
    if (appURL && [[UIApplication sharedApplication] canOpenURL:appURL]) {
        if ([self openURLThroughApplicationDelegate:appURL]) return YES;
        return [self openURL:appURL];
    }

    NSURL *webURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.instagram.com/%@/", encodedUsername]];
    return [self openInstagramMediaURL:webURL];
}

+ (BOOL)openInstagramMediaURL:(NSURL *)url {
    if (!url) return NO;
    NSString *scheme = url.scheme.lowercaseString ?: @"";
    UIApplication *application = [UIApplication sharedApplication];
    id<UIApplicationDelegate> delegate = application.delegate;

    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
        activity.webpageURL = url;
        SEL continueSelector = @selector(application:continueUserActivity:restorationHandler:);
        if ([delegate respondsToSelector:continueSelector]) {
            BOOL handled = [delegate application:application
                            continueUserActivity:activity
                              restorationHandler:^(__unused NSArray<id<UIUserActivityRestoring>> *restorableObjects) {}];
            if (handled) return YES;
        }
        if ([self openURLThroughApplicationDelegate:url]) return YES;
    } else if ([scheme isEqualToString:@"instagram"]) {
        if ([self openURLThroughApplicationDelegate:url]) return YES;
    }

    return [self openURL:url];
}

+ (NSURL *)sanitizedInstagramShareURL:(NSURL *)url {
    if (!url) return nil;
    if (![url isKindOfClass:[NSURL class]]) return nil;

    if (![url.scheme.lowercaseString isEqualToString:@"http"] && ![url.scheme.lowercaseString isEqualToString:@"https"]) {
        return url;
    }
    if (!SCIInstagramHostMatchesCanonical(url.host)) {
        return url;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if (!components) {
        return url;
    }

    NSArray<NSString *> *rawSegments = [components.path componentsSeparatedByString:@"/"];
    NSMutableArray<NSString *> *segments = [NSMutableArray array];
    for (NSString *segment in rawSegments) {
        if (segment.length > 0) {
            [segments addObject:segment];
        }
    }

    NSArray<NSString *> *sanitizedSegments = SCISanitizedInstagramPathSegments(segments);
    NSString *path = sanitizedSegments.count > 0 ? [@"/" stringByAppendingString:[sanitizedSegments componentsJoinedByString:@"/"]] : @"/";
    if (![path hasSuffix:@"/"]) {
        path = [path stringByAppendingString:@"/"];
    }

    components.scheme = @"https";
    components.host = @"www.instagram.com";
    components.path = path;
    components.queryItems = SCISanitizedInstagramQueryItems(components.queryItems);
    components.fragment = nil;

    return components.URL ?: url;
}

+ (BOOL)openPhotosApp {
    NSURL *url = [NSURL URLWithString:@"photos-redirect://"];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        return [self openURL:url];
    }
    return NO;
}

// MARK: Media
+ (NSURL *)getPhotoUrl:(IGPhoto *)photo {
    if (!photo) return nil;

    NSURL *photoUrl = SCIHighestQualityURLFromVersions(SCIImageVersionsFromPhoto(photo));
    if (photoUrl) return photoUrl;

    if ([photo respondsToSelector:@selector(imageURLForWidth:)]) {
        photoUrl = [photo imageURLForWidth:100000.00];
        if (photoUrl) return photoUrl;
    }

    photoUrl = SCIURLFromStringOrURL(SCIObjectForSelector(photo, @"thumbnailURL"));

    return photoUrl;
}
+ (NSURL *)getPhotoUrlForMedia:(IGMedia *)media {
    if (!media) return nil;

    IGPhoto *photo = media.photo;

    return [SCIUtils getPhotoUrl:photo];
}
+ (NSURL *)getBestProfilePictureURLForUser:(id)user {
    return SCIHDProfilePicURL(user) ?: SCIThumbProfilePicURL(user);
}
+ (NSURL *)getVideoUrl:(IGVideo *)video {
    if (!video) return nil;

    NSURL *videoURL = SCIHighestQualityURLFromVersions(SCIVideoVersionsFromVideo(video));
    if (videoURL) return videoURL;

    // The past (pre v398)
    if ([video respondsToSelector:@selector(sortedVideoURLsBySize)]) {
        id sorted = [video sortedVideoURLsBySize];
        videoURL = SCIURLFromVideoURLCollection(sorted);
        if (videoURL) return videoURL;
    }

    // The present (post v398)
    if ([video respondsToSelector:@selector(allVideoURLs)]) {
        videoURL = SCIURLFromVideoURLCollection([video allVideoURLs]);
        if (videoURL) return videoURL;
    }

    return nil;
}
+ (NSURL *)getVideoUrlForMedia:(IGMedia *)media {
    if (!media) return nil;

    IGVideo *video = media.video;
    if (!video) return nil;

    return [SCIUtils getVideoUrl:video];
}

// MARK: View Controller Helpers
+ (UIViewController *)viewControllerForView:(UIView *)view {
    NSString *viewDelegate = @"viewDelegate";
    if ([view respondsToSelector:NSSelectorFromString(viewDelegate)]) {
        return [view valueForKey:viewDelegate];
    }

    return nil;
}

+ (UIViewController *)viewControllerForAncestralView:(UIView *)view {
    NSString *_viewControllerForAncestor = @"_viewControllerForAncestor";
    if ([view respondsToSelector:NSSelectorFromString(_viewControllerForAncestor)]) {
        return [view valueForKey:_viewControllerForAncestor];
    }

    return nil;
}

+ (UIViewController *)nearestViewControllerForView:(UIView *)view {
    return [self viewControllerForView:view] ?: [self viewControllerForAncestralView:view];
}

// Functions


// MARK: Alerts
+ (BOOL)showConfirmation:(void(^)(void))okHandler title:(NSString *)title {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:@"Are you sure?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        okHandler();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"No!" style:UIAlertActionStyleCancel handler:nil]];

    [topMostController() presentViewController:alert animated:YES completion:nil];

    return nil;
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler title:(NSString *)title {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:@"Are you sure?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        okHandler();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"No!" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (cancelHandler != nil) {
            cancelHandler();
        }
    }]];

    [topMostController() presentViewController:alert animated:YES completion:nil];

    return nil;
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler {
    return [self showConfirmation:okHandler title:nil];
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler {
    return [self showConfirmation:okHandler cancelHandler:cancelHandler title:nil];
}
+ (void)showRestartConfirmation {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Restart required" message:@"You must restart the app to apply this change" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restart" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];

    [topMostController() presentViewController:alert animated:YES completion:nil];
};

// MARK: Toasts
+ (void)showToastForDuration:(double)duration title:(NSString *)title {
    [SCIUtils showToastForDuration:duration
                             title:title
                          subtitle:nil
                      iconResource:@"info"
           fallbackSystemImageName:@"info.circle.fill"
                              tone:SCIFeedbackPillToneInfo];
}
+ (void)showToastForDuration:(double)duration title:(NSString *)title subtitle:(NSString *)subtitle {
    [SCIUtils showToastForDuration:duration
                             title:title
                          subtitle:subtitle
                      iconResource:@"info"
           fallbackSystemImageName:@"info.circle.fill"
                              tone:SCIFeedbackPillToneInfo];
}

+ (void)showToastForDuration:(double)duration
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                iconResource:(NSString *)iconResource
     fallbackSystemImageName:(NSString *)fallbackSystemImageName
                        tone:(SCIFeedbackPillTone)tone {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SCIUtils showToastForDuration:duration
                                     title:title
                                  subtitle:subtitle
                              iconResource:iconResource
                   fallbackSystemImageName:fallbackSystemImageName
                                      tone:tone];
        });
        return;
    }

    UIView *hostView = SCIFeedbackPresentationView();
    if (!hostView) {
        SCILog(@"No feedback host view available for title=%@", title);
        return;
    }
    SCIApplyFeedbackPillStylePreference();

    UIImage *icon = nil;
    if (iconResource.length > 0) {
        icon = [SCIUtils sci_resourceImageNamed:iconResource template:YES maxPointSize:16.0];
    }
    if (!icon && fallbackSystemImageName.length > 0) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
        icon = [UIImage systemImageNamed:fallbackSystemImageName withConfiguration:config];
    }

    NSTimeInterval effectiveDuration = (tone != SCIFeedbackPillToneError) ? kSCISuccessToastDuration : duration;
    [SCIFeedbackPillView showToastInView:hostView
                                duration:effectiveDuration
                                   title:title
                                subtitle:subtitle
                                    icon:icon
                                    tone:tone];
}

+ (SCIFeedbackPillView *)showProgressPill {
    if (![NSThread isMainThread]) {
        __block SCIFeedbackPillView *pill = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{
            pill = [SCIUtils showProgressPill];
        });
        return pill;
    }

    UIView *hostView = SCIFeedbackPresentationView();
    if (!hostView) {
        SCILog(@"No feedback host view available for progress pill");
        return nil;
    }
    SCIApplyFeedbackPillStylePreference();

    return [SCIFeedbackPillView showInView:hostView];
}

// MARK: Math
+ (NSUInteger)decimalPlacesInDouble:(double)value {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:15]; // Allow enough digits for double precision
    [formatter setMinimumFractionDigits:0];
    [formatter setDecimalSeparator:@"."]; // Force dot for internal logic, then respect locale for final display if needed

    NSString *stringValue = [formatter stringFromNumber:@(value)];

    // Find decimal separator
    NSRange decimalRange = [stringValue rangeOfString:formatter.decimalSeparator];

    if (decimalRange.location == NSNotFound) {
        return 0;
    } else {
        return stringValue.length - (decimalRange.location + decimalRange.length);
    }
}

// MARK: Resources (SCInsta.bundle + LiveContainer loose files / nested bundle)

+ (NSBundle *)sci_resourcesBundle {
    static NSBundle *bundle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSMutableArray<NSString *> *candidatePaths = [NSMutableArray array];

        // 1. Sideloaded IPA: cyan injects SCInsta.bundle into the .app root
        NSString *appBundlePath = [[NSBundle mainBundle] pathForResource:@"SCInsta" ofType:@"bundle"];
        if (appBundlePath.length) {
            [candidatePaths addObject:appBundlePath];
        }
        // Also check Frameworks/ (some injectors place bundles there)
        NSString *frameworksBundlePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks/SCInsta.bundle"];
        [candidatePaths addObject:frameworksBundlePath];

        // 2. LiveContainer: Documents/Tweaks/SCInsta/SCInsta.bundle
        NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if (documentsPath.length) {
            [candidatePaths addObject:[documentsPath stringByAppendingPathComponent:@"Tweaks/SCInsta/SCInsta.bundle"]];
        }

        // 3. Jailbroken paths
        [candidatePaths addObjectsFromArray:@[
            @"/var/jb/Library/Application Support/SCInsta.bundle",
            @"/Library/Application Support/SCInsta.bundle",
            @"/var/jb/Library/MobileSubstrate/DynamicLibraries/SCInsta.bundle",
            @"/Library/MobileSubstrate/DynamicLibraries/SCInsta.bundle",
        ]];

        for (NSString *path in candidatePaths) {
            if ([fileManager fileExistsAtPath:path]) {
                bundle = [NSBundle bundleWithPath:path];
                if (bundle) {
                    break;
                }
            }
        }

        if (!bundle) {
            bundle = [NSBundle bundleForClass:[SCIUtils class]];
        }
    });

    return bundle;
}

/// `imageWithContentsOfFile:` does not infer @2x/@3x scale; without this, bitmap pixels are shown 1:1 in points (huge icons).
static UIImage *SCIImageWithContentsOfFileApplyingScale(NSString *path) {
    if (!path.length) {
        return nil;
    }
    UIImage *img = [UIImage imageWithContentsOfFile:path];
    if (!img) {
        return nil;
    }
    CGFloat scale = 1.0;
    if ([path containsString:@"@3x"]) {
        scale = 3.0;
    } else if ([path containsString:@"@2x"]) {
        scale = 2.0;
    }
    if (fabs(img.scale - scale) < 0.01) {
        return img;
    }
    return [UIImage imageWithCGImage:img.CGImage scale:scale orientation:img.imageOrientation];
}

+ (UIImage *)sci_scaleImage:(UIImage *)image maxPointDimension:(CGFloat)maxPt {
    if (!image || maxPt <= 0) {
        return image;
    }
    CGFloat w = image.size.width;
    CGFloat h = image.size.height;
    CGFloat maxdim = MAX(w, h);
    if (maxdim <= maxPt + 0.01) {
        return image;
    }
    CGFloat ratio = maxPt / maxdim;
    CGSize newSize = CGSizeMake(round(w * ratio), round(h * ratio));
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = image.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:newSize format:fmt];
    UIImage *out = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    }];
    UIImageRenderingMode mode = image.renderingMode;
    if (mode != UIImageRenderingModeAutomatic) {
        out = [out imageWithRenderingMode:mode];
    }
    return out;
}

+ (UIImage *)sci_resourceImageNamed:(NSString *)name template:(BOOL)asTemplate {
    return [self sci_resourceImageNamed:name template:asTemplate maxPointSize:0];
}

+ (UIImage *)sci_resourceImageNamed:(NSString *)name template:(BOOL)asTemplate maxPointSize:(CGFloat)maxPointSize {
    if (!name.length) {
        return nil;
    }

    NSBundle *resourceBundle = [self sci_resourcesBundle];
    UIImage *image = [UIImage imageNamed:name inBundle:resourceBundle compatibleWithTraitCollection:nil];

    if (!image) {
        NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if (documentsPath.length) {
            NSString *baseDir = [documentsPath stringByAppendingPathComponent:@"Tweaks/SCInsta"];
            NSArray<NSString *> *fileNames = @[
                [NSString stringWithFormat:@"%@@3x.png", name],
                [NSString stringWithFormat:@"%@@2x.png", name],
                [NSString stringWithFormat:@"%@.png", name],
            ];
            for (NSString *fileName in fileNames) {
                NSString *path = [baseDir stringByAppendingPathComponent:fileName];
                if (!path.length) {
                    continue;
                }
                image = SCIImageWithContentsOfFileApplyingScale(path);
                if (image) {
                    break;
                }
            }
        }
    }

    if (!image) {
        NSArray<NSString *> *candidateNames = @[[NSString stringWithFormat:@"%@@3x", name], [NSString stringWithFormat:@"%@@2x", name], name];
        for (NSString *resName in candidateNames) {
            NSString *path = [resourceBundle pathForResource:resName ofType:@"png"];
            if (!path.length) {
                continue;
            }
            image = SCIImageWithContentsOfFileApplyingScale(path);
            if (image) {
                break;
            }
        }
    }

    if (!image) {
        image = [UIImage imageNamed:name];
    }

    if (!image) {
        return nil;
    }

    if (maxPointSize > 0) {
        image = [self sci_scaleImage:image maxPointDimension:maxPointSize];
    }

    if (asTemplate) {
        return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return image;
}

// Ivars
+ (NSNumber *)numericValueForObj:(id)obj selectorName:(NSString *)selectorName {
    return SCINumericValueForSelector(obj, selectorName);
}

+ (id)getIvarForObj:(id)obj name:(const char *)name {
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) return nil;

    return object_getIvar(obj, ivar);
}
+ (void)setIvarForObj:(id)obj name:(const char *)name value:(id)value {
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) return;
    
    object_setIvarWithStrongDefault(obj, ivar, value);
}


@end
