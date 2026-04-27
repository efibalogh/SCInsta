#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "../../InstagramHeaders.h"
#import "../../AssetUtils.h"
#import "../../Tweak.h"
#import "../../Utils.h"

static NSString * const kSCISeenMessagesBarIconResource = @"eye";
static NSString * const kSCIStoryMentionsBarIconResource = @"mention";
static NSInteger const kSCIStorySeenButtonTag = 926001;
static NSInteger const kSCIStoryMentionsButtonTag = 926002;
static NSInteger const kSCIStoriesActionButtonTag = 921343;
static NSInteger const kSCIDirectActionButtonTag = 921344;
static NSInteger const kSCIDirectSeenButtonTag = 921345;
static const void *kSCIStoryOverlayObservedFooterAssocKey = &kSCIStoryOverlayObservedFooterAssocKey;
static const void *kSCIStoryOverlayHasObserverAssocKey = &kSCIStoryOverlayHasObserverAssocKey;
static const void *kSCIDirectSeenBottomConstraintAssocKey = &kSCIDirectSeenBottomConstraintAssocKey;
static const void *kSCIDirectSeenTrailingOverlayConstraintAssocKey = &kSCIDirectSeenTrailingOverlayConstraintAssocKey;
static const void *kSCIDirectSeenTrailingActionConstraintAssocKey = &kSCIDirectSeenTrailingActionConstraintAssocKey;
static const void *kSCIDirectSeenCenterYActionConstraintAssocKey = &kSCIDirectSeenCenterYActionConstraintAssocKey;
static const void *kSCIDirectSeenWidthConstraintAssocKey = &kSCIDirectSeenWidthConstraintAssocKey;
static const void *kSCIDirectSeenHeightConstraintAssocKey = &kSCIDirectSeenHeightConstraintAssocKey;
static const void *kSCIDirectSeenAnchoredActionButtonAssocKey = &kSCIDirectSeenAnchoredActionButtonAssocKey;
static const void *kSCIDirectVisualObservedInputViewAssocKey = &kSCIDirectVisualObservedInputViewAssocKey;
static const void *kSCIDirectVisualHasInputObserverAssocKey = &kSCIDirectVisualHasInputObserverAssocKey;
static void *kSCIStoryOverlayAlphaObserverContext = &kSCIStoryOverlayAlphaObserverContext;
static void *kSCIDirectVisualInputAlphaObserverContext = &kSCIDirectVisualInputAlphaObserverContext;
static NSInteger kSCISeenAutoBypassCount = 0;
static void (*orig_setHasSentAMessageOrUpdate)(id, SEL, BOOL) = NULL;
static void (*orig_setHasSentAMessage)(id, SEL, BOOL) = NULL;

static inline BOOL SCIManualMessageSeenEnabled(void) {
    return [SCIUtils getBoolPref:@"remove_lastseen"];
}

static inline BOOL SCIManualStorySeenEnabled(void) {
    return [SCIUtils getBoolPref:@"no_seen_receipt"];
}

static inline BOOL SCIStoryMentionsButtonEnabled(void) {
    return [SCIUtils getBoolPref:@"story_mentions_button"];
}

static inline BOOL SCIAutoSeenOnSendEnabled(void) {
    return SCIManualMessageSeenEnabled() && [SCIUtils getBoolPref:@"seen_auto_on_send"];
}

static void SCITriggerAutoSeenForThreadController(id controller) {
    if (!SCIAutoSeenOnSendEnabled() || !controller) return;
    if (![controller respondsToSelector:@selector(markLastMessageAsSeen)]) return;

    kSCISeenAutoBypassCount++;
    ((void (*)(id, SEL))objc_msgSend)(controller, @selector(markLastMessageAsSeen));

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (kSCISeenAutoBypassCount > 0) {
            kSCISeenAutoBypassCount--;
        }
    });
}

static void SCIHandleDidSendMessageState(id controller, BOOL sent) {
    if (!sent || !SCIAutoSeenOnSendEnabled()) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SCITriggerAutoSeenForThreadController(controller);
    });
}

static void SCIHooked_setHasSentAMessageOrUpdate(id self, SEL _cmd, BOOL sent) {
    if (orig_setHasSentAMessageOrUpdate) {
        orig_setHasSentAMessageOrUpdate(self, _cmd, sent);
    }
    SCIHandleDidSendMessageState(self, sent);
}

static void SCIHooked_setHasSentAMessage(id self, SEL _cmd, BOOL sent) {
    if (orig_setHasSentAMessage) {
        orig_setHasSentAMessage(self, _cmd, sent);
    }
    SCIHandleDidSendMessageState(self, sent);
}

static BOOL SCIOverlayIsDirectVisualOverlay(UIView *overlayView) {
    UIViewController *nearestVC = [SCIUtils nearestViewControllerForView:overlayView];
    Class directViewerClass = NSClassFromString(@"IGDirectVisualMessageViewerController");
    return (directViewerClass && [nearestVC isKindOfClass:directViewerClass]);
}

