#import "../../Utils.h"
#import "../../InstagramHeaders.h"

static UIView *SCIRepostContainerForSelector(id view, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (![view respondsToSelector:selector]) return nil;

    id buttonView = ((id (*)(id, SEL))objc_msgSend)(view, selector);
    if (![buttonView isKindOfClass:[UIView class]]) return nil;

    UIView *containerView = [buttonView superview];
    return (containerView && containerView != view) ? containerView : buttonView;
}

static void SCIHideFeedRepostButtons(id view) {
    if (![SCIUtils getBoolPref:@"hide_repost_button"]) return;

    UIView *repostContainer = SCIRepostContainerForSelector(view, @"repostButton");
    if (repostContainer && !repostContainer.hidden) {
        repostContainer.hidden = YES;
    }

    UIView *undoRepostContainer = SCIRepostContainerForSelector(view, @"undoRepostButton");
    if (undoRepostContainer && !undoRepostContainer.hidden) {
        undoRepostContainer.hidden = YES;
    }
}

%hook IGUFIButtonBarView
- (void)layoutSubviews {
    %orig;

    SCIHideFeedRepostButtons(self);
}
%end

%hook IGUFIInteractionCountsView
- (void)layoutSubviews {
    %orig;

    SCIHideFeedRepostButtons(self);
}
%end

%hook IGSundialViewerUFIViewModel
- (BOOL)shouldShowRepostButton {
    if ([SCIUtils getBoolPref:@"hide_repost_button"]) {
        return NO;
    }

    return %orig;
}
%end
