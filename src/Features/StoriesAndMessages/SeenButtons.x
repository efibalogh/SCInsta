#import <objc/message.h>
#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Tweak.h"
#import "../../Utils.h"

static NSString * const kSCISeenMessagesBarIconResource = @"eye";
static NSInteger const kSCIStorySeenButtonTag = 926001;
static NSInteger const kSCIStoriesActionButtonTag = 921343;
static NSInteger const kSCIDirectActionButtonTag = 921344;
static NSInteger const kSCIDirectSeenButtonTag = 921345;

static inline BOOL SCIManualMessageSeenEnabled(void) {
    return [SCIUtils getBoolPref:@"remove_lastseen"];
}

static inline BOOL SCIManualStorySeenEnabled(void) {
    return [SCIUtils getBoolPref:@"no_seen_receipt"];
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
    button.layer.cornerRadius = 0.0;
    button.layer.shadowOpacity = 0.0;
    button.layer.shadowRadius = 0.0;
    button.layer.shadowOffset = CGSizeZero;
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

    id showCommentsPreview = [SCIUtils getIvarForObj:overlayView name:"_showCommentsPreview"];
    BOOL hasCommentsPreview = [showCommentsPreview respondsToSelector:@selector(boolValue)] ? [showCommentsPreview boolValue] : NO;
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

static void SCIMarkCurrentStoryAsSeenFromOverlay(UIView *overlayView) {
    if (!overlayView) return;

    UIViewController *viewerController = [SCIUtils nearestViewControllerForView:overlayView];
    Class viewerClass = NSClassFromString(@"IGStoryViewerViewController");
    if (!viewerController || (viewerClass && ![viewerController isKindOfClass:viewerClass])) {
        [SCIUtils showToastForDuration:1.5 title:@"Story viewer unavailable"];
        return;
    }

    id sectionController = SCIStorySectionControllerFromOverlayView(overlayView);
    if (!sectionController) {
        sectionController = [SCIUtils getIvarForObj:viewerController name:"_currentSectionController"];
    }

    id media = nil;
    SEL currentStorySelector = NSSelectorFromString(@"currentStoryItem");
    if (sectionController && [sectionController respondsToSelector:currentStorySelector]) {
        media = ((id (*)(id, SEL))objc_msgSend)(sectionController, currentStorySelector);
    }
    if (!media && [viewerController respondsToSelector:currentStorySelector]) {
        media = ((id (*)(id, SEL))objc_msgSend)(viewerController, currentStorySelector);
    }

    SEL markSelector = NSSelectorFromString(@"fullscreenSectionController:didMarkItemAsSeen:");
    if (!sectionController || !media || ![viewerController respondsToSelector:markSelector]) {
        [SCIUtils showToastForDuration:1.5 title:@"Unable to mark story as seen"];
        return;
    }

    SCIForceMarkStoryAsSeen = YES;
    ((void (*)(id, SEL, id, id))objc_msgSend)(viewerController, markSelector, sectionController, media);
    SCIForceMarkStoryAsSeen = NO;

    [SCIUtils showToastForDuration:1.5 title:@"Marked story as seen"];
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

static inline BOOL SCIShouldShowDirectVisualSeenButton(void) {
    return [SCIUtils getBoolPref:@"remove_lastseen"] || [SCIUtils getBoolPref:@"unlimited_replay"];
}

static void SCIMarkDirectVisualMessageAsSeen(UIViewController *controller) {
    if (!controller) return;

    id message = SCIDirectCurrentMessageFromController(controller);
    if (!message) {
        [SCIUtils showToastForDuration:1.5 title:@"Message not found"];
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
        [SCIUtils showToastForDuration:1.5 title:@"Unable to mark as seen"];
        return;
    }

    SEL overlayTapSelector = NSSelectorFromString(@"fullscreenOverlay:didTapInRegion:");
    if ([controller respondsToSelector:overlayTapSelector]) {
        ((void (*)(id, SEL, id, NSInteger))objc_msgSend)(controller, overlayTapSelector, nil, 3);
    }

    [SCIUtils showToastForDuration:1.5 title:@"Marked as seen"];
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
        UIImage *seenImage = [SCIUtils sci_resourceImageNamed:kSCISeenMessagesBarIconResource template:YES maxPointSize:24.0] ?: [UIImage systemImageNamed:@"eye"];
        [seenButton setImage:[seenImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [seenButton addTarget:controller action:@selector(sci_didTapDirectSeenButton:) forControlEvents:UIControlEventTouchUpInside];
        [overlay addSubview:seenButton];
    }

    seenButton.translatesAutoresizingMaskIntoConstraints = YES;
    SCIApplyStorySeenButtonStyle(seenButton);

    CGFloat size = 44.0;
    CGFloat bottomOffset = SCIDirectBottomOffset(controller);
    [overlay layoutIfNeeded];

    UIButton *actionButton = (UIButton *)[overlay viewWithTag:kSCIDirectActionButtonTag];
    BOOL actionVisible = [actionButton isKindOfClass:[UIButton class]]
        && !actionButton.hidden
        && actionButton.superview == overlay
        && CGRectGetWidth(actionButton.frame) > 0.0
        && CGRectGetHeight(actionButton.frame) > 0.0;

    CGFloat overlayWidth = CGRectGetWidth(overlay.bounds);
    CGFloat overlayHeight = CGRectGetHeight(overlay.bounds);
    if (overlayWidth <= 0.0 || overlayHeight <= 0.0) {
        overlayWidth = CGRectGetWidth(overlay.frame);
        overlayHeight = CGRectGetHeight(overlay.frame);
    }

    CGFloat x = overlayWidth - size - 10.0;
    CGFloat y = overlayHeight - bottomOffset - size;
    if (actionVisible) {
        x = CGRectGetMinX(actionButton.frame) - size - 5.0;
        y = CGRectGetMinY(actionButton.frame);
    }
    seenButton.frame = CGRectMake(x, y, size, size);

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
        UIImage *seenImg = [SCIUtils sci_resourceImageNamed:kSCISeenMessagesBarIconResource template:YES] ?: [UIImage systemImageNamed:@"checkmark.message"];
        UIBarButtonItem *seenButton = [[UIBarButtonItem alloc] initWithImage:seenImg style:UIBarButtonItemStylePlain target:self action:@selector(seenButtonHandler:)];
        [new_items addObject:seenButton];
    }

    %orig([new_items copy]);
}

// Messages seen button
%new - (void)seenButtonHandler:(UIBarButtonItem *)sender {
    (void)sender;
    UIViewController *nearestVC = [SCIUtils nearestViewControllerForView:self];
    if ([nearestVC isKindOfClass:%c(IGDirectThreadViewController)]) {
        [(IGDirectThreadViewController *)nearestVC markLastMessageAsSeen];

        [SCIUtils showToastForDuration:2.5 title:@"Marked messages as seen"];
    }
}
%end

// Messages seen logic
%hook IGDirectThreadViewListAdapterDataSource
- (BOOL)shouldUpdateLastSeenMessage {
    if (SCIManualMessageSeenEnabled()) {
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

    UIButton *seenButton = (UIButton *)[(UIView *)self viewWithTag:kSCIStorySeenButtonTag];
    if (SCIOverlayIsDirectVisualOverlay((UIView *)self)) {
        [seenButton removeFromSuperview];
        return;
    }

    if (!SCIManualStorySeenEnabled()) {
        [seenButton removeFromSuperview];
        return;
    }

    if (!seenButton) {
        seenButton = SCIStorySeenButtonWithTag((UIView *)self, kSCIStorySeenButtonTag);
        [seenButton addTarget:self action:@selector(sci_storySeenButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIImage *seenImage = [SCIUtils sci_resourceImageNamed:kSCISeenMessagesBarIconResource template:YES maxPointSize:24.0] ?: [UIImage systemImageNamed:@"eye"];
        [seenButton setImage:[seenImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    }

    SCIApplyStorySeenButtonStyle(seenButton);

    UIView *overlayView = (UIView *)self;
    UIButton *storyActionButton = (UIButton *)[overlayView viewWithTag:kSCIStoriesActionButtonTag];
    BOOL actionVisible = [storyActionButton isKindOfClass:[UIButton class]]
        && !storyActionButton.hidden
        && storyActionButton.superview == overlayView
        && CGRectGetWidth(storyActionButton.frame) > 0.0
        && CGRectGetHeight(storyActionButton.frame) > 0.0;

    CGRect seenFrame = SCIStorySeenBaseFrame(overlayView);
    if (actionVisible) {
        CGFloat size = CGRectGetWidth(storyActionButton.frame);
        if (size <= 0.0) size = CGRectGetWidth(seenFrame);
        seenFrame = CGRectMake(CGRectGetMinX(storyActionButton.frame) - size - 5.0, CGRectGetMinY(storyActionButton.frame), size, size);
    }

    seenButton.frame = seenFrame;
    [overlayView bringSubviewToFront:seenButton];
}

%new - (void)sci_storySeenButtonTapped:(UIButton *)sender {
    (void)sender;
    SCIMarkCurrentStoryAsSeenFromOverlay((UIView *)self);
}
%end

%hook IGDirectVisualMessageViewerController
- (void)viewDidLayoutSubviews {
    %orig;
    SCIInstallDirectSeenButton((UIViewController *)self);
    __weak UIViewController *weakController = (UIViewController *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *strongController = weakController;
        if (!strongController) return;
        SCIInstallDirectSeenButton(strongController);
    });
}

%new - (void)sci_didTapDirectSeenButton:(UIButton *)sender {
    (void)sender;
    SCIMarkDirectVisualMessageAsSeen((UIViewController *)self);
}
%end
