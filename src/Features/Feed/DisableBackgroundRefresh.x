// Disable feed/reels retap refresh on newer Instagram versions, and disable
// background feed refresh intervals.

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import <objc/runtime.h>
#import <substrate.h>

static BOOL sciDisableBgRefresh(void) {
    return [SCIUtils getBoolPref:@"disable_bg_refresh"];
}

static BOOL sciDisableHomeRefresh(void) {
    // Compatibility with legacy key naming.
    return [SCIUtils getBoolPref:@"disable_home_button_refresh"] || [SCIUtils getBoolPref:@"disable_home_refresh"];
}

static BOOL sciDisableReelsRefresh(void) {
    return [SCIUtils getBoolPref:@"disable_reels_tab_refresh"];
}

// Returns a very large interval when disabled, -1 to keep Instagram's value.
static double sciOverrideInterval(void) {
    if (sciDisableBgRefresh()) return 999999.0;
    return -1.0;
}

// MARK: - Refresh utility class-method overrides
// Newer IG versions recompute these values dynamically.

static double (*orig_wsRefresh)(id, SEL, id, id);
static double new_wsRefresh(id self, SEL _cmd, id launcherSet, id store) {
    double override = sciOverrideInterval();
    return override > 0.0 ? override : orig_wsRefresh(self, _cmd, launcherSet, store);
}

static double (*orig_wsBgRefresh)(id, SEL, id, id);
static double new_wsBgRefresh(id self, SEL _cmd, id launcherSet, id store) {
    double override = sciOverrideInterval();
    return override > 0.0 ? override : orig_wsBgRefresh(self, _cmd, launcherSet, store);
}

static double (*orig_peakWsRefresh)(id, SEL, double, id, id);
static double new_peakWsRefresh(id self, SEL _cmd, double interval, id launcherSet, id store) {
    double override = sciOverrideInterval();
    return override > 0.0 ? override : orig_peakWsRefresh(self, _cmd, interval, launcherSet, store);
}

static double (*orig_peakWsBgRefresh)(id, SEL, id, id);
static double new_peakWsBgRefresh(id self, SEL _cmd, id launcherSet, id store) {
    double override = sciOverrideInterval();
    return override > 0.0 ? override : orig_peakWsBgRefresh(self, _cmd, launcherSet, store);
}

static void SCIInstallRefreshUtilityHooks(void) {
    Class refreshUtilityClass = NSClassFromString(@"IGMainFeedViewModelUtility.IGMainFeedRefreshUtility");
    if (refreshUtilityClass) {
        Class metaClass = object_getClass(refreshUtilityClass);

        SEL sel1 = NSSelectorFromString(@"warmStartRefreshIntervalWithLauncherSet:feedRefreshInstructionsStore:");
        if (class_getInstanceMethod(metaClass, sel1)) {
            MSHookMessageEx(metaClass, sel1, (IMP)new_wsRefresh, (IMP *)&orig_wsRefresh);
        }

        SEL sel2 = NSSelectorFromString(@"warmStartBackgroundRefreshIntervalWithLauncherSet:feedRefreshInstructionsStore:");
        if (class_getInstanceMethod(metaClass, sel2)) {
            MSHookMessageEx(metaClass, sel2, (IMP)new_wsBgRefresh, (IMP *)&orig_wsBgRefresh);
        }

        SEL sel3 = NSSelectorFromString(@"onPeakWarmStartRefreshIntervalWithWarmStartFetchInterval:launcherSet:feedRefreshInstructionsStore:");
        if (class_getInstanceMethod(metaClass, sel3)) {
            MSHookMessageEx(metaClass, sel3, (IMP)new_peakWsRefresh, (IMP *)&orig_peakWsRefresh);
        }

        SEL sel4 = NSSelectorFromString(@"onPeakWarmStartBackgroundRefreshIntervalWithLauncherSet:feedRefreshInstructionsStore:");
        if (class_getInstanceMethod(metaClass, sel4)) {
            MSHookMessageEx(metaClass, sel4, (IMP)new_peakWsBgRefresh, (IMP *)&orig_peakWsBgRefresh);
        }
    }
}

// MARK: - Background refresh network source hooks

%group SCIBackgroundRefreshHooks

%hook IGMainFeedNetworkSource

- (instancetype)initWithDeps:(id)a1
                       posts:(id)a2
                   nextMaxID:(id)a3
     initialPaginationSource:(id)a4
          contentCoordinator:(id)a5
