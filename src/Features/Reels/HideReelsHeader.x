#import "../../Utils.h"

%group SCIHideReelsHeaderHooks

%hook IGSundialViewerNavigationBarOld
- (void)didMoveToWindow {
    %orig;

    if ([SCIUtils getBoolPref:@"hide_reels_header"]) {
        NSLog(@"[SCInsta] Hiding reels header");

        [self removeFromSuperview];
    }
}
%end

%end

void SCIInstallHideReelsHeaderHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"hide_reels_header"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIHideReelsHeaderHooks);
    });
}
