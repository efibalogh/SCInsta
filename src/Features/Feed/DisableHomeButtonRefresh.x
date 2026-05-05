#import "../../Utils.h"

static NSInteger const kSCIFeedRefreshReasonHomeButton = 5;

static BOOL sciShouldBlockFeedRefresh(void) {
    return [SCIUtils getBoolPref:@"disable_home_button_refresh"];
}

static BOOL sciScrollViewToTopWithoutRefresh(UIScrollView *scrollView) {
    if (![scrollView isKindOfClass:[UIScrollView class]]) {
        return NO;
    }

    CGPoint topOffset = CGPointMake(scrollView.contentOffset.x, -scrollView.adjustedContentInset.top);
    if (CGPointEqualToPoint(scrollView.contentOffset, topOffset)) {
        return NO;
    }

    [scrollView setContentOffset:topOffset animated:YES];
    return NO;
}

%group SCIDisableHomeButtonRefreshHooks

%hook IGMainFeedViewController
- (void)refreshFeedWithFetchReason:(NSInteger)reason animated:(BOOL)animated {
    if (sciShouldBlockFeedRefresh() && reason == kSCIFeedRefreshReasonHomeButton) {
        NSLog(@"[SCInsta] Blocking home-button feed refresh");
        return;
    }

    %orig;
}
%end

%hook IGMainFeedScrollViewDelegateDistributor
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    if (sciShouldBlockFeedRefresh()) {
        return sciScrollViewToTopWithoutRefresh(scrollView);
    }

    return %orig;
}
%end

// Swift class from IGHomeSundialFeedScrollOrchestrator.
%hook _TtC35IGHomeSundialFeedScrollOrchestrator35IGHomeSundialFeedScrollOrchestrator
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    if (sciShouldBlockFeedRefresh()) {
        return sciScrollViewToTopWithoutRefresh(scrollView);
    }

    return %orig;
}
%end

%end

void SCIInstallDisableHomeButtonRefreshHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"disable_home_button_refresh"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIDisableHomeButtonRefreshHooks);
    });
}
