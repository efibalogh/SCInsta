#import <substrate.h>
#import <objc/runtime.h>
#import "../../InstagramHeaders.h"
#import "../../Utils.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

typedef BOOL (*SCI_BOOL_MSG)(id self, SEL _cmd);

static SCI_BOOL_MSG orig_liquidGlass_class_isEnabled;
static BOOL hook_liquidGlass_class_isEnabled(id self, SEL _cmd) {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return YES;
    }
    return orig_liquidGlass_class_isEnabled ? orig_liquidGlass_class_isEnabled(self, _cmd) : NO;
}

static SCI_BOOL_MSG orig_nav_isEnabled;
static BOOL hook_nav_isEnabled(id self, SEL _cmd) {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return YES;
    }
    return orig_nav_isEnabled ? orig_nav_isEnabled(self, _cmd) : NO;
}

static SCI_BOOL_MSG orig_nav_isDefaultValueSet;
static BOOL hook_nav_isDefaultValueSet(id self, SEL _cmd) {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return YES;
    }
    return orig_nav_isDefaultValueSet ? orig_nav_isDefaultValueSet(self, _cmd) : NO;
}

static SCI_BOOL_MSG orig_nav_isHomeFeedHeaderEnabled;
static BOOL hook_nav_isHomeFeedHeaderEnabled(id self, SEL _cmd) {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return YES;
    }
    return orig_nav_isHomeFeedHeaderEnabled ? orig_nav_isHomeFeedHeaderEnabled(self, _cmd) : NO;
}

static SCI_BOOL_MSG orig_swizzle_isEnabled;
static BOOL hook_swizzle_isEnabled(id self, SEL _cmd) {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return YES;
    }
    return orig_swizzle_isEnabled ? orig_swizzle_isEnabled(self, _cmd) : NO;
}

static SCI_BOOL_MSG orig_badged_isLiquidGlass;
static BOOL hook_badged_isLiquidGlass(id self, SEL _cmd) {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return YES;
    }
    return orig_badged_isLiquidGlass ? orig_badged_isLiquidGlass(self, _cmd) : NO;
}

static SCI_BOOL_MSG orig_videoBack_isLiquidGlass;
static BOOL hook_videoBack_isLiquidGlass(id self, SEL _cmd) {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return YES;
    }
    return orig_videoBack_isLiquidGlass ? orig_videoBack_isLiquidGlass(self, _cmd) : NO;
}

static SCI_BOOL_MSG orig_videoCam_isLiquidGlass;
static BOOL hook_videoCam_isLiquidGlass(id self, SEL _cmd) {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return YES;
    }
    return orig_videoCam_isLiquidGlass ? orig_videoCam_isLiquidGlass(self, _cmd) : NO;
}

static SCI_BOOL_MSG orig_alert_enableLiquidGlass;
static BOOL hook_alert_enableLiquidGlass(id self, SEL _cmd) {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return YES;
    }
    return orig_alert_enableLiquidGlass ? orig_alert_enableLiquidGlass(self, _cmd) : NO;
}

%hook IGTabBar
- (instancetype)initWithFrame:(CGRect)frame
                defaultConfig:(id)defaultConfig
            immersiveConfig:(id)immersiveConfig
               backgroundView:(id)backgroundView
                  launcherSet:(id)launcherSet {
    if (![SCIUtils sci_anyLiquidGlassEnabled]) {
        return %orig;
    }

    Class lgClass = objc_getClass("IGLiquidGlassInteractiveTabBar");
    if (!lgClass) {
        return %orig;
    }

    id replacement = [[lgClass alloc] initWithFrame:frame];
    if (!replacement) {
        return %orig;
    }

    if (defaultConfig && [replacement respondsToSelector:@selector(setConfig:)]) {
        [replacement performSelector:@selector(setConfig:) withObject:defaultConfig];
    }
    if (immersiveConfig && [replacement respondsToSelector:@selector(setImmersiveConfig:)]) {
        [replacement performSelector:@selector(setImmersiveConfig:) withObject:immersiveConfig];
    }

    return replacement;
}
%end