dataSourceSupplementaryItemsProvider:(id)a6
     disableAutomaticRefresh:(BOOL)disable
       disableSerialization:(BOOL)a8
                   sessionId:(id)a9
             analyticsModule:(id)a10
         serializationSuffix:(id)a11
       disableFlashFeedTLI:(BOOL)a12
disableFlashFeedOnColdStart:(BOOL)a13
    disableResponseDeferral:(BOOL)a14
             hidesStoriesTray:(BOOL)a15
             isSecondaryFeed:(BOOL)a16
collectionViewBackgroundColorOverride:(id)a17
       minWarmStartFetchInterval:(double)a18
  peakMinWarmStartFetchInterval:(double)a19
minimumWarmStartBackgroundedInterval:(double)a20
peakMinimumWarmStartBackgroundedInterval:(double)a21
supplementalFeedHoistedMediaID:(id)a22
          headerTitleOverride:(id)a23
             isInFollowingTab:(BOOL)a24
useShimmerLoadingWhenNoStoriesTray:(BOOL)a25 {

    double override = sciOverrideInterval();
    if (sciDisableBgRefresh()) disable = YES;
    if (override > 0.0) {
        a18 = override;
        a19 = override;
        a20 = override;
        a21 = override;
    }

    return %orig(a1, a2, a3, a4, a5, a6, disable, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25);
}

- (double)minWarmStartFetchInterval {
    double override = sciOverrideInterval();
    return override > 0.0 ? override : %orig;
}

- (double)peakMinWarmStartFetchInterval {
    double override = sciOverrideInterval();
    return override > 0.0 ? override : %orig;
}

- (double)minimumWarmStartBackgroundedInterval {
    double override = sciOverrideInterval();
    return override > 0.0 ? override : %orig;
}

- (double)peakMinimumWarmStartBackgroundedInterval {
    double override = sciOverrideInterval();
    return override > 0.0 ? override : %orig;
}

%end

%hook IGMainFeedViewController

- (void)hotStartRefresh {
    if (sciDisableBgRefresh()) return;
    %orig;
}

%end

// MARK: - Tab retap handling (newer IG)

%hook IGTabBarController

- (void)_timelineButtonPressed {
    if (!sciDisableHomeRefresh()) {
        %orig;
        return;
    }

    UIViewController *selected = nil;
    if ([self respondsToSelector:@selector(selectedViewController)]) {
        selected = [self valueForKey:@"selectedViewController"];
    }

    UIViewController *top = [selected isKindOfClass:[UINavigationController class]]
        ? [(UINavigationController *)selected topViewController]
        : selected;
    BOOL onFeedTab = top && [NSStringFromClass([top class]) containsString:@"MainFeed"];
    if (!onFeedTab) {
        %orig;
        return;
    }

    NSMutableArray *queue = [NSMutableArray array];
    if (top.view) [queue addObject:top.view];
    NSInteger scanned = 0;
    while (queue.count > 0 && scanned < 40) {
        UIView *current = queue.firstObject;
        [queue removeObjectAtIndex:0];
        scanned++;

        if ([current isKindOfClass:[UICollectionView class]]) {
            UIScrollView *scrollView = (UIScrollView *)current;
            CGPoint topOffset = CGPointMake(0.0, -scrollView.adjustedContentInset.top);
            [scrollView setContentOffset:topOffset animated:YES];
            return;
        }

        [queue addObjectsFromArray:current.subviews];
    }
}

- (void)_discoverVideoButtonPressed {
    if (!sciDisableReelsRefresh()) {
        %orig;
        return;
    }

    UIViewController *selected = nil;
    if ([self respondsToSelector:@selector(selectedViewController)]) {
        selected = [self valueForKey:@"selectedViewController"];
    }

    UIViewController *top = [selected isKindOfClass:[UINavigationController class]]
        ? [(UINavigationController *)selected topViewController]
        : selected;
    NSString *topClass = top ? NSStringFromClass([top class]) : @"";
    BOOL onReelsTab = [topClass containsString:@"Sundial"] ||
                      [topClass containsString:@"Reels"] ||
                      [topClass containsString:@"DiscoverVideo"];
    if (!onReelsTab) {
        %orig;
        return;
    }
}

%end

%end

void SCIInstallBackgroundRefreshHooksIfEnabled(void) {
    if (!sciDisableBgRefresh() && !sciDisableHomeRefresh() && !sciDisableReelsRefresh()) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    %init(SCIBackgroundRefreshHooks);
    SCIInstallRefreshUtilityHooks();
    });
}
