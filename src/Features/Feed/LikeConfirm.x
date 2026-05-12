#import "../../Utils.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

extern void SCIMarkStoryAsSeenForViewWithAdvancePref(UIView *view, NSString *advancePrefKey);
extern UIView *SCIActiveStoryOverlayForInteractions(void);

static inline BOOL SCIStoryLegacyInteractionPrefEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"story_mark_seen_on_interaction"] != nil &&
        [SCIUtils getBoolPref:@"story_mark_seen_on_interaction"];
}

static inline BOOL SCIStoryMarkSeenOnLikeEnabled(void) {
    return [SCIUtils getBoolPref:@"story_mark_seen_on_like"] || SCIStoryLegacyInteractionPrefEnabled();
}

static inline BOOL SCIStoryMarkSeenOnReplyEnabled(void) {
    return [SCIUtils getBoolPref:@"story_mark_seen_on_reply"] || SCIStoryLegacyInteractionPrefEnabled();
}

static inline BOOL SCIStoryInteractionHooksNeeded(void) {
    return [SCIUtils getBoolPref:@"like_confirm_stories"] ||
        SCIStoryMarkSeenOnLikeEnabled() ||
        SCIStoryMarkSeenOnReplyEnabled() ||
        [SCIUtils getBoolPref:@"advance_story_when_like_marked_seen"] ||
        [SCIUtils getBoolPref:@"advance_story_when_reply_marked_seen"];
}

static void SCIStoryMarkSeenForInteractionView(UIView *view, NSString *advancePrefKey) {
    if (!view) return;
    SCIMarkStoryAsSeenForViewWithAdvancePref(view, advancePrefKey);
}

static void SCIStoryReplySideEffects(void) {
    if (!SCIStoryMarkSeenOnReplyEnabled()) return;
    UIView *overlay = SCIActiveStoryOverlayForInteractions();
    if (!overlay) return;
    SCIStoryMarkSeenForInteractionView(overlay, @"advance_story_when_reply_marked_seen");
}

///////////////////////////////////////////////////////////

// Confirmation handlers

#define CONFIRMFEEDLIKE(orig)                             \
    if ([SCIUtils getBoolPref:@"like_confirm_feed"]) {      \
        NSLog(@"[SCInsta] Confirm feed like triggered");  \
                                                          \
        [SCIUtils showConfirmation:^(void) { orig; }      \
                                 title:@"Confirm Post Like"     \
                               message:@"Are you sure you want to like this post or comment?"]; \
    }                                                     \
    else {                                                \
        return orig;                                      \
    }                                                     \

