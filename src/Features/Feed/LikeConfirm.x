#import "../../Utils.h"
#import <objc/message.h>
#import <objc/runtime.h>

///////////////////////////////////////////////////////////

// Confirmation handlers

#define CONFIRMFEEDLIKE(orig)                             \
    if ([SCIUtils getBoolPref:@"like_confirm_feed"]) {      \
        NSLog(@"[SCInsta] Confirm feed like triggered");  \
                                                          \
        [SCIUtils showConfirmation:^(void) { orig; }];    \
    }                                                     \
    else {                                                \
        return orig;                                      \
    }                                                     \

#define CONFIRMREELSLIKE(orig)                            \
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {     \
        NSLog(@"[SCInsta] Confirm reels like triggered"); \
                                                          \
        [SCIUtils showConfirmation:^(void) { orig; }];    \
    }                                                     \
    else {                                                \
        return orig;                                      \
    }                                                     \

///////////////////////////////////////////////////////////

// Liking posts
%group SCILikeConfirmHooks

%hook IGUFIButtonBarView
- (void)_onLikeButtonPressed:(id)arg1 {
    CONFIRMFEEDLIKE(%orig);
}
%end
%hook IGFeedPhotoView
- (void)_onDoubleTap:(id)arg1 {
    CONFIRMFEEDLIKE(%orig);
}
%end
%hook IGVideoPlayerOverlayContainerView
- (void)_handleDoubleTapGesture:(id)arg1 {
    CONFIRMFEEDLIKE(%orig);
}
%end

// Liking reels
%hook IGSundialViewerVideoCell
- (void)controlsOverlayControllerDidTapLikeButton:(id)arg1 {
    CONFIRMREELSLIKE(%orig);
}
- (void)controlsOverlayControllerDidLongPressLikeButton:(id)arg1 gestureRecognizer:(id)arg2 {
    CONFIRMREELSLIKE(%orig);
}
- (void)gestureController:(id)arg1 didObserveDoubleTap:(id)arg2 {
    CONFIRMREELSLIKE(%orig);
}
%end
%hook IGSundialViewerPhotoCell
- (void)controlsOverlayControllerDidTapLikeButton:(id)arg1 {
    CONFIRMREELSLIKE(%orig);
}
- (void)gestureController:(id)arg1 didObserveDoubleTap:(id)arg2 {
    CONFIRMREELSLIKE(%orig);
}
%end
%hook IGSundialViewerCarouselCell
- (void)controlsOverlayControllerDidTapLikeButton:(id)arg1 {
    CONFIRMREELSLIKE(%orig);
}
- (void)gestureController:(id)arg1 didObserveDoubleTap:(id)arg2 {
    CONFIRMREELSLIKE(%orig);
}
%end

// Liking comments
%hook IGCommentCellController
- (void)commentCell:(id)arg1 didTapLikeButton:(id)arg2 {
    CONFIRMFEEDLIKE(%orig);
}
- (void)commentCell:(id)arg1 didTapLikedByButtonForUser:(id)arg2 {
    CONFIRMFEEDLIKE(%orig);
}
- (void)commentCellDidLongPressOnLikeButton:(id)arg1 {
    CONFIRMFEEDLIKE(%orig);
}
- (void)commentCellDidEndLongPressOnLikeButton:(id)arg1 {
    CONFIRMFEEDLIKE(%orig);
}
- (void)commentCellDidDoubleTap:(id)arg1 {
    CONFIRMFEEDLIKE(%orig);
}
%end
%hook IGFeedItemPreviewCommentCell
- (void)_didTapLikeButton {
    CONFIRMFEEDLIKE(%orig);
}
%end

// Liking stories (newer Instagram builds)
static void (*orig_sciStoryLikeTap)(id, SEL, id);
static void new_sciStoryLikeTap(id self, SEL _cmd, id button) {
    if (![SCIUtils getBoolPref:@"like_confirm_stories"]) {
        orig_sciStoryLikeTap(self, _cmd, button);
        return;
    }

    BOOL isSelected = [button isKindOfClass:[UIButton class]] ? [(UIButton *)button isSelected] : NO;
    if (!isSelected) {
        orig_sciStoryLikeTap(self, _cmd, button);
        return;
    }

    UIButton *btn = [button isKindOfClass:[UIButton class]] ? (UIButton *)button : nil;
    SEL setLikedSel = NSSelectorFromString(@"setIsLiked:animated:");

    [SCIUtils showConfirmation:^{
        if (btn) {
            [btn setSelected:YES];
            if ([btn respondsToSelector:setLikedSel]) {
                ((void (*)(id, SEL, BOOL, BOOL))objc_msgSend)(btn, setLikedSel, YES, YES);
            }
        }
        orig_sciStoryLikeTap(self, _cmd, button);
    }];

    if (btn) {
        [UIView performWithoutAnimation:^{
            [btn setSelected:NO];
            if ([btn respondsToSelector:setLikedSel]) {
                ((void (*)(id, SEL, BOOL, BOOL))objc_msgSend)(btn, setLikedSel, NO, NO);
            }
        }];
    }
}

static void SCIInstallStoryLikeConfirmHookIfNeeded(void) {
    if (![SCIUtils getBoolPref:@"like_confirm_stories"]) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"_TtC22IGStoryLikesController38IGStoryLikesInteractionControllingImpl");
        if (!cls) cls = NSClassFromString(@"IGStoryLikesInteractionControllingImpl");
        if (!cls) return;

        SEL sel = NSSelectorFromString(@"handleStoryLikeTapWith:");
        if (!class_getInstanceMethod(cls, sel)) {
            sel = NSSelectorFromString(@"handleStoryLikeTapWithButton:");
        }
        if (!class_getInstanceMethod(cls, sel)) return;

        MSHookMessageEx(cls, sel, (IMP)new_sciStoryLikeTap, (IMP *)&orig_sciStoryLikeTap);
    });
}

// DM like button (seems to be hidden)
%hook IGDirectThreadViewController
- (void)_didTapLikeButton {
    CONFIRMFEEDLIKE(%orig);
}
%end

%end

void SCIInstallLikeConfirmHooksIfNeeded(void) {
    if (![SCIUtils getBoolPref:@"like_confirm_feed"] &&
        ![SCIUtils getBoolPref:@"like_confirm_reels"] &&
        ![SCIUtils getBoolPref:@"like_confirm_stories"]) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCILikeConfirmHooks);
    });

    SCIInstallStoryLikeConfirmHookIfNeeded();
}
