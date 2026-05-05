#import "../../Utils.h"
#import "../../InstagramHeaders.h"

%group SCIDisableScrollingReelsHooks

%hook IGUnifiedVideoCollectionView
- (void)didMoveToWindow {
    %orig;

    if ([SCIUtils getBoolPref:@"disable_scrolling_reels"]) {
        NSLog(@"[SCInsta] Disabling scrolling reels");
        
        self.scrollEnabled = false;
    }
}

- (void)setScrollEnabled:(BOOL)arg1 {
    if ([SCIUtils getBoolPref:@"disable_scrolling_reels"]) {
        NSLog(@"[SCInsta] Disabling scrolling reels");
        
        return %orig(NO);
    }

    return %orig;
}
%end

// Disable auto-scrolling reels
%hook _TtC19IGSundialAutoScroll19IGSundialAutoScroll
- (void)setIsEnabled:(BOOL)enabled {
    if ([SCIUtils getBoolPref:@"disable_scrolling_reels"]) {
        %orig(NO);
    }
    else {
        %orig(enabled);
    }
}
%end

%end

void SCIInstallDisableScrollingReelsHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"disable_scrolling_reels"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIDisableScrollingReelsHooks);
    });
}