#define CONFIRMREELSLIKE(orig)                            \
    if ([SCIUtils getBoolPref:@"like_confirm_reels"]) {     \
        NSLog(@"[SCInsta] Confirm reels like triggered"); \
                                                          \
        [SCIUtils showConfirmation:^(void) { orig; }      \
                                 title:@"Confirm Reel Like"     \
                               message:@"Are you sure you want to like this reel?"]; \
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
        if (SCIStoryMarkSeenOnLikeEnabled() && [button isKindOfClass:[UIView class]]) {
            SCIStoryMarkSeenForInteractionView((UIView *)button, @"advance_story_when_like_marked_seen");
        }
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
        if (SCIStoryMarkSeenOnLikeEnabled() && [button isKindOfClass:[UIView class]]) {
            SCIStoryMarkSeenForInteractionView((UIView *)button, @"advance_story_when_like_marked_seen");
        }
    } title:@"Confirm Story Like"
      message:@"Are you sure you want to like this story?"];

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
    if (!SCIStoryInteractionHooksNeeded()) {
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

%hook IGDirectComposer
- (void)_didTapSend {
    %orig;
    SCIStoryReplySideEffects();
}

- (void)_didTapSend:(id)arg {
    %orig;
    SCIStoryReplySideEffects();
}

- (void)_send {
    %orig;
    SCIStoryReplySideEffects();
}
%end

static void (*orig_storyFooterEmojiQuick)(id, SEL, id, id);
static void SCIHookedStoryFooterEmojiQuick(id self, SEL _cmd, id inputView, id button) {
    if (orig_storyFooterEmojiQuick) orig_storyFooterEmojiQuick(self, _cmd, inputView, button);
    SCIStoryReplySideEffects();
}

static void (*orig_storyFooterEmojiReaction)(id, SEL, id, id);
static void SCIHookedStoryFooterEmojiReaction(id self, SEL _cmd, id inputView, id button) {
    if (orig_storyFooterEmojiReaction) orig_storyFooterEmojiReaction(self, _cmd, inputView, button);
    SCIStoryReplySideEffects();
}

static void (*orig_storyQuickReaction)(id, SEL, id, id, id);
static void SCIHookedStoryQuickReaction(id self, SEL _cmd, id view, id sourceButton, id emoji) {
    if (orig_storyQuickReaction) orig_storyQuickReaction(self, _cmd, view, sourceButton, emoji);
    SCIStoryReplySideEffects();
}

static void (*orig_storyPrivateEmojiQuick)(id, SEL, id);
static void SCIHookedStoryPrivateEmojiQuick(id self, SEL _cmd, id button) {
    if (orig_storyPrivateEmojiQuick) orig_storyPrivateEmojiQuick(self, _cmd, button);
    SCIStoryReplySideEffects();
}

static void (*orig_directReshareQuickReaction)(id, SEL, id);
static void SCIHookedDirectReshareQuickReaction(id self, SEL _cmd, id arg) {
    if (orig_directReshareQuickReaction) orig_directReshareQuickReaction(self, _cmd, arg);
    SCIStoryReplySideEffects();
}

static Class SCIStoryReplyFooterClass(void) {
    for (NSString *className in @[
        @"IGStoryDefaultFooter.IGStoryFullscreenDefaultFooterView",
        @"IGStoryFullscreenDefaultFooterView"
    ]) {
        Class cls = NSClassFromString(className);
        if (cls) return cls;
    }
    return Nil;
}

static void SCIInstallStoryReplyHooksIfNeeded(void) {
    if (!SCIStoryInteractionHooksNeeded()) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class footerClass = SCIStoryReplyFooterClass();
        SEL quickSelector = NSSelectorFromString(@"inputView:didTapEmojiQuickReactionButton:");
        if (footerClass && class_getInstanceMethod(footerClass, quickSelector)) {
            MSHookMessageEx(footerClass, quickSelector, (IMP)SCIHookedStoryFooterEmojiQuick, (IMP *)&orig_storyFooterEmojiQuick);
        }

        SEL reactionSelector = NSSelectorFromString(@"inputView:didTapEmojiReactionButton:");
        if (footerClass && class_getInstanceMethod(footerClass, reactionSelector)) {
            MSHookMessageEx(footerClass, reactionSelector, (IMP)SCIHookedStoryFooterEmojiReaction, (IMP *)&orig_storyFooterEmojiReaction);
        }

        Class quickReactionClass = NSClassFromString(@"IGStoryQuickReactions.IGStoryQuickReactionsController");
        SEL quickReactionSelector = NSSelectorFromString(@"quickReactionsView:sourceEmojiButton:didTapEmoji:");
        if (quickReactionClass && class_getInstanceMethod(quickReactionClass, quickReactionSelector)) {
            MSHookMessageEx(quickReactionClass, quickReactionSelector, (IMP)SCIHookedStoryQuickReaction, (IMP *)&orig_storyQuickReaction);
        }

        SEL privateQuickSelector = NSSelectorFromString(@"_didTapEmojiQuickReactionButton:");
        if (footerClass && class_getInstanceMethod(footerClass, privateQuickSelector)) {
            MSHookMessageEx(footerClass, privateQuickSelector, (IMP)SCIHookedStoryPrivateEmojiQuick, (IMP *)&orig_storyPrivateEmojiQuick);
        }

        Class quickReactionDelegateClass = NSClassFromString(@"_TtC29IGStoryQuickReactionsDelegate33IGStoryQuickReactionsDelegateImpl");
        if (!quickReactionDelegateClass) quickReactionDelegateClass = NSClassFromString(@"IGStoryQuickReactionsDelegateImpl");
        SEL directReshareSelector = NSSelectorFromString(@"directReshareMediaReplyFooterViewDidTapQuickReactionEmoji:");
        if (quickReactionDelegateClass && class_getInstanceMethod(quickReactionDelegateClass, directReshareSelector)) {
            MSHookMessageEx(quickReactionDelegateClass, directReshareSelector, (IMP)SCIHookedDirectReshareQuickReaction, (IMP *)&orig_directReshareQuickReaction);
        }
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
        !SCIStoryInteractionHooksNeeded()) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCILikeConfirmHooks);
    });

    SCIInstallStoryLikeConfirmHookIfNeeded();
    SCIInstallStoryReplyHooksIfNeeded();
}