%hook IGTabBarController
- (NSInteger)tabBarStyle {
    if ([SCIUtils sci_anyLiquidGlassEnabled]) {
        return 1;
    }
    return %orig;
}
%end

%ctor {
    Class c = objc_getClass("IGLiquidGlass.IGLiquidGlass");
    if (c) {
        Method m = class_getClassMethod(c, @selector(isEnabled));
        if (m) {
            MSHookMessageEx(object_getClass((id)c), @selector(isEnabled), (IMP)hook_liquidGlass_class_isEnabled, (IMP *)&orig_liquidGlass_class_isEnabled);
        }
    }

    c = objc_getClass("IGLiquidGlassExperimentHelper.IGLiquidGlassNavigationExperimentHelper");
    if (c) {
        Method m = class_getInstanceMethod(c, @selector(isEnabled));
        if (m) {
            MSHookMessageEx(c, @selector(isEnabled), (IMP)hook_nav_isEnabled, (IMP *)&orig_nav_isEnabled);
        }
        m = class_getInstanceMethod(c, @selector(isDefaultValueSet));
        if (m) {
            MSHookMessageEx(c, @selector(isDefaultValueSet), (IMP)hook_nav_isDefaultValueSet, (IMP *)&orig_nav_isDefaultValueSet);
        }
        m = class_getInstanceMethod(c, @selector(isHomeFeedHeaderEnabled));
        if (m) {
            MSHookMessageEx(c, @selector(isHomeFeedHeaderEnabled), (IMP)hook_nav_isHomeFeedHeaderEnabled, (IMP *)&orig_nav_isHomeFeedHeaderEnabled);
        }
    }

    c = objc_getClass("IGLiquidGlassSwizzle.IGLiquidGlassSwizzleToggle");
    if (c) {
        Method m = class_getInstanceMethod(c, @selector(isEnabled));
        if (m) {
            MSHookMessageEx(c, @selector(isEnabled), (IMP)hook_swizzle_isEnabled, (IMP *)&orig_swizzle_isEnabled);
        } else {
            m = class_getClassMethod(c, @selector(isEnabled));
            if (m) {
                MSHookMessageEx(object_getClass((id)c), @selector(isEnabled), (IMP)hook_swizzle_isEnabled, (IMP *)&orig_swizzle_isEnabled);
            }
        }
    }

    c = objc_getClass("IGBadgedNavigationButton");
    if (c) {
        Method m = class_getInstanceMethod(c, @selector(_isLiquidGlassEnabled));
        if (m) {
            MSHookMessageEx(c, @selector(_isLiquidGlassEnabled), (IMP)hook_badged_isLiquidGlass, (IMP *)&orig_badged_isLiquidGlass);
        }
    }

    c = objc_getClass("IGUnifiedVideoBackButton");
    if (c) {
        Method m = class_getInstanceMethod(c, @selector(_isLiquidGlassEnabled));
        if (m) {
            MSHookMessageEx(c, @selector(_isLiquidGlassEnabled), (IMP)hook_videoBack_isLiquidGlass, (IMP *)&orig_videoBack_isLiquidGlass);
        }
    }

    c = objc_getClass("IGUnifiedVideoCameraEntryPointButton");
    if (c) {
        Method m = class_getInstanceMethod(c, @selector(_isLiquidGlassEnabled));
        if (m) {
            MSHookMessageEx(c, @selector(_isLiquidGlassEnabled), (IMP)hook_videoCam_isLiquidGlass, (IMP *)&orig_videoCam_isLiquidGlass);
        }
    }

    c = objc_getClass("IGDSAlertDialogActionButton");
    if (c) {
        Method m = class_getInstanceMethod(c, @selector(enableLiquidGlass));
        if (m) {
            MSHookMessageEx(c, @selector(enableLiquidGlass), (IMP)hook_alert_enableLiquidGlass, (IMP *)&orig_alert_enableLiquidGlass);
        }
    }
}

#pragma clang diagnostic pop
