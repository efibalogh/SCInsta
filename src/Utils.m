#import "Utils.h"

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

+ (_Bool)liquidGlassEnabledBool:(_Bool)fallback {
    BOOL setting = [SCIUtils getBoolPref:@"liquid_glass_surfaces"];
    return setting ? true : fallback;
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

    // Log errors
    if (deletionErrors.count > 1) {

        for (NSError *error in deletionErrors) {
            NSLog(@"[SCInsta] File Deletion Error: %@", error);
        }

    }

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

+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc {
    return [self showErrorHUDWithDescription:errorDesc dismissAfterDelay:4.0];
}
+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc dismissAfterDelay:(CGFloat)dismissDelay {
    JGProgressHUD *hud = [[JGProgressHUD alloc] init];
    hud.textLabel.text = errorDesc;
    hud.indicatorView = [[JGProgressHUDErrorIndicatorView alloc] init];

    [hud showInView:topMostController().view];
    [hud dismissAfterDelay:4.0];

    return hud;
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
    [SCIUtils showToastForDuration:duration title:title subtitle:nil];
}
+ (void)showToastForDuration:(double)duration title:(NSString *)title subtitle:(NSString *)subtitle {
    // Root VC
    Class rootVCClass = NSClassFromString(@"IGRootViewController");

    UIViewController *topMostVC = topMostController();
    if (![topMostVC isKindOfClass:rootVCClass]) return;

    IGRootViewController *rootVC = (IGRootViewController *)topMostVC;

    // Presenter
    IGActionableConfirmationToastPresenter *toastPresenter = [rootVC toastPresenter];
    if (toastPresenter == nil) return;

    // View Model
    Class modelClass = NSClassFromString(@"IGActionableConfirmationToastViewModel");
    IGActionableConfirmationToastViewModel *model = [modelClass new];
    
    [model setValue:title forKey:@"text_annotatedTitleText"];
    [model setValue:subtitle forKey:@"text_annotatedSubtitleText"];

    // Show new toast, after clearing existing one
    [toastPresenter hideAlert];
    [toastPresenter showAlertWithViewModel:model isAnimated:true animationDuration:duration presentationPriority:0 tapActionBlock:nil presentedHandler:nil dismissedHandler:nil];
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
        NSMutableArray<NSString *> *candidatePaths = [NSMutableArray arrayWithArray:@[
            @"/var/jb/Library/Application Support/SCInsta.bundle",
            @"/Library/Application Support/SCInsta.bundle",
            @"/var/jb/Library/MobileSubstrate/DynamicLibraries/SCInsta.bundle",
            @"/Library/MobileSubstrate/DynamicLibraries/SCInsta.bundle",
        ]];

        NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if (documentsPath.length) {
            NSString *liveBundle = [documentsPath stringByAppendingPathComponent:@"Tweaks/SCInsta/SCInsta.bundle"];
            [candidatePaths addObject:liveBundle];
        }

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
