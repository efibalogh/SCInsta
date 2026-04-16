#import "../../Utils.h"

static inline BOOL SCIBlockDisappearingSwipeUpEnabled(void) {
    return [SCIUtils getBoolPref:@"disable_disappearing_swipe_up"];
}

static inline BOOL SCIHideVanishScreenshotEnabled(void) {
    return [SCIUtils getBoolPref:@"hide_vanish_screenshot"];
}

%hook IGDirectBottomSwipeableScrollManager
- (id)initWithKeyboardVisibleSwipeThreshold:(double)arg1
                keyboardHiddenSwipeThreshold:(double)arg2
                            keyboardObserver:(id)arg3
                        enableHapticFeedback:(BOOL)arg4
                                 launcherSet:(id)arg5 {
    if (SCIBlockDisappearingSwipeUpEnabled()) {
        NSLog(@"[SCInsta] Blocking disappearing swipe-up initializer (launcherSet)");
        return nil;
    }

    return %orig;
}

- (id)initWithKeyboardVisibleSwipeThreshold:(double)arg1
                keyboardHiddenSwipeThreshold:(double)arg2
                            keyboardObserver:(id)arg3
                        enableHapticFeedback:(BOOL)arg4 {
    if (SCIBlockDisappearingSwipeUpEnabled()) {
        NSLog(@"[SCInsta] Blocking disappearing swipe-up initializer");
        return nil;
    }

    return %orig;
}
%end

%hook IGDirectThreadViewController
- (void)swipeableScrollManagerDidEndDraggingAboveSwipeThreshold:(id)arg1 {
    if (SCIBlockDisappearingSwipeUpEnabled()) {
        NSLog(@"[SCInsta] Blocking disappearing swipe-up threshold action");
        return;
    }

    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        NSLog(@"[SCInsta] Confirm shh mode triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }];
    } else {
        return %orig;
    }
}

- (id)bottomSwipeHandler {
    if (SCIBlockDisappearingSwipeUpEnabled()) {
        NSLog(@"[SCInsta] Blocking disappearing swipe-up handler");
        return nil;
    }

    return %orig;
}

- (void)shhModeTransitionButtonDidTap:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        NSLog(@"[SCInsta] Confirm shh mode triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }];
    } else {
        return %orig;
    }
}

- (void)messageListViewControllerDidToggleShhMode:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        NSLog(@"[SCInsta] Confirm shh mode triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }];
    } else {
        return %orig;
    }
}

- (void)messageListViewControllerDidTakeScreenshot:(id)arg1 isRecording:(BOOL)arg2 productType:(NSInteger)arg3 {
    if (SCIHideVanishScreenshotEnabled()) {
        NSLog(@"[SCInsta] Suppressing vanish screenshot callback (thread controller)");
        return;
    }

    %orig;
}
%end

%hook IGDirectMessageListViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    if (SCIHideVanishScreenshotEnabled()) {
        NSLog(@"[SCInsta] Suppressing vanish screenshot callback (screenshot taken)");
        return;
    }

    %orig;
}

- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    if (SCIHideVanishScreenshotEnabled()) {
        NSLog(@"[SCInsta] Suppressing vanish screenshot callback (active capture)");
        return;
    }

    %orig;
}
%end