#import "../../Utils.h"
#import "../../InstagramHeaders.h"

%group SCIHideTrendingSearchesHooks

%hook IGDSSegmentedPillBarView
- (void)didMoveToWindow {
    %orig;

    if ([[self delegate] isKindOfClass:%c(IGSearchTypeaheadNavigationHeaderView)]) {
        if ([SCIUtils getBoolPref:@"hide_trending_searches"]) {
            NSLog(@"[SCInsta] Hiding trending searches");

            [self removeFromSuperview];
        }
    }
}
%end

%end

void SCIInstallHideTrendingSearchesHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"hide_trending_searches"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIHideTrendingSearchesHooks);
    });
}
