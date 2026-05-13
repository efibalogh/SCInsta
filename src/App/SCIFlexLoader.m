#import "SCIFlexLoader.h"

#import <dlfcn.h>
#import <objc/message.h>

#import "../Utils.h"

FOUNDATION_EXPORT void SCIInstallFlexLoadedCompatibilityHooksIfNeeded(void);

static void *sSCIFlexHandle = NULL;
static id (*sSCIFlexGetManager)(void) = NULL;
static SEL (*sSCIFlexRevealSEL)(void) = NULL;
static Class (*sSCIFlexWindowClassGetter)(void) = NULL;
static id sSCIFlexManager = nil;
static SEL sSCIFlexShowSelector = NULL;
static NSString *sSCIFlexLoadedPath = nil;
static NSString *sSCIFlexLoadError = nil;
static NSTimeInterval sSCIFlexLastShowAttempt = 0.0;
static NSString *sSCIFlexLastShowTrigger = nil;

static dispatch_queue_t SCIFlexLoaderQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.scinsta.flex-loader", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static void SCIAppendFlexPath(NSMutableArray<NSString *> *paths, NSString *path) {
    if (path.length == 0) {
        return;
    }

    if (![paths containsObject:path]) {
        [paths addObject:path];
    }
}

static NSString *SCIDylibDirectory(void) {
    Dl_info info;
    if (dladdr((void *)SCIDylibDirectory, &info) && info.dli_fname) {
        return [@(info.dli_fname) stringByDeletingLastPathComponent];
    }
    return nil;
}

static void SCIAppendLiveContainerApplicationFlexPaths(NSMutableArray<NSString *> *paths) {
    NSString *dylibDirectory = SCIDylibDirectory();
    if (dylibDirectory.length == 0) {
        return;
    }

    NSString *documentsPath = nil;
    NSRange tweaksRange = [dylibDirectory rangeOfString:@"/Documents/Tweaks/" options:NSBackwardsSearch];
    if (tweaksRange.location != NSNotFound) {
        documentsPath = [dylibDirectory substringToIndex:tweaksRange.location + @"/Documents".length];
    } else {
        NSRange documentsRange = [dylibDirectory rangeOfString:@"/Documents/" options:NSBackwardsSearch];
        if (documentsRange.location != NSNotFound) {
            documentsPath = [dylibDirectory substringToIndex:documentsRange.location + @"/Documents".length];
        }
    }

    if (documentsPath.length == 0) {
        return;
    }

    NSString *applicationsPath = [documentsPath stringByAppendingPathComponent:@"Applications"];
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:applicationsPath error:nil];
    for (NSString *entry in entries) {
        if (![entry.pathExtension isEqualToString:@"app"]) {
            continue;
        }

        NSString *candidate = [[[applicationsPath stringByAppendingPathComponent:entry]
            stringByAppendingPathComponent:@"Frameworks"]
            stringByAppendingPathComponent:@"libFLEX.dylib"];
        SCIAppendFlexPath(paths, candidate);
    }
}

static NSArray<NSString *> *SCIFlexCandidatePaths(void) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    if (bundlePath.length > 0) {
        SCIAppendFlexPath(paths, [bundlePath stringByAppendingPathComponent:@"Frameworks/libFLEX.dylib"]);
    }

    NSString *executablePath = NSProcessInfo.processInfo.arguments.firstObject;
    NSString *executableDirectory = executablePath.stringByDeletingLastPathComponent;
    if (executableDirectory.length > 0) {
        SCIAppendFlexPath(paths, [executableDirectory stringByAppendingPathComponent:@"Frameworks/libFLEX.dylib"]);
    }

    NSString *dylibDirectory = SCIDylibDirectory();
    if (dylibDirectory.length > 0) {
        SCIAppendFlexPath(paths, [dylibDirectory stringByAppendingPathComponent:@"libFLEX.dylib"]);
        SCIAppendFlexPath(paths, [dylibDirectory stringByAppendingPathComponent:@"libflex.dylib"]);
    }

    SCIAppendLiveContainerApplicationFlexPaths(paths);

    // Jailbreak package locations.
    SCIAppendFlexPath(paths, @"/var/jb/Library/MobileSubstrate/DynamicLibraries/libFLEX.dylib");
    SCIAppendFlexPath(paths, @"/Library/MobileSubstrate/DynamicLibraries/libFLEX.dylib");

    return paths;
}

