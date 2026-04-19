#import "../../Utils.h"

static NSInteger const kSCIFeedRefreshReasonHomeButton = 5;

%hook IGMainFeedViewController
- (void)refreshFeedWithFetchReason:(NSInteger)reason animated:(BOOL)animated {
    if ([SCIUtils getBoolPref:@"disable_home_button_refresh"] && reason == kSCIFeedRefreshReasonHomeButton) {
        NSLog(@"[SCInsta] Blocking home-button feed refresh");
        return;
    }

    %orig;
}
%end