static NSArray *SCIArrayFromCollection(id collection) {
    if (!collection ||
        [collection isKindOfClass:[NSDictionary class]] ||
        [collection isKindOfClass:[NSString class]] ||
        [collection isKindOfClass:[NSURL class]]) {
        return nil;
    }

    if ([collection isKindOfClass:[NSArray class]]) {
        return collection;
    }

    if ([collection isKindOfClass:[NSOrderedSet class]]) {
        return [(NSOrderedSet *)collection array];
    }

    if ([collection isKindOfClass:[NSSet class]]) {
        return [(NSSet *)collection allObjects];
    }

    if ([collection conformsToProtocol:@protocol(NSFastEnumeration)]) {
        NSMutableArray *array = [NSMutableArray array];
        for (id item in collection) {
            [array addObject:item];
        }
        return array;
    }

    return nil;
}

static id SCIKVCObject(id target, NSString *key) {
    if (!target || key.length == 0) return nil;

    @try {
        return [target valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id SCIObjectForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;

    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return nil;

    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static id SCIFirstObjectForSelectors(id target, NSArray<NSString *> *selectors) {
    if (!target || selectors.count == 0) return nil;
    for (NSString *selectorName in selectors) {
        id value = SCIObjectForSelector(target, selectorName);
        if (value) return value;
    }
    return nil;
}

static void SCIPlayButtonTappedHaptic(void) {
    UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
    [feedback selectionChanged];
}

static UIButton *SCIStorySeenButtonWithTag(UIView *container, NSInteger tag) {
    UIView *existing = [container viewWithTag:tag];
    if ([existing isKindOfClass:[UIButton class]]) {
        return (UIButton *)existing;
    }

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = tag;
    button.adjustsImageWhenHighlighted = YES;
    button.showsMenuAsPrimaryAction = NO;
    button.clipsToBounds = NO;
    [container addSubview:button];
    return button;
}

static void SCIApplyStorySeenButtonStyle(UIButton *button) {
    if (!button) return;

    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = UIColor.clearColor;
    button.layer.cornerRadius = 8.0;
    button.layer.shadowColor = [UIColor blackColor].CGColor;
    button.layer.shadowOpacity = 0.5;
    button.layer.shadowRadius = 2.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 2.0);
}

static UIView *SCIStoryFooterContainerFromOverlay(UIView *overlayView) {
    if (!overlayView) return nil;

    UIView *footerContainer = [SCIUtils getIvarForObj:overlayView name:"_footerContainerView"];
    if (![footerContainer isKindOfClass:[UIView class]]) {
        id selectorFooter = SCIObjectForSelector(overlayView, @"footerContainerView");
        footerContainer = [selectorFooter isKindOfClass:[UIView class]] ? (UIView *)selectorFooter : nil;
    }
    return footerContainer;
}

static void SCIUpdateStoryButtonsAlpha(UIView *overlayView, CGFloat alpha) {
    if (!overlayView) return;

    UIButton *actionButton = (UIButton *)[overlayView viewWithTag:kSCIStoriesActionButtonTag];
    if ([actionButton isKindOfClass:[UIButton class]]) {
        actionButton.alpha = alpha;
    }

    UIButton *seenButton = (UIButton *)[overlayView viewWithTag:kSCIStorySeenButtonTag];
    if ([seenButton isKindOfClass:[UIButton class]]) {
        seenButton.alpha = alpha;
    }

    UIButton *mentionsButton = (UIButton *)[overlayView viewWithTag:kSCIStoryMentionsButtonTag];
    if ([mentionsButton isKindOfClass:[UIButton class]]) {
        mentionsButton.alpha = alpha;
    }
}

static void SCIRemoveStoryOverlayAlphaObserverIfNeeded(UIView *overlayView) {
    UIView *observedFooter = objc_getAssociatedObject(overlayView, kSCIStoryOverlayObservedFooterAssocKey);
    BOOL hasObserver = [objc_getAssociatedObject(overlayView, kSCIStoryOverlayHasObserverAssocKey) boolValue];
    if (observedFooter && hasObserver) {
        [observedFooter removeObserver:overlayView forKeyPath:@"alpha" context:kSCIStoryOverlayAlphaObserverContext];
    }

    objc_setAssociatedObject(overlayView, kSCIStoryOverlayObservedFooterAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(overlayView, kSCIStoryOverlayHasObserverAssocKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SCIEnsureStoryOverlayAlphaObserver(UIView *overlayView) {
    if (!overlayView) return;

    UIView *footerContainer = SCIStoryFooterContainerFromOverlay(overlayView);
    UIView *observedFooter = objc_getAssociatedObject(overlayView, kSCIStoryOverlayObservedFooterAssocKey);
    BOOL hasObserver = [objc_getAssociatedObject(overlayView, kSCIStoryOverlayHasObserverAssocKey) boolValue];
    if (observedFooter && observedFooter != footerContainer && hasObserver) {
        [observedFooter removeObserver:overlayView forKeyPath:@"alpha" context:kSCIStoryOverlayAlphaObserverContext];
        objc_setAssociatedObject(overlayView, kSCIStoryOverlayHasObserverAssocKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        hasObserver = NO;
    }

    if (observedFooter != footerContainer) {
        objc_setAssociatedObject(overlayView, kSCIStoryOverlayObservedFooterAssocKey, footerContainer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (footerContainer && !hasObserver) {
        [footerContainer addObserver:overlayView
                          forKeyPath:@"alpha"
                             options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                             context:kSCIStoryOverlayAlphaObserverContext];
        objc_setAssociatedObject(overlayView, kSCIStoryOverlayHasObserverAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static CGRect SCIStorySeenBaseFrame(UIView *overlayView) {
    if (!overlayView) return CGRectZero;

    CGFloat size = 38.0;
    CGFloat y = 0.0;

    UIView *mediaView = [SCIUtils getIvarForObj:overlayView name:"_mediaView"];
    UIView *footerContainer = [SCIUtils getIvarForObj:overlayView name:"_footerContainerView"];
    if (![mediaView isKindOfClass:[UIView class]]) mediaView = nil;
    if (![footerContainer isKindOfClass:[UIView class]]) footerContainer = nil;

    if (mediaView) {
        CGRect mediaFrame = mediaView.frame;
        y = CGRectGetMaxY(mediaFrame) - size - 7.0;
        if (footerContainer && CGRectGetMinY(footerContainer.frame) < CGRectGetMaxY(mediaFrame)) {
            y -= 50.0;
        }
    } else if (footerContainer) {
        y = CGRectGetMinY(footerContainer.frame) - size - 12.0;
    } else {
        y = CGRectGetHeight(overlayView.bounds) - size - 12.0;
    }

    NSNumber *showCommentsPreview = [SCIUtils numericValueForObj:overlayView selectorName:@"showCommentsPreview"];
    if (!showCommentsPreview) {
        showCommentsPreview = [SCIUtils numericValueForObj:overlayView selectorName:@"isShowingCommentsPreview"];
    }
    if (!showCommentsPreview) {
        id kvcShowComments = SCIKVCObject(overlayView, @"showCommentsPreview");
        if ([kvcShowComments respondsToSelector:@selector(boolValue)]) {
            showCommentsPreview = @([kvcShowComments boolValue]);
        }
    }
    BOOL hasCommentsPreview = showCommentsPreview.boolValue;
    if (hasCommentsPreview) {
        UIView *hypeFaceswarmView = [SCIUtils getIvarForObj:overlayView name:"_hypeFaceswarmView"];
        if ([hypeFaceswarmView isKindOfClass:[UIView class]] && (y + size) > CGRectGetMinY(hypeFaceswarmView.frame)) {
            y = CGRectGetMinY(hypeFaceswarmView.frame) - size - 2.0;
        } else {
            y -= 35.0;
        }
    }

    CGFloat x = CGRectGetWidth(overlayView.frame) - size - 7.0;
    return CGRectMake(x, y, size, size);
}

static id SCIStorySectionControllerFromOverlayView(UIView *overlayView) {
    if (!overlayView) return nil;

    NSArray<NSString *> *delegateSelectors = @[@"mediaOverlayDelegate", @"retryDelegate", @"tappableOverlayDelegate", @"buttonDelegate"];
    Class sectionControllerClass = NSClassFromString(@"IGStoryFullscreenSectionController");

    for (NSString *selectorName in delegateSelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![overlayView respondsToSelector:selector]) continue;

        id delegate = ((id (*)(id, SEL))objc_msgSend)(overlayView, selector);
        if (!delegate) continue;

        if (!sectionControllerClass || [delegate isKindOfClass:sectionControllerClass]) {
            return delegate;
        }
    }

    return nil;
}

static NSString *SCIStringFromValue(id value) {
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *string = (NSString *)value;
        return string.length > 0 ? string : nil;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *string = [value stringValue];
        return string.length > 0 ? string : nil;
    }
    return [[value description] length] > 0 ? [value description] : nil;
}

static id SCIStoryMediaFromAnyObject(id object) {
    if (!object) return nil;
    id candidate = SCIFirstObjectForSelectors(object, @[@"media", @"mediaItem", @"storyItem", @"item", @"model"]);
    return candidate ?: object;
}

static BOOL SCIResolveStoryContextFromOverlay(UIView *overlayView, id *outMarkTarget, id *outSectionController, id *outMedia) {
    if (!overlayView) return NO;

    SEL markSelector = NSSelectorFromString(@"fullscreenSectionController:didMarkItemAsSeen:");
    UIViewController *viewerController = [SCIUtils nearestViewControllerForView:overlayView];

    id sectionController = SCIStorySectionControllerFromOverlayView(overlayView);
    id markTarget = nil;
    id sectionDelegate = SCIObjectForSelector(sectionController, @"delegate");
    if (sectionDelegate && [sectionDelegate respondsToSelector:markSelector]) {
        markTarget = sectionDelegate;
    } else if (viewerController && [viewerController respondsToSelector:markSelector]) {
        markTarget = viewerController;
    } else {
        id overlayAncestor = SCIObjectForSelector(overlayView, @"_viewControllerForAncestor");
        if (overlayAncestor && [overlayAncestor respondsToSelector:markSelector]) {
            markTarget = overlayAncestor;
        }
    }

    if (!sectionController && markTarget) {
        sectionController = SCIFirstObjectForSelectors(markTarget, @[@"currentSectionController"]);
        if (!sectionController) {
            sectionController = [SCIUtils getIvarForObj:markTarget name:"_currentSectionController"];
        }
    }

    id media = SCIFirstObjectForSelectors(sectionController, @[@"currentStoryItem", @"currentItem", @"item"]);
    if (!media) media = SCIFirstObjectForSelectors(markTarget, @[@"currentStoryItem", @"currentItem", @"item"]);
    if (!media && viewerController) media = SCIFirstObjectForSelectors(viewerController, @[@"currentStoryItem", @"currentItem", @"item"]);
    media = SCIStoryMediaFromAnyObject(media);

    if (outMarkTarget) *outMarkTarget = markTarget;
    if (outSectionController) *outSectionController = sectionController;
    if (outMedia) *outMedia = media;

    return (media != nil);
}

static NSArray<NSDictionary *> *SCIStoryMentionsForOverlay(UIView *overlayView) {
    id markTarget = nil;
    id sectionController = nil;
    id media = nil;
    if (!SCIResolveStoryContextFromOverlay(overlayView, &markTarget, &sectionController, &media)) {
        return @[];
    }

    id mentionsCollection = SCIObjectForSelector(media, @"reelMentions");
    NSArray *mentions = SCIArrayFromCollection(mentionsCollection);
    if (mentions.count == 0) return @[];

    NSMutableArray<NSDictionary *> *userInfos = [NSMutableArray array];
    for (id mention in mentions) {
        id user = SCIKVCObject(mention, @"user");
        if (!user) user = SCIObjectForSelector(mention, @"user");
        if (!user) continue;

        NSString *username = SCIStringFromValue(SCIKVCObject(user, @"username"));
        if (!username) username = SCIStringFromValue(SCIObjectForSelector(user, @"username"));
        NSString *fullName = SCIStringFromValue(SCIKVCObject(user, @"fullName"));
        if (!fullName) fullName = SCIStringFromValue(SCIKVCObject(user, @"full_name"));

        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        if (username.length > 0) entry[@"username"] = username;
        if (fullName.length > 0) entry[@"fullName"] = fullName;
        if (entry.count > 0) [userInfos addObject:entry];
    }

    return userInfos;
}

static void SCIAdvanceStoryAfterManualSeenIfNeeded(UIView *overlayView) {
    if (![SCIUtils getBoolPref:@"advance_story_when_marking_seen"]) return;

    id sectionController = SCIStorySectionControllerFromOverlayView(overlayView);
    SEL advanceSelector = NSSelectorFromString(@"storyPlayerMediaViewDidPlayToEnd:");
    if (!sectionController || ![sectionController respondsToSelector:advanceSelector]) return;

    id mediaView = [SCIUtils getIvarForObj:sectionController name:"_mediaView"];
    if (!mediaView) mediaView = [SCIUtils getIvarForObj:overlayView name:"_mediaView"];

    SCIForceStoryAutoAdvance = YES;
    ((void (*)(id, SEL, id))objc_msgSend)(sectionController, advanceSelector, mediaView);
    dispatch_async(dispatch_get_main_queue(), ^{
        SCIForceStoryAutoAdvance = NO;
    });
}

// Forward declaration — implemented in StoryMentions.x
extern void SCIPresentStoryMentionsSheet(UIView *overlayView);

static void SCIMarkCurrentStoryAsSeenFromOverlay(UIView *overlayView) {
    if (!overlayView) return;

    id markTarget = nil;
    id sectionController = nil;
    id media = nil;
    BOOL resolved = SCIResolveStoryContextFromOverlay(overlayView, &markTarget, &sectionController, &media);
    if (!markTarget || !sectionController || !media) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionStoryMarkSeen duration:1.5
                                 title:@"Unable to mark story as seen"
                              subtitle:nil
                          iconResource:@"error_filled"
                                  tone:SCIFeedbackPillToneError];
        return;
    }

    SEL markSelector = NSSelectorFromString(@"fullscreenSectionController:didMarkItemAsSeen:");
    SCIForceMarkStoryAsSeen = YES;
    ((void (*)(id, SEL, id, id))objc_msgSend)(markTarget, markSelector, sectionController, media);
    SCIForceMarkStoryAsSeen = NO;

    if (resolved) {
        SCIAdvanceStoryAfterManualSeenIfNeeded(overlayView);
    }

    [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionStoryMarkSeen duration:1.5
                             title:@"Marked story as seen"
                          subtitle:nil
                      iconResource:@"circle_check_filled"
                              tone:SCIFeedbackPillToneSuccess];
}

static UIView *SCIDirectOverlayViewFromController(UIViewController *controller) {
    if (!controller) return nil;

    id viewerContainer = [SCIUtils getIvarForObj:controller name:"_viewerContainerView"];
    if (!viewerContainer) viewerContainer = SCIKVCObject(controller, @"viewerContainerView");

    SEL overlaySelector = NSSelectorFromString(@"overlayView");
    if (![viewerContainer respondsToSelector:overlaySelector]) return nil;
    id overlay = ((id (*)(id, SEL))objc_msgSend)(viewerContainer, overlaySelector);
    return [overlay isKindOfClass:[UIView class]] ? (UIView *)overlay : nil;
}

static id SCIDirectCurrentMessageFromController(UIViewController *controller) {
    if (!controller) return nil;

    id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
    if (!dataSource) dataSource = SCIKVCObject(controller, @"dataSource");

    id message = [SCIUtils getIvarForObj:dataSource name:"_currentMessage"];
    if (!message) message = SCIKVCObject(dataSource, @"currentMessage");
    return message;
}

static CGFloat SCIHeightFromFrameLikeObject(id object) {
    if (!object) return 0.0;

    if ([object isKindOfClass:[UIView class]]) {
        return ((UIView *)object).frame.size.height;
    }

    @try {
        id frameValue = [object valueForKey:@"frame"];
        if ([frameValue isKindOfClass:[NSValue class]]) {
            return ((NSValue *)frameValue).CGRectValue.size.height;
        }
    } @catch (__unused NSException *exception) {
    }

    return 0.0;
}

static CGFloat SCIDirectBottomOffset(UIViewController *controller) {
    if (!controller) return 12.0;

    id inputView = [SCIUtils getIvarForObj:controller name:"_inputView"];
    CGFloat offset = controller.view.safeAreaInsets.bottom + 12.0;
    if (inputView) {
        offset += SCIHeightFromFrameLikeObject(inputView);
    }

    return offset;
}

static UIView *SCIDirectInputViewFromController(UIViewController *controller) {
    if (!controller) return nil;

    id inputView = [SCIUtils getIvarForObj:controller name:"_inputView"];
    if (![inputView isKindOfClass:[UIView class]]) {
        inputView = SCIKVCObject(controller, @"inputView");
    }
    return [inputView isKindOfClass:[UIView class]] ? (UIView *)inputView : nil;
}

static void SCIUpdateDirectVisualButtonsAlpha(UIViewController *controller, CGFloat alpha) {
    if (!controller) return;
    UIView *overlay = SCIDirectOverlayViewFromController(controller);
    if (!overlay) return;

    UIButton *actionButton = (UIButton *)[overlay viewWithTag:kSCIDirectActionButtonTag];
    if ([actionButton isKindOfClass:[UIButton class]]) {
        actionButton.alpha = alpha;
    }

    UIButton *seenButton = (UIButton *)[overlay viewWithTag:kSCIDirectSeenButtonTag];
    if ([seenButton isKindOfClass:[UIButton class]]) {
        seenButton.alpha = alpha;
    }
}

static void SCIRemoveDirectVisualInputAlphaObserverIfNeeded(UIViewController *controller) {
    UIView *observedInputView = objc_getAssociatedObject(controller, kSCIDirectVisualObservedInputViewAssocKey);
    BOOL hasObserver = [objc_getAssociatedObject(controller, kSCIDirectVisualHasInputObserverAssocKey) boolValue];
    if (observedInputView && hasObserver) {
        [observedInputView removeObserver:controller forKeyPath:@"alpha" context:kSCIDirectVisualInputAlphaObserverContext];
    }

    objc_setAssociatedObject(controller, kSCIDirectVisualObservedInputViewAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, kSCIDirectVisualHasInputObserverAssocKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SCIEnsureDirectVisualInputAlphaObserver(UIViewController *controller) {
    if (!controller) return;

    UIView *inputView = SCIDirectInputViewFromController(controller);
    UIView *observedInputView = objc_getAssociatedObject(controller, kSCIDirectVisualObservedInputViewAssocKey);
    BOOL hasObserver = [objc_getAssociatedObject(controller, kSCIDirectVisualHasInputObserverAssocKey) boolValue];
    if (observedInputView && observedInputView != inputView && hasObserver) {
        [observedInputView removeObserver:controller forKeyPath:@"alpha" context:kSCIDirectVisualInputAlphaObserverContext];
        objc_setAssociatedObject(controller, kSCIDirectVisualHasInputObserverAssocKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        hasObserver = NO;
    }

    if (observedInputView != inputView) {
        objc_setAssociatedObject(controller, kSCIDirectVisualObservedInputViewAssocKey, inputView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (inputView && !hasObserver) {
        [inputView addObserver:controller
                    forKeyPath:@"alpha"
                       options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                       context:kSCIDirectVisualInputAlphaObserverContext];
        objc_setAssociatedObject(controller, kSCIDirectVisualHasInputObserverAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static inline BOOL SCIShouldShowDirectVisualSeenButton(void) {
    return [SCIUtils getBoolPref:@"remove_lastseen"] || [SCIUtils getBoolPref:@"unlimited_replay"];
}

static void SCIMarkDirectVisualMessageAsSeen(UIViewController *controller) {
    if (!controller) return;

    id message = SCIDirectCurrentMessageFromController(controller);
    if (!message) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionDirectVisualMarkSeen duration:1.5
                                 title:@"Message not found"
                              subtitle:nil
                          iconResource:@"error_filled"
                                  tone:SCIFeedbackPillToneError];
        return;
    }

    id responders = [SCIUtils getIvarForObj:controller name:"_eventResponders"];
    if (!responders) responders = SCIKVCObject(controller, @"eventResponders");

    SEL beginPlaybackSelector = NSSelectorFromString(@"visualMessageViewerController:didBeginPlaybackForVisualMessage:atIndex:");
    SCIPendingDirectVisualMessageToMarkSeen = message;
    BOOL dispatched = NO;

    for (id responder in SCIArrayFromCollection(responders) ?: @[]) {
        if ([responder respondsToSelector:beginPlaybackSelector]) {
            dispatched = YES;
            ((void (*)(id, SEL, id, id, NSInteger))objc_msgSend)(responder, beginPlaybackSelector, controller, message, 0);
            break;
        }
    }

    SCIPendingDirectVisualMessageToMarkSeen = nil;
    if (!dispatched) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionDirectVisualMarkSeen duration:1.5
                                 title:@"Unable to mark as seen"
                              subtitle:nil
                          iconResource:@"error_filled"
                                  tone:SCIFeedbackPillToneError];
        return;
    }

    SEL overlayTapSelector = NSSelectorFromString(@"expandOverlay:didTapInRegion:");
    if ([controller respondsToSelector:overlayTapSelector]) {
        ((void (*)(id, SEL, id, NSInteger))objc_msgSend)(controller, overlayTapSelector, nil, 3);
    }

    [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionDirectVisualMarkSeen duration:1.5
                             title:@"Marked as seen"
                          subtitle:nil
                      iconResource:@"circle_check_filled"
                              tone:SCIFeedbackPillToneSuccess];
}

static void SCIInstallDirectSeenButton(UIViewController *controller) {
    UIView *overlay = SCIDirectOverlayViewFromController(controller);
    if (!overlay) return;

    UIButton *seenButton = (UIButton *)[overlay viewWithTag:kSCIDirectSeenButtonTag];
    if (!SCIShouldShowDirectVisualSeenButton()) {
        [seenButton removeFromSuperview];
        return;
    }

    if (![seenButton isKindOfClass:[UIButton class]]) {
        seenButton = [UIButton buttonWithType:UIButtonTypeSystem];
        seenButton.tag = kSCIDirectSeenButtonTag;
        seenButton.adjustsImageWhenHighlighted = YES;
        UIImage *seenImage = [SCIAssetUtils instagramIconNamed:kSCISeenMessagesBarIconResource pointSize:24.0];
        [seenButton setImage:[seenImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [seenButton addTarget:controller action:@selector(sci_didTapDirectSeenButton:) forControlEvents:UIControlEventTouchUpInside];
        [overlay addSubview:seenButton];
    }

    seenButton.translatesAutoresizingMaskIntoConstraints = NO;
    SCIApplyStorySeenButtonStyle(seenButton);

    CGFloat size = 44.0;
    CGFloat bottomOffset = SCIDirectBottomOffset(controller);
    UIButton *actionButton = (UIButton *)[overlay viewWithTag:kSCIDirectActionButtonTag];
    BOOL actionVisible = [actionButton isKindOfClass:[UIButton class]]
        && !actionButton.hidden
        && actionButton.superview == overlay
        && CGRectGetWidth(actionButton.bounds) > 0.0
        && CGRectGetHeight(actionButton.bounds) > 0.0;

    NSLayoutConstraint *bottomConstraint = objc_getAssociatedObject(seenButton, kSCIDirectSeenBottomConstraintAssocKey);
    NSLayoutConstraint *trailingOverlayConstraint = objc_getAssociatedObject(seenButton, kSCIDirectSeenTrailingOverlayConstraintAssocKey);
    NSLayoutConstraint *trailingActionConstraint = objc_getAssociatedObject(seenButton, kSCIDirectSeenTrailingActionConstraintAssocKey);
    NSLayoutConstraint *centerYActionConstraint = objc_getAssociatedObject(seenButton, kSCIDirectSeenCenterYActionConstraintAssocKey);
    NSLayoutConstraint *widthConstraint = objc_getAssociatedObject(seenButton, kSCIDirectSeenWidthConstraintAssocKey);
    NSLayoutConstraint *heightConstraint = objc_getAssociatedObject(seenButton, kSCIDirectSeenHeightConstraintAssocKey);
    UIButton *anchoredActionButton = objc_getAssociatedObject(seenButton, kSCIDirectSeenAnchoredActionButtonAssocKey);

    if (!bottomConstraint || !trailingOverlayConstraint || !widthConstraint || !heightConstraint) {
        bottomConstraint = [seenButton.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor constant:-bottomOffset];
        trailingOverlayConstraint = [seenButton.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-10.0];
        widthConstraint = [seenButton.widthAnchor constraintEqualToConstant:size];
        heightConstraint = [seenButton.heightAnchor constraintEqualToConstant:size];

        [NSLayoutConstraint activateConstraints:@[
            bottomConstraint,
            trailingOverlayConstraint,
            widthConstraint,
            heightConstraint
        ]];

        objc_setAssociatedObject(seenButton, kSCIDirectSeenBottomConstraintAssocKey, bottomConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(seenButton, kSCIDirectSeenTrailingOverlayConstraintAssocKey, trailingOverlayConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(seenButton, kSCIDirectSeenWidthConstraintAssocKey, widthConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(seenButton, kSCIDirectSeenHeightConstraintAssocKey, heightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (actionVisible && (!trailingActionConstraint || anchoredActionButton != actionButton)) {
        if (trailingActionConstraint) {
            trailingActionConstraint.active = NO;
        }
        trailingActionConstraint = [seenButton.trailingAnchor constraintEqualToAnchor:actionButton.leadingAnchor constant:-5.0];
        objc_setAssociatedObject(seenButton, kSCIDirectSeenTrailingActionConstraintAssocKey, trailingActionConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(seenButton, kSCIDirectSeenAnchoredActionButtonAssocKey, actionButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (actionVisible && (!centerYActionConstraint || anchoredActionButton != actionButton)) {
        if (centerYActionConstraint) {
            centerYActionConstraint.active = NO;
        }
        centerYActionConstraint = [seenButton.centerYAnchor constraintEqualToAnchor:actionButton.centerYAnchor];
        objc_setAssociatedObject(seenButton, kSCIDirectSeenCenterYActionConstraintAssocKey, centerYActionConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    bottomConstraint.constant = -bottomOffset;
    trailingOverlayConstraint.constant = -10.0;
    widthConstraint.constant = size;
    heightConstraint.constant = size;

    if (actionVisible && trailingActionConstraint) {
        bottomConstraint.active = NO;
        trailingOverlayConstraint.active = NO;
        trailingActionConstraint.active = YES;
        if (centerYActionConstraint) centerYActionConstraint.active = YES;
    } else {
        if (centerYActionConstraint) centerYActionConstraint.active = NO;
        if (trailingActionConstraint) trailingActionConstraint.active = NO;
        trailingOverlayConstraint.active = YES;
        bottomConstraint.active = YES;
    }

    [overlay bringSubviewToFront:seenButton];
}

// Seen buttons (in DMs)
// - Enables no seen for messages
%hook IGTallNavigationBarView
- (void)setRightBarButtonItems:(NSArray <UIBarButtonItem *> *)items {
    NSMutableArray *new_items = [[items filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(UIView *value, NSDictionary *_) {
            if ([SCIUtils getBoolPref:@"hide_reels_blend"]) {
                return ![value.accessibilityIdentifier isEqualToString:@"blend-button"];
            }

            return true;
        }]
    ] mutableCopy];

    // Messages seen
    if (SCIManualMessageSeenEnabled()) {
        UIImage *seenImg = [SCIAssetUtils instagramIconNamed:kSCISeenMessagesBarIconResource pointSize:24.0];
        UIBarButtonItem *seenButton = [[UIBarButtonItem alloc] initWithImage:seenImg style:UIBarButtonItemStylePlain target:self action:@selector(seenButtonHandler:)];
        [new_items addObject:seenButton];
    }

    %orig([new_items copy]);
}

// Messages seen button
%new - (void)seenButtonHandler:(UIBarButtonItem *)sender {
    (void)sender;
    SCIPlayButtonTappedHaptic();
    UIViewController *nearestVC = [SCIUtils nearestViewControllerForView:self];
    if ([nearestVC isKindOfClass:%c(IGDirectThreadViewController)]) {
        [(IGDirectThreadViewController *)nearestVC markLastMessageAsSeen];

        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionThreadMessagesMarkSeen duration:2.5
                                 title:@"Marked messages as seen"
                              subtitle:nil
                          iconResource:@"circle_check_filled"
                                  tone:SCIFeedbackPillToneSuccess];
    }
}
%end

// Messages seen logic
%hook IGDirectThreadViewListAdapterDataSource
- (BOOL)shouldUpdateLastSeenMessage {
    if (SCIManualMessageSeenEnabled()) {
        if (kSCISeenAutoBypassCount > 0) {
            return %orig;
        }
        return false;
    }
    
    return %orig;
}
%end

%hook IGDirectMessageListViewController
- (BOOL)messageListDataSourceShouldUpdateSeenState:(id)arg1 {
    if (SCIManualMessageSeenEnabled()) {
        return false;
    }

    return %orig;
}
%end

%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
    %orig;

    UIView *overlayView = (UIView *)self;
    SCIEnsureStoryOverlayAlphaObserver(overlayView);

    UIButton *seenButton = (UIButton *)[(UIView *)self viewWithTag:kSCIStorySeenButtonTag];
    UIButton *mentionsButton = (UIButton *)[(UIView *)self viewWithTag:kSCIStoryMentionsButtonTag];
    if (SCIOverlayIsDirectVisualOverlay((UIView *)self)) {
        [seenButton removeFromSuperview];
        [mentionsButton removeFromSuperview];
        UIView *footerContainer = SCIStoryFooterContainerFromOverlay(overlayView);
        if (footerContainer) {
            SCIUpdateStoryButtonsAlpha(overlayView, footerContainer.alpha);
        }
        return;
    }

    BOOL showSeenButton = SCIManualStorySeenEnabled();
    if (!showSeenButton) {
        [seenButton removeFromSuperview];
        [mentionsButton removeFromSuperview];
        UIView *footerContainer = SCIStoryFooterContainerFromOverlay(overlayView);
        if (footerContainer) {
            SCIUpdateStoryButtonsAlpha(overlayView, footerContainer.alpha);
        }
        return;
    }

    if (showSeenButton && !seenButton) {
        seenButton = SCIStorySeenButtonWithTag((UIView *)self, kSCIStorySeenButtonTag);
        [seenButton addTarget:self action:@selector(sci_storySeenButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIImage *seenImage = [SCIAssetUtils instagramIconNamed:kSCISeenMessagesBarIconResource pointSize:24.0];
        [seenButton setImage:[seenImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    }
    if (showSeenButton) SCIApplyStorySeenButtonStyle(seenButton);

    NSArray<NSDictionary *> *storyMentions = SCIStoryMentionsForOverlay(overlayView);
    BOOL showMentionsButton = SCIStoryMentionsButtonEnabled() && storyMentions.count > 0;
    if (showMentionsButton && !mentionsButton) {
        mentionsButton = SCIStorySeenButtonWithTag((UIView *)self, kSCIStoryMentionsButtonTag);
        [mentionsButton addTarget:self action:@selector(sci_storyMentionsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIImage *mentionsImage = [SCIAssetUtils instagramIconNamed:kSCIStoryMentionsBarIconResource pointSize:24.0];
        [mentionsButton setImage:[mentionsImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    } else if (!showMentionsButton && mentionsButton) {
        [mentionsButton removeFromSuperview];
        mentionsButton = nil;
    }
    if (showMentionsButton) SCIApplyStorySeenButtonStyle(mentionsButton);

    UIButton *storyActionButton = (UIButton *)[overlayView viewWithTag:kSCIStoriesActionButtonTag];
    BOOL actionVisible = [storyActionButton isKindOfClass:[UIButton class]]
        && !storyActionButton.hidden
        && storyActionButton.superview == overlayView
        && CGRectGetWidth(storyActionButton.frame) > 0.0
        && CGRectGetHeight(storyActionButton.frame) > 0.0;

    CGRect baseFrame = SCIStorySeenBaseFrame(overlayView);
    CGFloat size = CGRectGetWidth(baseFrame);
    if (actionVisible) {
        size = CGRectGetWidth(storyActionButton.frame);
    }
    if (size <= 0.0) size = 38.0;

    CGFloat y = actionVisible ? CGRectGetMinY(storyActionButton.frame) : CGRectGetMinY(baseFrame);
    CGFloat nextX = actionVisible
        ? (CGRectGetMinX(storyActionButton.frame) - size - 5.0)
        : CGRectGetMinX(baseFrame);

    if (showSeenButton && seenButton) {
        seenButton.frame = CGRectMake(nextX, y, size, size);
        [overlayView bringSubviewToFront:seenButton];
        nextX -= (size + 5.0);
    } else if (seenButton) {
        [seenButton removeFromSuperview];
        seenButton = nil;
    }

    if (showMentionsButton && mentionsButton) {
        mentionsButton.frame = CGRectMake(nextX, y, size, size);
        [overlayView bringSubviewToFront:mentionsButton];
    }

    UIView *footerContainer = SCIStoryFooterContainerFromOverlay(overlayView);
    if (footerContainer) {
        SCIUpdateStoryButtonsAlpha(overlayView, footerContainer.alpha);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    if (context == kSCIStoryOverlayAlphaObserverContext && [keyPath isEqualToString:@"alpha"]) {
        CGFloat alpha = 1.0;
        id newAlphaValue = change[NSKeyValueChangeNewKey];
        if ([newAlphaValue respondsToSelector:@selector(floatValue)]) {
            alpha = [newAlphaValue floatValue];
        } else if ([object isKindOfClass:[UIView class]]) {
            alpha = ((UIView *)object).alpha;
        }
        SCIUpdateStoryButtonsAlpha((UIView *)self, alpha);
        return;
    }

    %orig(keyPath, object, change, context);
}

- (void)dealloc {
    SCIRemoveStoryOverlayAlphaObserverIfNeeded((UIView *)self);
    %orig;
}

%new - (void)sci_storySeenButtonTapped:(UIButton *)sender {
    (void)sender;
    SCIPlayButtonTappedHaptic();
    SCIMarkCurrentStoryAsSeenFromOverlay((UIView *)self);
}

%new - (void)sci_storyMentionsButtonTapped:(UIButton *)sender {
    (void)sender;
    SCIPlayButtonTappedHaptic();
    SCIPresentStoryMentionsSheet((UIView *)self);
}
%end

%hook IGDirectVisualMessageViewerController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *inputView = SCIDirectInputViewFromController((UIViewController *)self);
    SCIEnsureDirectVisualInputAlphaObserver((UIViewController *)self);
    SCIInstallDirectSeenButton((UIViewController *)self);
    SCIUpdateDirectVisualButtonsAlpha((UIViewController *)self, inputView ? inputView.alpha : 1.0);
    __weak UIViewController *weakController = (UIViewController *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *strongController = weakController;
        if (!strongController) return;
        UIView *strongInputView = SCIDirectInputViewFromController(strongController);
        SCIInstallDirectSeenButton(strongController);
        SCIUpdateDirectVisualButtonsAlpha(strongController, strongInputView ? strongInputView.alpha : 1.0);
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    if (context == kSCIDirectVisualInputAlphaObserverContext && [keyPath isEqualToString:@"alpha"]) {
        CGFloat alpha = 1.0;
        id newAlphaValue = change[NSKeyValueChangeNewKey];
        if ([newAlphaValue respondsToSelector:@selector(floatValue)]) {
            alpha = [newAlphaValue floatValue];
        } else if ([object isKindOfClass:[UIView class]]) {
            alpha = ((UIView *)object).alpha;
        }
        SCIUpdateDirectVisualButtonsAlpha((UIViewController *)self, alpha);
        return;
    }

    %orig(keyPath, object, change, context);
}

- (void)dealloc {
    SCIRemoveDirectVisualInputAlphaObserverIfNeeded((UIViewController *)self);
    %orig;
}

%new - (void)sci_didTapDirectSeenButton:(UIButton *)sender {
    (void)sender;
    SCIPlayButtonTappedHaptic();
    SCIMarkDirectVisualMessageAsSeen((UIViewController *)self);
}
%end

%ctor {
    Class threadVCClass = NSClassFromString(@"IGDirectThreadViewController");
    if (!threadVCClass) return;

    SEL setHasSentOrUpdateSelector = NSSelectorFromString(@"setHasSentAMessageOrUpdate:");
    if (class_getInstanceMethod(threadVCClass, setHasSentOrUpdateSelector)) {
        MSHookMessageEx(threadVCClass,
                        setHasSentOrUpdateSelector,
                        (IMP)SCIHooked_setHasSentAMessageOrUpdate,
                        (IMP *)&orig_setHasSentAMessageOrUpdate);
    }

    SEL setHasSentSelector = NSSelectorFromString(@"setHasSentAMessage:");
    if (class_getInstanceMethod(threadVCClass, setHasSentSelector)) {
        MSHookMessageEx(threadVCClass,
                        setHasSentSelector,
                        (IMP)SCIHooked_setHasSentAMessage,
                        (IMP *)&orig_setHasSentAMessage);
    }
}