static NSString *SCIFlexBundledPath(void) {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    for (NSString *path in SCIFlexCandidatePaths()) {
        if ([fileManager fileExistsAtPath:path]) {
            return path;
        }
    }
    return nil;
}

BOOL SCIFlexIsBundled(void) {
    return SCIFlexBundledPath() != nil;
}

BOOL SCIFlexIsLoaded(void) {
    return sSCIFlexManager != nil && sSCIFlexShowSelector != NULL;
}

BOOL SCIFlexLoadIfNeeded(void) {
    if (SCIFlexIsLoaded()) {
        return YES;
    }

    NSString *path = SCIFlexBundledPath();
    if (path.length == 0) {
        sSCIFlexLoadError = @"libFLEX.dylib was not bundled";
        SCILog(@"FLEX unavailable: %@", sSCIFlexLoadError);
        return NO;
    }

    void *handle = dlopen(path.UTF8String, RTLD_NOW | RTLD_GLOBAL);
    if (!handle) {
        const char *error = dlerror();
        sSCIFlexLoadError = error ? @(error) : @"dlopen failed";
        SCILog(@"FLEX dlopen failed at %@: %@", path, sSCIFlexLoadError);
        return NO;
    }

    sSCIFlexHandle = handle;
    sSCIFlexGetManager = (id (*)(void))dlsym(handle, "FLXGetManager");
    sSCIFlexRevealSEL = (SEL (*)(void))dlsym(handle, "FLXRevealSEL");
    sSCIFlexWindowClassGetter = (Class (*)(void))dlsym(handle, "FLXWindowClass");

    if (!sSCIFlexGetManager || !sSCIFlexRevealSEL) {
        sSCIFlexLoadError = @"libFLEX.dylib did not export required symbols";
        SCILog(@"FLEX symbol resolution failed at %@", path);
        return NO;
    }

    sSCIFlexManager = sSCIFlexGetManager();
    sSCIFlexShowSelector = sSCIFlexRevealSEL();
    sSCIFlexLoadedPath = path;
    sSCIFlexLoadError = nil;

    SCIInstallFlexLoadedCompatibilityHooksIfNeeded();

    SCILog(@"FLEX loaded lazily from %@", sSCIFlexLoadedPath);
    return SCIFlexIsLoaded();
}

Class SCIFlexWindowClass(void) {
    if (!SCIFlexIsLoaded() || !sSCIFlexWindowClassGetter) {
        return Nil;
    }
    return sSCIFlexWindowClassGetter();
}

static BOOL SCIFlexShouldSuppressDuplicateShow(NSString *trigger) {
    NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
    BOOL duplicateLaunchFocus = [trigger isEqualToString:@"focus"] &&
        [sSCIFlexLastShowTrigger isEqualToString:@"launch"] &&
        now - sSCIFlexLastShowAttempt < 2.0;

    if (!duplicateLaunchFocus) {
        sSCIFlexLastShowAttempt = now;
        sSCIFlexLastShowTrigger = [trigger copy];
    }

    return duplicateLaunchFocus;
}

static void SCIFlexShowMissingPill(NSString *trigger) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *subtitle = @"Rebuild with --with-flex";
        if (sSCIFlexLoadError.length > 0 && ![sSCIFlexLoadError isEqualToString:@"libFLEX.dylib was not bundled"]) {
            subtitle = sSCIFlexLoadError;
        }

        SCILog(@"FLEX show requested by %@ but unavailable: %@", trigger, subtitle);
        SCINotify(kSCINotificationFlexUnavailable, @"FLEX unavailable", subtitle, @"info_filled", SCINotificationToneInfo);
    });
}

void SCIFlexShowExplorer(NSString *trigger) {
    NSString *showTrigger = trigger ?: @"unknown";
    if (SCIFlexShouldSuppressDuplicateShow(showTrigger)) {
        SCILog(@"Skipping duplicate FLEX show for trigger %@", showTrigger);
        return;
    }

    if (SCIFlexIsLoaded()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sSCIFlexManager && sSCIFlexShowSelector) {
                ((void (*)(id, SEL))objc_msgSend)(sSCIFlexManager, sSCIFlexShowSelector);
            }
        });
        return;
    }

    dispatch_async(SCIFlexLoaderQueue(), ^{
        if (!SCIFlexLoadIfNeeded()) {
            SCIFlexShowMissingPill(showTrigger);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (sSCIFlexManager && sSCIFlexShowSelector) {
                ((void (*)(id, SEL))objc_msgSend)(sSCIFlexManager, sSCIFlexShowSelector);
            }
        });
    });
}
