#import "../../Utils.h"
#import "../../InstagramHeaders.h"

%group SCIHideExploreGridHooks

%hook IGExploreGridViewController
- (void)viewDidLoad {
    if ([SCIUtils getBoolPref:@"hide_explore_grid"]) {
        NSLog(@"[SCInsta] Hiding explore grid");

        [[self view] removeFromSuperview];

        return;
    }
    
    return %orig;
}
%end

%hook IGExploreViewController
- (void)viewDidLoad {
    %orig;

    if ([SCIUtils getBoolPref:@"hide_explore_grid"]) {
        NSLog(@"[SCInsta] Hiding explore grid");

        IGShimmeringGridView *shimmeringGridView = MSHookIvar<IGShimmeringGridView *>(self, "_shimmeringGridView");
        if (shimmeringGridView != nil) {
            [shimmeringGridView removeFromSuperview];
        }
    }
}
%end

%end

extern "C" void SCIInstallHideExploreGridHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"hide_explore_grid"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIHideExploreGridHooks);
    });
}
