#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Downloader/Download.h"
#import "../../Vault/SCIVaultFile.h"
#import "../../Vault/SCIVaultSaveMetadata.h"
#import "../../MediaPreview/SCIFullScreenMediaPlayer.h"
#import "../../MediaPreview/SCIMediaItem.h"

@interface IGUFIButtonBarView : UIView
@end

@interface IGStoryViewerViewController : UIViewController
@end

static SCIDownloadDelegate *dlBtnImageDelegate;
static SCIDownloadDelegate *dlBtnVideoDelegate;
static SCIDownloadDelegate *dlBtnShareImageDelegate;
static SCIDownloadDelegate *dlBtnShareVideoDelegate;
static SCIDownloadDelegate *dlBtnVaultImageDelegate;
static SCIDownloadDelegate *dlBtnVaultVideoDelegate;

static NSInteger const kSCIDownloadButtonTag = 8315931;
static NSInteger const kSCIDirectDownloadButtonTag = 13123;
static void *kSCIStorySectionControllerKey = &kSCIStorySectionControllerKey;
static void *kSCIDownloadButtonDesiredAlphaKey = &kSCIDownloadButtonDesiredAlphaKey;
static void *kSCIDirectVaultHostControllerKey = &kSCIDirectVaultHostControllerKey;
static void (*orig_socialUFI_layoutSubviews)(id, SEL);

typedef id (^SCIResolveObjectBlock)(void);
typedef NSInteger (^SCIResolveIndexBlock)(void);

@interface SCIDownloadMenuButton : UIButton
@end

@implementation SCIDownloadMenuButton

- (void)setHidden:(BOOL)hidden {
    [super setHidden:NO];

    if (self.imageView) {
        self.imageView.hidden = NO;
    }
}

- (void)setAlpha:(CGFloat)alpha {
    NSNumber *alphaValue = objc_getAssociatedObject(self, kSCIDownloadButtonDesiredAlphaKey);
    CGFloat desiredAlpha = alphaValue ? alphaValue.doubleValue : alpha;
    [super setAlpha:desiredAlpha];

    if (self.imageView) {
        self.imageView.alpha = 1.0;
    }
}

- (void)sci_restoreVisibleState {
    NSNumber *alphaValue = objc_getAssociatedObject(self, kSCIDownloadButtonDesiredAlphaKey);
    CGFloat desiredAlpha = alphaValue ? alphaValue.doubleValue : 1.0;

    self.hidden = NO;
    self.alpha = desiredAlpha;
    self.layer.opacity = 1.0f;

    if (self.imageView) {
        self.imageView.hidden = NO;
        self.imageView.alpha = 1.0;
    }
}

- (void)sci_menuActionTriggered:(id)sender {
    [self sci_restoreVisibleState];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self sci_restoreVisibleState];
    });
}

- (id)contextMenuInteraction:(id)interaction previewForHighlightingMenuWithConfiguration:(id)configuration {
    [self sci_restoreVisibleState];
    return nil;
}

- (id)contextMenuInteraction:(id)interaction previewForDismissingMenuWithConfiguration:(id)configuration {
    [self sci_restoreVisibleState];
    return nil;
}

- (void)contextMenuInteraction:(id)interaction willDisplayMenuForConfiguration:(id)configuration animator:(id)animator {
    [super contextMenuInteraction:interaction willDisplayMenuForConfiguration:configuration animator:animator];
    [self sci_restoreVisibleState];
}

- (void)contextMenuInteraction:(id)interaction willEndForConfiguration:(id)configuration animator:(id)animator {
    [super contextMenuInteraction:interaction willEndForConfiguration:configuration animator:animator];
    [self sci_restoreVisibleState];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self sci_restoreVisibleState];
    });
}

@end

static void SCIInitDownloadButtonDownloaders(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dlBtnImageDelegate = [[SCIDownloadDelegate alloc] initWithAction:saveToPhotos showProgress:YES];
        dlBtnVideoDelegate = [[SCIDownloadDelegate alloc] initWithAction:saveToPhotos showProgress:YES];
        dlBtnShareImageDelegate = [[SCIDownloadDelegate alloc] initWithAction:share showProgress:YES];
        dlBtnShareVideoDelegate = [[SCIDownloadDelegate alloc] initWithAction:share showProgress:YES];
        dlBtnVaultImageDelegate = [[SCIDownloadDelegate alloc] initWithAction:saveToVault showProgress:YES];
        dlBtnVaultVideoDelegate = [[SCIDownloadDelegate alloc] initWithAction:saveToVault showProgress:YES];
    });
}

static id SCIObjectForSelector(id target, NSString *selectorName) {
    if (!target) return nil;

    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return nil;

    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static NSInteger SCIIntegerForSelector(id target, NSString *selectorName, NSInteger fallback) {
    if (!target) return fallback;

    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return fallback;

    return ((NSInteger (*)(id, SEL))objc_msgSend)(target, selector);
}

static id SCIKVCObject(id target, NSString *key) {
    if (!target || !key.length) return nil;

    @try {
        return [target valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL SCIKVCBool(id target, NSString *key, BOOL fallback) {
    id value = SCIKVCObject(target, key);
    if (!value) return fallback;

    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }

    return fallback;
}

static CGRect SCIFrameInContainer(UIView *view, UIView *container) {
    if (!view || !container) return CGRectZero;

    if (view.superview == container) {
        return view.frame;
    }

    return [container convertRect:view.bounds fromView:view];
}

static void SCIAllowContextMenuOverflow(UIView *view) {
    UIView *ancestor = view;
    NSInteger depth = 0;

    while (ancestor && depth < 6) {
        ancestor.clipsToBounds = NO;
        ancestor.layer.masksToBounds = NO;
        ancestor = ancestor.superview;
        depth++;
    }
}

static void SCISetButtonDesiredAlpha(UIButton *button, CGFloat alpha) {
    if (!button) {
        return;
    }

    objc_setAssociatedObject(button, kSCIDownloadButtonDesiredAlphaKey, @(alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    button.hidden = NO;
    button.alpha = alpha;
    button.layer.opacity = 1.0f;

    if (button.imageView) {
        button.imageView.hidden = NO;
        button.imageView.alpha = 1.0;
    }
}

static UIView *SCIRecursiveSubviewOfClass(UIView *view, Class cls) {
    if (!view || !cls) return nil;

    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:cls]) {
            return subview;
        }

        UIView *nested = SCIRecursiveSubviewOfClass(subview, cls);
        if (nested) return nested;
    }

    return nil;
}

static UIView *SCIAncestorOfClass(UIView *view, Class cls) {
    if (!view || !cls) return nil;

    UIView *ancestor = view.superview;
    while (ancestor) {
        if ([ancestor isKindOfClass:cls]) {
            return ancestor;
        }

        ancestor = ancestor.superview;
    }

    return nil;
}

static UIImage *SCIDownloadButtonGlyph(CGFloat pointSize) {
    UIImage *image = [SCIUtils sci_resourceImageNamed:@"action" template:YES];
    if (image) {
        return image;
    }

    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightMedium];

    if (@available(iOS 17.0, *)) {
        image = [UIImage systemImageNamed:@"option" withConfiguration:configuration];
    }

    if (!image) {
        image = [UIImage systemImageNamed:@"ellipsis.circle" withConfiguration:configuration];
    }

    if (!image) {
        image = [UIImage systemImageNamed:@"arrow.down" withConfiguration:configuration];
    }

    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static BOOL SCIIsDirectVisualMessageContext(UIView *view) {
    UIViewController *controller = [SCIUtils nearestViewControllerForView:view];
    return [controller isKindOfClass:%c(IGDirectVisualMessageViewerController)];
}

static UIButton *SCIDownloadButtonInContainer(UIView *container, NSInteger tag, id target, SEL action, CGFloat pointSize, UIColor *tintColor) {
    UIButton *button = (UIButton *)[container viewWithTag:tag];
    BOOL didCreateButton = NO;
    if (![button isKindOfClass:[UIButton class]]) {
        button = [SCIDownloadMenuButton buttonWithType:UIButtonTypeCustom];
        didCreateButton = YES;
        button.tag = tag;
        button.accessibilityIdentifier = @"com.socuul.scinsta.download-button";
        button.adjustsImageWhenHighlighted = NO;
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        [container addSubview:button];
    }

    UIImage *image = SCIDownloadButtonGlyph(pointSize);

    [button setImage:image forState:UIControlStateNormal];
    [button setTintColor:tintColor];
    button.backgroundColor = UIColor.clearColor;
    button.layer.cornerRadius = 0.0;
    button.layer.shadowOpacity = 0.0;
    button.layer.shadowRadius = 0.0;
    button.layer.shadowOffset = CGSizeZero;
    button.layer.shadowColor = UIColor.clearColor.CGColor;
    button.contentEdgeInsets = UIEdgeInsetsZero;
    button.imageEdgeInsets = UIEdgeInsetsZero;
    SCISetButtonDesiredAlpha(button, 1.0);
    if (didCreateButton && target && action) {
        [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }

    return button;
}

static void SCIApplyShadow(UIView *view, CGFloat opacity, CGFloat radius, CGFloat offsetY) {
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = opacity;
    view.layer.shadowRadius = radius;
    view.layer.shadowOffset = CGSizeMake(0.0, offsetY);
}

static UIView *SCIViewForNamedSelector(id view, NSString *selectorName) {
    id candidate = SCIObjectForSelector(view, selectorName);
    return [candidate isKindOfClass:[UIView class]] ? candidate : nil;
}

static UIEdgeInsets SCIContentInsetsFromView(id view) {
    SEL selector = NSSelectorFromString(@"contentEdgeInsets");
    if (!view || ![view respondsToSelector:selector]) {
        return UIEdgeInsetsZero;
    }

    return ((UIEdgeInsets (*)(id, SEL))objc_msgSend)(view, selector);
}

static UIView *SCIAnyFeedButtonFromView(UIView *view) {
    UIView *saveButton = [SCIUtils getIvarForObj:view name:"_saveButton"];
    if ([saveButton isKindOfClass:[UIView class]] && !saveButton.hidden) {
        return saveButton;
    }

    NSArray<NSString *> *selectors = @[@"sendButton", @"commentButton", @"likeButton", @"saveButton"];

    for (NSString *selectorName in selectors) {
        UIView *button = SCIViewForNamedSelector(view, selectorName);
        if (button && !button.hidden && button.superview) {
            return button;
        }
    }

    for (UIView *subview in view.subviews) {
        if (subview.tag == kSCIDownloadButtonTag || subview.hidden || subview.alpha <= 0.0) continue;

        if ([subview isKindOfClass:[UIControl class]] || [subview isKindOfClass:%c(IGUFIButtonWithCountsView)]) {
            return subview;
        }
    }

    return nil;
}

static CGRect SCIAnyFeedButtonFrameFromView(UIView *view) {
    UIView *referenceButton = SCIAnyFeedButtonFromView(view);
    if (!referenceButton) {
        return CGRectMake(0.0, 0.0, 40.0, 48.0);
    }

    CGRect frame = SCIFrameInContainer(referenceButton, view);
    if (CGRectIsEmpty(frame)) {
        return CGRectMake(0.0, 0.0, 40.0, 48.0);
    }

    return frame;
}

static UIView *SCIFirstRightFeedButton(UIView *view) {
    UIView *visualSearchButton = SCIViewForNamedSelector(view, @"visualSearchButton");
    if (visualSearchButton && !visualSearchButton.hidden && visualSearchButton.superview) {
        return visualSearchButton;
    }

    visualSearchButton = [SCIUtils getIvarForObj:view name:"_visualSearchButton"];
    if ([visualSearchButton isKindOfClass:[UIView class]] && !visualSearchButton.hidden && visualSearchButton.superview) {
        return visualSearchButton;
    }

    UIView *saveButton = SCIViewForNamedSelector(view, @"saveButton");
    if (saveButton && !saveButton.hidden && saveButton.superview) {
        return saveButton;
    }

    saveButton = [SCIUtils getIvarForObj:view name:"_saveButton"];
    if ([saveButton isKindOfClass:[UIView class]] && !saveButton.hidden && saveButton.superview) {
        return saveButton;
    }

    UIView *bestCandidate = nil;
    CGFloat bestX = CGFLOAT_MAX;
    CGFloat rightRegionThreshold = CGRectGetWidth(view.bounds) * 0.7;

    for (UIView *subview in view.subviews) {
        if (subview.tag == kSCIDownloadButtonTag || subview.hidden || subview.alpha <= 0.0) continue;

        CGRect frame = SCIFrameInContainer(subview, view);
        if (CGRectIsEmpty(frame)) continue;

        CGFloat midX = CGRectGetMidX(frame);
        if (midX < rightRegionThreshold) continue;

        if (CGRectGetMinX(frame) < bestX) {
            bestX = CGRectGetMinX(frame);
            bestCandidate = subview;
        }
    }

    return bestCandidate;
}

/// Walks up from `view` to find `IGMedia` — `post` on media cells, `mediaCellFeedItem` on modern/clips reel surfaces, then delegate-style `media`.
static id SCIFeedPostMediaFromAncestors(UIView *view) {
    UIView *walker = view;
    for (NSUInteger depth = 0; depth < 36 && walker; depth++) {
        if ([walker respondsToSelector:@selector(post)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id post = [walker performSelector:@selector(post)];
#pragma clang diagnostic pop
            if (post) return post;
        }

        id post = [SCIUtils getIvarForObj:walker name:"_post"];
        if (!post) {
            post = SCIKVCObject(walker, @"post");
        }
        if (post) return post;

        if ([walker respondsToSelector:@selector(mediaCellFeedItem)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id feedItem = [walker performSelector:@selector(mediaCellFeedItem)];
#pragma clang diagnostic pop
            if (feedItem) {
                id media = SCIObjectForSelector(feedItem, @"media");
                if (!media) {
                    media = [SCIUtils getIvarForObj:feedItem name:"_media"];
                }
                if (media) return media;
            }
        }

        id media = [SCIUtils getIvarForObj:walker name:"_media"];
        if (!media) {
            media = SCIObjectForSelector(walker, @"media");
        }
        if (media) return media;

        walker = walker.superview;
    }

    return nil;
}

static id SCIBaseFeedMediaFromView(id view) {
    id delegate = SCIObjectForSelector(view, @"delegate");
    id owner = SCIObjectForSelector(delegate, @"delegate");
    NSArray *candidates = @[
        owner ?: [NSNull null],
        delegate ?: [NSNull null],
        view ?: [NSNull null]
    ];

    for (id candidate in candidates) {
        if (candidate == [NSNull null]) continue;

        id media = [SCIUtils getIvarForObj:candidate name:"_media"];
        if (media) return media;

        media = SCIObjectForSelector(candidate, @"media");
        if (media) return media;
    }

    if ([view isKindOfClass:[UIView class]]) {
        id postMedia = SCIFeedPostMediaFromAncestors((UIView *)view);
        if (postMedia) return postMedia;
    }

    return nil;
}

static NSInteger SCIPageIndexForFeedView(id view) {
    id delegate = SCIObjectForSelector(view, @"delegate");
    id owner = SCIObjectForSelector(delegate, @"delegate");
    NSArray *candidates = @[
        owner ?: [NSNull null],
        delegate ?: [NSNull null],
        view ?: [NSNull null]
    ];

    for (id candidate in candidates) {
        if (candidate == [NSNull null]) continue;

        id pageCellState = [SCIUtils getIvarForObj:candidate name:"_pageCellState"];
        NSInteger index = SCIIntegerForSelector(pageCellState, @"currentPageIndex", NSNotFound);
        if (index != NSNotFound) {
            return index;
        }

        index = SCIIntegerForSelector(candidate, @"pageControlCurrentPage", NSNotFound);
        if (index != NSNotFound) {
            return index;
        }

        id pageControl = SCIObjectForSelector(candidate, @"pageControl");
        index = SCIIntegerForSelector(pageControl, @"currentPage", NSNotFound);
        if (index != NSNotFound) {
            return index;
        }
    }

    return NSNotFound;
}

static NSArray *SCIItemsFromMedia(id media) {
    if (!media) return nil;

    id items = SCIObjectForSelector(media, @"items");
    if (!items) {
        items = [SCIUtils getIvarForObj:media name:"_items"];
    }

    return [items isKindOfClass:[NSArray class]] ? items : nil;
}

static id SICurrentPageMediaFromFeedView(UIView *view) {
    UIView *ufiCell = SCIAncestorOfClass(view, %c(IGFeedItemUFICell));
    if (!ufiCell) return nil;

    UICollectionView *collectionView = (UICollectionView *)SCIAncestorOfClass(ufiCell, [UICollectionView class]);
    if (!collectionView) return nil;

    UIView *bestCandidateCell = nil;
    CGFloat bestGap = CGFLOAT_MAX;
    CGFloat ufiTop = CGRectGetMinY(ufiCell.frame);

    for (UIView *candidate in collectionView.subviews) {
        if (candidate == ufiCell || candidate.hidden) continue;

        CGFloat candidateBottom = CGRectGetMaxY(candidate.frame);
        CGFloat gap = ufiTop - candidateBottom;
        if (gap < -2.0 || gap > 30.0) continue;

        UIView *pageMediaView = SCIRecursiveSubviewOfClass(candidate, %c(IGPageMediaView));
        if (!pageMediaView) continue;

        if (gap < bestGap) {
            bestGap = gap;
            bestCandidateCell = candidate;
        }
    }

    UIView *pageMediaView = SCIRecursiveSubviewOfClass(bestCandidateCell, %c(IGPageMediaView));
    if (![pageMediaView isKindOfClass:%c(IGPageMediaView)]) return nil;

    return [(IGPageMediaView *)pageMediaView currentMediaItem];
}

static id SCIResolvedFeedMediaFromView(UIView *view) {
    id media = SCIBaseFeedMediaFromView(view);
    NSArray *items = SCIItemsFromMedia(media);
    if (items.count) {
        NSInteger index = SCIPageIndexForFeedView(view);
        if (index == NSNotFound || index < 0 || index >= (NSInteger)items.count) {
            return items.firstObject ?: media;
        }

        return items[index];
    }

    id currentPageMedia = SICurrentPageMediaFromFeedView(view);
    return currentPageMedia ?: media;
}

static id SCIReelMediaFromView(id view) {
    id delegate = SCIObjectForSelector(view, @"delegate");
    if (!delegate) return nil;

    id media = SCIObjectForSelector(delegate, @"media");
    if (media) return media;

    return [SCIUtils getIvarForObj:delegate name:"_media"];
}

static NSInteger SCIReelPageIndexFromView(id view) {
    id pageIndicator = SCIObjectForSelector(view, @"progressPageIndicator");
    if (!pageIndicator) {
        pageIndicator = [SCIUtils getIvarForObj:view name:"_progressPageIndicator"];
    }

    return SCIIntegerForSelector(pageIndicator, @"currentPage", NSNotFound);
}

static id SCIResolvedReelMediaFromView(id view) {
    id media = SCIReelMediaFromView(view);
    NSArray *items = SCIItemsFromMedia(media);
    if (!items.count) return media;

    NSInteger index = SCIReelPageIndexFromView(view);
    if (index == NSNotFound || index < 0 || index >= (NSInteger)items.count) {
        return items.firstObject ?: media;
    }

    return items[index];
}

static id SCIStorySectionControllerFromOverlay(id overlay) {
    UIViewController *viewerController = [SCIUtils nearestViewControllerForView:overlay];
    id sectionController = viewerController ? objc_getAssociatedObject(viewerController, kSCIStorySectionControllerKey) : nil;
    if (sectionController) return sectionController;

    if ([overlay respondsToSelector:@selector(gestureDelegate)]) {
        id gestureDelegate = [(IGStoryFullscreenOverlayView *)overlay gestureDelegate];
        if ([gestureDelegate isKindOfClass:%c(IGStoryFullscreenSectionController)]) {
            return gestureDelegate;
        }
    }

    NSArray<NSString *> *delegateKeys = @[
        @"_mediaOverlayDelegate",
        @"mediaOverlayDelegate",
        @"_retryDelegate",
        @"retryDelegate",
        @"_tappableOverlayDelegate",
        @"tappableOverlayDelegate",
        @"_buttonDelegate",
        @"buttonDelegate"
    ];

    for (NSString *key in delegateKeys) {
        id candidate = SCIKVCObject(overlay, key);
        if ([candidate isKindOfClass:%c(IGStoryFullscreenSectionController)]) {
            return candidate;
        }
    }

    return nil;
}

static id SCIStoryMediaFromOverlay(id overlay) {
    id sectionController = SCIStorySectionControllerFromOverlay(overlay);
    id media = SCIObjectForSelector(sectionController, @"currentStoryItem");
    if (media) return media;

    UIViewController *viewerController = [SCIUtils nearestViewControllerForView:overlay];
    media = SCIObjectForSelector(viewerController, @"currentStoryItem");
    if (media) return media;

    UIViewController *ancestorController = [SCIUtils viewControllerForAncestralView:overlay];
    media = SCIObjectForSelector(ancestorController, @"currentStoryItem");
    if (media) return media;

    return nil;
}

/// Resolves the DM fullscreen viewer VC used for vault metadata (button → superviews often lack a useful `viewDelegate`).
static UIViewController *SCIDirectVisualMessageHostForAnchor(UIView *anchorView) {
    if (!anchorView) {
        return nil;
    }

    UIViewController *pinned = objc_getAssociatedObject(anchorView, kSCIDirectVaultHostControllerKey);
    if (pinned) {
        return pinned;
    }

    UIView *walker = anchorView;
    for (NSUInteger depth = 0; depth < 22 && walker; depth++) {
        UIViewController *vc = [SCIUtils nearestViewControllerForView:walker];
        if (vc) {
            NSString *name = NSStringFromClass(vc.class);
            if ([name containsString:@"VisualMessage"] || [name containsString:@"DirectVisualMessage"]) {
                return vc;
            }
        }
        walker = walker.superview;
    }

    UIViewController *fallback = [SCIUtils nearestViewControllerForView:anchorView];
    if (fallback && [NSStringFromClass(fallback.class) containsString:@"Direct"]) {
        return fallback;
    }
    return nil;
}

static id SCIDirectCurrentMessage(id controller) {
    if (!controller) {
        return nil;
    }

    id msg = SCIObjectForSelector(controller, @"currentMessage");
    if (msg) {
        return msg;
    }

    id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
    if (!dataSource) {
        dataSource = SCIKVCObject(controller, @"dataSource");
    }
    if (!dataSource) {
        return nil;
    }

    id currentMessage = [SCIUtils getIvarForObj:dataSource name:"_currentMessage"];
    if (currentMessage) {
        return currentMessage;
    }

    currentMessage = SCIObjectForSelector(dataSource, @"currentMessage");
    if (currentMessage) {
        return currentMessage;
    }

    currentMessage = [SCIUtils getIvarForObj:dataSource name:"_visibleMessage"];
    if (currentMessage) {
        return currentMessage;
    }

    currentMessage = SCIObjectForSelector(dataSource, @"visibleMessage");
    if (currentMessage) {
        return currentMessage;
    }

    return nil;
}

static id SCIDirectOverlayView(id controller) {
    id viewerContainerView = [SCIUtils getIvarForObj:controller name:"_viewerContainerView"];
    if (!viewerContainerView) return nil;

    return SCIObjectForSelector(viewerContainerView, @"overlayView");
}

static NSString *SCIUsernameStringFromUserLike(id userObj) {
    if (!userObj) {
        return nil;
    }
    id name = SCIKVCObject(userObj, @"username");
    if ([name isKindOfClass:[NSString class]] && [(NSString *)name length] > 0) {
        return (NSString *)name;
    }
    return nil;
}

static id SCICurrentInstagramSessionUser(void) {
    UIApplication *app = [UIApplication sharedApplication];
    id delegate = [app delegate];
    if (!delegate) {
        return nil;
    }
    id session = SCIKVCObject(delegate, @"userSession");
    return SCIKVCObject(session, @"user");
}

static NSString *SCIUsernamePreferringNotSelf(id userObj) {
    NSString *u = SCIUsernameStringFromUserLike(userObj);
    if (!u.length) {
        return nil;
    }
    NSString *me = SCIUsernameStringFromUserLike(SCICurrentInstagramSessionUser());
    if (me.length && [me compare:u options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return nil;
    }
    return u;
}

static NSString *SCIUsernameStringPreferringNotSelf(NSString *candidate) {
    if (!candidate.length) {
        return nil;
    }
    NSString *me = SCIUsernameStringFromUserLike(SCICurrentInstagramSessionUser());
    if (me.length && [me compare:candidate options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return nil;
    }
    return candidate;
}

static NSString *SCIUsernameFromThreadLikeObject(id thread) {
    if (!thread) {
        return nil;
    }

    NSArray<NSString *> *thrKeys = @[
        @"primaryUser", @"peerUser", @"otherUser", @"recipient", @"localRecipient", @"user", @"inviter",
        @"pendingPeer", @"displayedUser", @"threadPartner", @"correspondentUser"
    ];
    for (NSString *key in thrKeys) {
        id u = SCIKVCObject(thread, key);
        NSString *s = SCIUsernamePreferringNotSelf(u);
        if (s.length) {
            return s;
        }
    }

    id users = SCIKVCObject(thread, @"users");
    if ([users isKindOfClass:[NSArray class]]) {
        for (id u in (NSArray *)users) {
            NSString *s = SCIUsernamePreferringNotSelf(u);
            if (s.length) {
                return s;
            }
        }
    }

    id recipients = SCIKVCObject(thread, @"recipients");
    if ([recipients isKindOfClass:[NSArray class]]) {
        for (id r in (NSArray *)recipients) {
            id u = SCIKVCObject(r, @"user") ?: SCIKVCObject(r, @"userSummary") ?: r;
            NSString *s = SCIUsernamePreferringNotSelf(u);
            if (s.length) {
                return s;
            }
        }
    }

    id otherUsers = SCIKVCObject(thread, @"otherUsers") ?: SCIKVCObject(thread, @"secondaryUsers");
    if ([otherUsers isKindOfClass:[NSArray class]]) {
        for (id u in (NSArray *)otherUsers) {
            NSString *s = SCIUsernamePreferringNotSelf(u);
            if (s.length) {
                return s;
            }
        }
    }

    id allUsers = SCIKVCObject(thread, @"allUsers");
    if ([allUsers isKindOfClass:[NSArray class]]) {
        for (id u in (NSArray *)allUsers) {
            NSString *s = SCIUsernamePreferringNotSelf(u);
            if (s.length) {
                return s;
            }
        }
    }

    return nil;
}

static NSString *SCIUsernameFromDirectMessage(id message, UIViewController *viewerVC) {
    if (!message) {
        return nil;
    }

    NSArray<NSString *> *keyPaths = @[
        @"sender.username", @"author.username", @"user.username", @"fromUser.username",
        @"messageSender.username", @"senderUser.username", @"peerUser.username", @"contactUser.username"
    ];
    for (NSString *kp in keyPaths) {
        @try {
            id v = [message valueForKeyPath:kp];
            if (![v isKindOfClass:[NSString class]]) {
                continue;
            }
            NSString *s = SCIUsernameStringPreferringNotSelf((NSString *)v);
            if (s.length) {
                return s;
            }
        } @catch (__unused NSException *e) {
        }
    }

    NSArray<NSString *> *msgUserKeys = @[
        @"sender", @"senderUser", @"author", @"user", @"fromUser", @"peerUser", @"messageSender",
        @"contactUser", @"instagramActor", @"igActor", @"forwardingUser", @"rankedRecipient",
        @"senderUserSession"
    ];
    for (NSString *key in msgUserKeys) {
        id u = SCIKVCObject(message, key);
        NSString *s = SCIUsernamePreferringNotSelf(u);
        if (!s.length && u) {
            s = SCIUsernamePreferringNotSelf(SCIKVCObject(u, @"user"));
        }
        if (s.length) {
            return s;
        }
    }

    id thread = SCIKVCObject(message, @"thread") ?: SCIKVCObject(message, @"conversation") ?: SCIKVCObject(message, @"directThread");
    NSString *fromThread = SCIUsernameFromThreadLikeObject(thread);
    if (fromThread.length) {
        return fromThread;
    }

    if (viewerVC) {
        id vthread = SCIKVCObject(viewerVC, @"thread");
        if (!vthread) {
            vthread = [SCIUtils getIvarForObj:viewerVC name:"_thread"];
        }
        fromThread = SCIUsernameFromThreadLikeObject(vthread);
        if (fromThread.length) {
            return fromThread;
        }

        id dataSource = [SCIUtils getIvarForObj:viewerVC name:"_dataSource"];
        id dsThread = SCIKVCObject(dataSource, @"thread");
        if (!dsThread) {
            dsThread = [SCIUtils getIvarForObj:dataSource name:"_thread"];
        }
        fromThread = SCIUsernameFromThreadLikeObject(dsThread);
        if (fromThread.length) {
            return fromThread;
        }
    }

    return nil;
}

static BOOL SCIDownloadMediaCandidate(id baseMedia, id currentMedia, UIView *anchorView, NSString *failureDescription);

static id SCIVideoFromCandidate(id candidate) {
    if (!candidate) return nil;

    if ([candidate isKindOfClass:%c(IGVideo)]) {
        return candidate;
    }

    return SCIObjectForSelector(candidate, @"video");
}

static id SCIPhotoFromCandidate(id candidate) {
    if (!candidate) return nil;

    if ([candidate isKindOfClass:%c(IGPhoto)]) {
        return candidate;
    }

    return SCIObjectForSelector(candidate, @"photo");
}

static NSURL *SCIVideoURLFromCandidate(id candidate) {
    return [SCIUtils getVideoUrl:SCIVideoFromCandidate(candidate)];
}

static NSURL *SCIPhotoURLFromCandidate(id candidate) {
    return [SCIUtils getPhotoUrl:SCIPhotoFromCandidate(candidate)];
}

static NSString *SCIUsernameFromMediaCandidate(id candidate) {
    if (!candidate) {
        return nil;
    }

    NSMutableArray *roots = [NSMutableArray arrayWithObject:candidate];
    id nestedMedia = SCIKVCObject(candidate, @"media");
    if (nestedMedia && nestedMedia != candidate) {
        [roots addObject:nestedMedia];
    }

    for (id root in roots) {
        for (NSString *key in @[ @"user", @"owner" ]) {
            id userObj = SCIKVCObject(root, key);
            if (!userObj) {
                continue;
            }

            id name = SCIKVCObject(userObj, @"username");
            if ([name isKindOfClass:[NSString class]] && [(NSString *)name length] > 0) {
                return (NSString *)name;
            }
        }
    }

    return nil;
}

static SCIVaultSource SCIVaultSourceFromAnchorView(UIView *view) {
    if (!view) {
        return SCIVaultSourceFeed;
    }

    UIViewController *vc = [SCIUtils nearestViewControllerForView:view];
    NSString *cls = NSStringFromClass(vc.class);

    if ([cls rangeOfString:@"Story"].location != NSNotFound) {
        return SCIVaultSourceStories;
    }
    if ([cls containsString:@"Reel"] || [cls containsString:@"Sundial"] || [cls containsString:@"Clips"]) {
        return SCIVaultSourceReels;
    }
    if ([cls containsString:@"Direct"]) {
        return SCIVaultSourceDMs;
    }
    if ([cls containsString:@"ProfilePicture"] || [cls containsString:@"PicturePreview"] ||
        [cls containsString:@"ProfilePhoto"] || [cls containsString:@"CoinFlip"] ||
        [cls containsString:@"Avatar"]) {
        return SCIVaultSourceProfile;
    }
    if ([cls containsString:@"Profile"] || [cls containsString:@"UserDetail"]) {
        return SCIVaultSourceProfile;
    }

    return SCIVaultSourceFeed;
}

static void SCIApplyVideoMetricsFromCandidate(id candidate, SCIVaultSaveMetadata *meta) {
    if (!meta) {
        return;
    }

    id video = SCIVideoFromCandidate(candidate);
    if (!video) {
        return;
    }

    for (NSString *key in @[ @"duration", @"length", @"videoDuration" ]) {
        id val = SCIKVCObject(video, key);
        if ([val respondsToSelector:@selector(doubleValue)]) {
            double d = [val doubleValue];
            if (d > 0.1) {
                meta.durationSeconds = d;
                break;
            }
        }
    }

    NSNumber *w = SCIKVCObject(video, @"width");
    NSNumber *h = SCIKVCObject(video, @"height");
    if (!w || !h) {
        w = SCIKVCObject(video, @"renderWidth");
        h = SCIKVCObject(video, @"renderHeight");
    }
    if ([w respondsToSelector:@selector(intValue)] && [w intValue] > 0) {
        meta.pixelWidth = (int32_t)[w intValue];
    }
    if ([h respondsToSelector:@selector(intValue)] && [h intValue] > 0) {
        meta.pixelHeight = (int32_t)[h intValue];
    }
}

static void SCIApplyPhotoMetricsFromCandidate(id candidate, SCIVaultSaveMetadata *meta) {
    if (!meta) {
        return;
    }

    id photo = SCIPhotoFromCandidate(candidate);
    if (!photo) {
        return;
    }

    NSNumber *w = SCIKVCObject(photo, @"width");
    NSNumber *h = SCIKVCObject(photo, @"height");
    if ([w respondsToSelector:@selector(intValue)] && [w intValue] > 0) {
        meta.pixelWidth = (int32_t)[w intValue];
    }
    if ([h respondsToSelector:@selector(intValue)] && [h intValue] > 0) {
        meta.pixelHeight = (int32_t)[h intValue];
    }
}

static SCIVaultSaveMetadata *SCIVaultMetadataForMediaCandidate(id baseMedia, id currentMedia, UIView *anchorView) {
    SCIVaultSaveMetadata *meta = [[SCIVaultSaveMetadata alloc] init];
    meta.sourceUsername = SCIUsernameFromMediaCandidate(baseMedia);
    if (!meta.sourceUsername.length) {
        meta.sourceUsername = SCIUsernameFromMediaCandidate(currentMedia);
    }

    UIViewController *dmHost = SCIDirectVisualMessageHostForAnchor(anchorView);
    if (dmHost) {
        meta.source = (int16_t)SCIVaultSourceDMs;
        if (!meta.sourceUsername.length) {
            id dmMessage = SCIDirectCurrentMessage(dmHost);
            NSString *resolved = SCIUsernameFromDirectMessage(dmMessage, dmHost);
            if (resolved.length) {
                meta.sourceUsername = resolved;
            }
        }
    } else {
        meta.source = (int16_t)SCIVaultSourceFromAnchorView(anchorView);
        if (!meta.sourceUsername.length) {
            UIViewController *hostVC = anchorView ? [SCIUtils nearestViewControllerForView:anchorView] : nil;
            NSString *hostName = hostVC ? NSStringFromClass(hostVC.class) : @"";
            if ([hostName containsString:@"Direct"]) {
                id dmMessage = SCIDirectCurrentMessage(hostVC);
                meta.sourceUsername = SCIUsernameFromDirectMessage(dmMessage, hostVC) ?: meta.sourceUsername;
            }
        }
    }

    if (SCIVideoURLFromCandidate(currentMedia)) {
        SCIApplyVideoMetricsFromCandidate(currentMedia, meta);
    } else {
        SCIApplyPhotoMetricsFromCandidate(currentMedia, meta);
    }

    return meta;
}

static NSInteger SCIMediaTypeFromMedia(id media) {
    if (!media) return 0;

    NSArray *items = SCIItemsFromMedia(media);
    if (items.count > 0) return 3;

    if (SCIVideoFromCandidate(media)) return 2;
    if (SCIPhotoFromCandidate(media)) return 1;

    return 0;
}

static NSInteger SCIResolvedItemIndex(NSArray *items, id currentMedia, NSInteger fallbackIndex) {
    if (items.count == 0) {
        return NSNotFound;
    }

    if (fallbackIndex != NSNotFound && fallbackIndex >= 0 && fallbackIndex < (NSInteger)items.count) {
        return fallbackIndex;
    }

    NSUInteger exactMatch = [items indexOfObjectIdenticalTo:currentMedia];
    if (exactMatch != NSNotFound) {
        return (NSInteger)exactMatch;
    }

    NSURL *currentVideoURL = SCIVideoURLFromCandidate(currentMedia);
    NSURL *currentPhotoURL = SCIPhotoURLFromCandidate(currentMedia);

    if (!currentVideoURL && !currentPhotoURL) {
        return 0;
    }

    for (NSUInteger i = 0; i < items.count; i++) {
        id item = items[i];

        NSURL *itemVideoURL = SCIVideoURLFromCandidate(item);
        if (currentVideoURL && [itemVideoURL.absoluteString isEqualToString:currentVideoURL.absoluteString]) {
            return (NSInteger)i;
        }

        NSURL *itemPhotoURL = SCIPhotoURLFromCandidate(item);
        if (currentPhotoURL && [itemPhotoURL.absoluteString isEqualToString:currentPhotoURL.absoluteString]) {
            return (NSInteger)i;
        }
    }

    return 0;
}

static BOOL SCIShareMediaCandidate(id baseMedia, id currentMedia, UIView *anchorView, NSString *failureDescription) {
    SCIInitDownloadButtonDownloaders();

    SCIVaultSaveMetadata *meta = SCIVaultMetadataForMediaCandidate(baseMedia, currentMedia, anchorView);

    NSURL *videoURL = SCIVideoURLFromCandidate(currentMedia);
    if (videoURL) {
        dlBtnShareVideoDelegate.pendingVaultSaveMetadata = meta;
        [dlBtnShareVideoDelegate downloadFileWithURL:videoURL
                                      fileExtension:videoURL.pathExtension
                                           hudLabel:nil];
        return YES;
    }

    NSURL *photoURL = SCIPhotoURLFromCandidate(currentMedia);
    if (photoURL) {
        dlBtnShareImageDelegate.pendingVaultSaveMetadata = meta;
        [dlBtnShareImageDelegate downloadFileWithURL:photoURL
                                      fileExtension:photoURL.pathExtension
                                           hudLabel:nil];
        return YES;
    }

    if (failureDescription.length) {
        [SCIUtils showErrorHUDWithDescription:failureDescription];
    }

    return NO;
}

static BOOL SCICopyMediaLinkForCandidate(id candidate, NSString *failureDescription) {
    NSURL *url = SCIVideoURLFromCandidate(candidate) ?: SCIPhotoURLFromCandidate(candidate);
    if (!url) {
        if (failureDescription.length) {
            [SCIUtils showErrorHUDWithDescription:failureDescription];
        }
        return NO;
    }

    UIPasteboard.generalPasteboard.string = url.absoluteString ?: @"";
    [SCIUtils showToastForDuration:1.5 title:@"Copied link"];
    return YES;
}

static BOOL SCIDownloadToVaultMediaCandidate(id baseMedia, id currentMedia, UIView *anchorView, NSString *failureDescription) {
    SCIInitDownloadButtonDownloaders();

    SCIVaultSaveMetadata *vaultMeta = SCIVaultMetadataForMediaCandidate(baseMedia, currentMedia, anchorView);

    NSURL *videoURL = SCIVideoURLFromCandidate(currentMedia);
    if (videoURL) {
        dlBtnVaultVideoDelegate.pendingVaultSaveMetadata = vaultMeta;
        [dlBtnVaultVideoDelegate downloadFileWithURL:videoURL
                                       fileExtension:videoURL.pathExtension
                                            hudLabel:nil];
        return YES;
    }

    NSURL *photoURL = SCIPhotoURLFromCandidate(currentMedia);
    if (photoURL) {
        dlBtnVaultImageDelegate.pendingVaultSaveMetadata = vaultMeta;
        [dlBtnVaultImageDelegate downloadFileWithURL:photoURL
                                       fileExtension:photoURL.pathExtension
                                            hudLabel:nil];
        return YES;
    }

    if (failureDescription.length) {
        [SCIUtils showErrorHUDWithDescription:failureDescription];
    }

    return NO;
}

static BOOL SCIExpandMediaCandidate(id baseMedia, id currentMedia, NSInteger currentIndex, UIView *anchorView, NSString *failureDescription) {
    SCIVaultSaveMetadata *meta = SCIVaultMetadataForMediaCandidate(baseMedia, currentMedia, anchorView);
    id resolvedCurrent = currentMedia;
    NSArray *items = SCIItemsFromMedia(baseMedia);

    if (items.count > 0) {
        NSInteger itemIndex = SCIResolvedItemIndex(items, currentMedia, currentIndex);
        if (itemIndex != NSNotFound && itemIndex >= 0 && itemIndex < (NSInteger)items.count) {
            resolvedCurrent = items[itemIndex];
        }

        NSMutableArray<SCIMediaItem *> *mediaItems = [NSMutableArray arrayWithCapacity:items.count];
        NSInteger startPagerIndex = NSNotFound;

        for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
            id raw = items[i];
            NSURL *url = SCIVideoURLFromCandidate(raw) ?: SCIPhotoURLFromCandidate(raw);
            if (!url) {
                continue;
            }

            if (itemIndex != NSNotFound && i == itemIndex) {
                startPagerIndex = (NSInteger)mediaItems.count;
            }

            SCIMediaItem *mi = [SCIMediaItem itemWithFileURL:url];
            mi.vaultMetadata = meta;
            [mediaItems addObject:mi];
        }

        if (mediaItems.count > 0) {
            NSInteger adj = startPagerIndex == NSNotFound ? 0 : startPagerIndex;
            adj = MAX(0, MIN(adj, (NSInteger)mediaItems.count - 1));

            if (mediaItems.count == 1) {
                [SCIFullScreenMediaPlayer showFileURL:mediaItems.firstObject.fileURL metadata:meta];
            } else {
                [SCIFullScreenMediaPlayer showMediaItems:mediaItems startingAtIndex:adj metadata:meta];
            }
            return YES;
        }
    }

    NSURL *videoURL = SCIVideoURLFromCandidate(resolvedCurrent);
    if (videoURL) {
        [SCIFullScreenMediaPlayer showFileURL:videoURL metadata:meta];
        return YES;
    }

    NSURL *photoURL = SCIPhotoURLFromCandidate(resolvedCurrent);
    if (photoURL) {
        [SCIFullScreenMediaPlayer showFileURL:photoURL metadata:meta];
        return YES;
    }

    if (failureDescription.length) {
        [SCIUtils showErrorHUDWithDescription:failureDescription];
    }

    return NO;
}

static BOOL SCIImageMostlyBlack(UIImage *image) {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return YES;

    size_t width = 8;
    size_t height = 8;
    size_t bytesPerPixel = 4;
    size_t bytesPerRow = width * bytesPerPixel;
    size_t bitsPerComponent = 8;
    size_t totalPixels = width * height;

    uint8_t *rawData = (uint8_t *)calloc(height, bytesPerRow);
    if (!rawData) return YES;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    CGContextRef context = CGBitmapContextCreate(rawData,
                                                 width,
                                                 height,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 bitmapInfo);

    if (!context) {
        CGColorSpaceRelease(colorSpace);
        free(rawData);
        return YES;
    }

    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), cgImage);

    NSUInteger darkPixels = 0;
    for (size_t i = 0; i < totalPixels; i++) {
        size_t offset = i * bytesPerPixel;
        uint8_t r = rawData[offset];
        uint8_t g = rawData[offset + 1];
        uint8_t b = rawData[offset + 2];

        if (r < 30 && g < 30 && b < 30) {
            darkPixels++;
        }
    }

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(rawData);

    return ((double)darkPixels / (double)totalPixels) > 0.85;
}

static void SCIExtractVideoThumbnailAndShow(NSURL *videoURL) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *assetOptions = @{ AVURLAssetPreferPreciseDurationAndTimingKey: @YES };
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:assetOptions];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.requestedTimeToleranceBefore = kCMTimeZero;
        generator.requestedTimeToleranceAfter = CMTimeMakeWithSeconds(0.5, 600);

        NSArray<NSValue *> *sampleTimes = @[
            [NSValue valueWithCMTime:CMTimeMakeWithSeconds(0.5, 600)],
            [NSValue valueWithCMTime:CMTimeMakeWithSeconds(1.0, 600)],
            [NSValue valueWithCMTime:CMTimeMakeWithSeconds(2.0, 600)],
            [NSValue valueWithCMTime:CMTimeMakeWithSeconds(0.0, 600)]
        ];

        UIImage *fallbackImage = nil;
        UIImage *selectedImage = nil;

        for (NSValue *timeValue in sampleTimes) {
            NSError *frameError = nil;
            CGImageRef frameRef = [generator copyCGImageAtTime:timeValue.CMTimeValue actualTime:NULL error:&frameError];
            if (!frameRef || frameError) {
                if (frameRef) {
                    CGImageRelease(frameRef);
                }
                continue;
            }

            UIImage *frameImage = [UIImage imageWithCGImage:frameRef];
            CGImageRelease(frameRef);

            if (!frameImage) {
                continue;
            }

            if (!fallbackImage) {
                fallbackImage = frameImage;
            }

            if (!SCIImageMostlyBlack(frameImage)) {
                selectedImage = frameImage;
                break;
            }
        }

        UIImage *finalImage = selectedImage ?: fallbackImage;
        if (!finalImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SCIUtils showToastForDuration:1.5 title:@"Cover not available"];
            });
            return;
        }

        NSData *jpegData = UIImageJPEGRepresentation(finalImage, 0.9);
        NSString *tempFilename = [NSString stringWithFormat:@"scinsta-cover-%@.jpg", NSUUID.UUID.UUIDString];
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFilename];
        NSURL *tempURL = nil;
        if (jpegData.length > 0 && [jpegData writeToFile:tempPath atomically:YES]) {
            tempURL = [NSURL fileURLWithPath:tempPath];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (tempURL) {
                [SCIFullScreenMediaPlayer showFileURL:tempURL metadata:nil];
            } else {
                [SCIFullScreenMediaPlayer showImage:finalImage];
            }
        });
    });
}

static NSInteger SCICoverSafeIndex(NSInteger index, NSInteger count) {
    if (count <= 0) return NSNotFound;

    NSInteger safeIndex = index;
    if (safeIndex == NSNotFound || safeIndex < 0) {
        safeIndex = 0;
    }
    if (safeIndex >= count) {
        safeIndex = count - 1;
    }

    return safeIndex;
}

static id SCIResolveMediaForExpandCoverFromMedia(id media, NSInteger currentIndex) {
    NSInteger mediaType = SCIMediaTypeFromMedia(media);

    if (mediaType == 3) {
        NSArray *items = SCIItemsFromMedia(media);
        NSInteger safeIndex = SCICoverSafeIndex(currentIndex, (NSInteger)items.count);
        if (safeIndex == NSNotFound) return nil;

        id item = items[safeIndex];
        return SCIMediaTypeFromMedia(item) == 2 ? item : nil;
    }

    if (mediaType == 2) {
        return media;
    }

    return nil;
}

static BOOL SCIMediaHasVideoContent(id baseMedia, id currentMedia, NSInteger currentIndex) {
    id media = baseMedia ?: currentMedia;
    return SCIResolveMediaForExpandCoverFromMedia(media, currentIndex) != nil;
}

static BOOL SCIExpandCoverMediaCandidate(id baseMedia, id currentMedia, NSInteger currentIndex, UIView *anchorView, NSString *failureDescription) {
    SCIVaultSaveMetadata *meta = SCIVaultMetadataForMediaCandidate(baseMedia, currentMedia, anchorView);
    id media = baseMedia ?: currentMedia;
    id coverMedia = SCIResolveMediaForExpandCoverFromMedia(media, currentIndex);
    if (!coverMedia) {
        [SCIUtils showToastForDuration:1.5 title:@"Cover not available"];
        return NO;
    }

    id coverPhoto = SCIPhotoFromCandidate(coverMedia);
    if (coverPhoto) {
        NSURL *photoURL = [SCIUtils getPhotoUrl:coverPhoto];
        if (photoURL) {
            [SCIFullScreenMediaPlayer showFileURL:photoURL metadata:meta];
            return YES;
        }
    }

    NSURL *videoURL = SCIVideoURLFromCandidate(coverMedia);
    if (videoURL) {
        SCIExtractVideoThumbnailAndShow(videoURL);
        return YES;
    }

    [SCIUtils showToastForDuration:1.5 title:@"Cover not available"];
    return NO;
}

static void SCIPresentMediaActionSheet(UIButton *sender, id baseMedia, id currentMedia, NSInteger currentIndex, NSString *failureDescription) {
    if (!currentMedia) {
        if (failureDescription.length) {
            [SCIUtils showErrorHUDWithDescription:failureDescription];
        }
        return;
    }

    UIViewController *presenter = [SCIUtils nearestViewControllerForView:sender];
    if (!presenter) {
        presenter = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (presenter.presentedViewController) {
            presenter = presenter.presentedViewController;
        }
    }
    if (!presenter) {
        return;
    }

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Download"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(__unused UIAlertAction *action) {
        SCIDownloadMediaCandidate(baseMedia, currentMedia, sender, failureDescription);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Share"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(__unused UIAlertAction *action) {
        SCIShareMediaCandidate(baseMedia, currentMedia, sender, failureDescription);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Copy Link"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(__unused UIAlertAction *action) {
        SCICopyMediaLinkForCandidate(currentMedia, failureDescription);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Download to Vault"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(__unused UIAlertAction *action) {
        SCIDownloadToVaultMediaCandidate(baseMedia, currentMedia, sender, failureDescription);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Expand"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(__unused UIAlertAction *action) {
        SCIExpandMediaCandidate(baseMedia ?: currentMedia, currentMedia, currentIndex, sender, failureDescription);
    }]];

    if ([SCIUtils getBoolPref:@"expand_cover"] && SCIMediaHasVideoContent(baseMedia ?: currentMedia, currentMedia, currentIndex)) {
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Expand Cover"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(__unused UIAlertAction *action) {
            SCIExpandCoverMediaCandidate(baseMedia ?: currentMedia, currentMedia, currentIndex, sender, failureDescription);
        }]];
    }

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];

    UIPopoverPresentationController *popover = actionSheet.popoverPresentationController;
    if (popover && sender) {
        popover.sourceView = sender;
        popover.sourceRect = sender.bounds;
    }

    [presenter presentViewController:actionSheet animated:YES completion:nil];
}

static void SCIConfigureButtonContextMenu(UIButton *button,
                                          SCIResolveObjectBlock baseMediaBlock,
                                          SCIResolveObjectBlock currentMediaBlock,
                                          SCIResolveIndexBlock currentIndexBlock,
                                          NSString *failureDescription) {
    if (!button) {
        return;
    }

    if (button.menu && button.showsMenuAsPrimaryAction) {
        return;
    }

    NSString *failureCopy = [failureDescription copy] ?: @"";

    UIImage *downloadIcon = [SCIUtils sci_resourceImageNamed:@"download" template:YES] ?: [UIImage systemImageNamed:@"arrow.down"];
    UIImage *shareIcon = [SCIUtils sci_resourceImageNamed:@"share" template:YES] ?: [UIImage systemImageNamed:@"square.and.arrow.up"];
    UIImage *copyIcon = [SCIUtils sci_resourceImageNamed:@"link" template:YES] ?: [UIImage systemImageNamed:@"link"];
    UIImage *vaultIcon = [SCIUtils sci_resourceImageNamed:@"photo_gallery" template:YES] ?: [UIImage systemImageNamed:@"tray.full"];
    UIImage *expandIcon = [SCIUtils sci_resourceImageNamed:@"fullscreen" template:YES] ?: [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"];

    UIAction *downloadAction = [UIAction actionWithTitle:@"Download" image:downloadIcon identifier:nil handler:^(__unused UIAction *action) {
        id current = currentMediaBlock ? currentMediaBlock() : nil;
        id base = baseMediaBlock ? baseMediaBlock() : current;
        SCIDownloadMediaCandidate(base, current, button, failureCopy);
    }];

    UIAction *shareAction = [UIAction actionWithTitle:@"Share" image:shareIcon identifier:nil handler:^(__unused UIAction *action) {
        id current = currentMediaBlock ? currentMediaBlock() : nil;
        id base = baseMediaBlock ? baseMediaBlock() : current;
        SCIShareMediaCandidate(base, current, button, failureCopy);
    }];

    UIAction *copyAction = [UIAction actionWithTitle:@"Copy Link" image:copyIcon identifier:nil handler:^(__unused UIAction *action) {
        id current = currentMediaBlock ? currentMediaBlock() : nil;
        SCICopyMediaLinkForCandidate(current, failureCopy);
    }];

    UIAction *vaultAction = [UIAction actionWithTitle:@"Download to Vault" image:vaultIcon identifier:nil handler:^(__unused UIAction *action) {
        id current = currentMediaBlock ? currentMediaBlock() : nil;
        id base = baseMediaBlock ? baseMediaBlock() : current;
        SCIDownloadToVaultMediaCandidate(base, current, button, failureCopy);
    }];

    UIAction *expandAction = [UIAction actionWithTitle:@"Expand" image:expandIcon identifier:nil handler:^(__unused UIAction *action) {
        id current = currentMediaBlock ? currentMediaBlock() : nil;
        id base = baseMediaBlock ? baseMediaBlock() : current;
        NSInteger index = currentIndexBlock ? currentIndexBlock() : 0;
        SCIExpandMediaCandidate(base ?: current, current, index, button, failureCopy);
    }];

    NSMutableArray *menuChildren = [NSMutableArray arrayWithArray:@[downloadAction, shareAction, copyAction, vaultAction, expandAction]];

    if ([SCIUtils getBoolPref:@"expand_cover"]) {
        id currentCheck = currentMediaBlock ? currentMediaBlock() : nil;
        id baseCheck = baseMediaBlock ? baseMediaBlock() : currentCheck;
        NSInteger indexCheck = currentIndexBlock ? currentIndexBlock() : NSNotFound;
        if (SCIMediaHasVideoContent(baseCheck ?: currentCheck, currentCheck, indexCheck)) {
            UIImage *coverIcon = [SCIUtils sci_resourceImageNamed:@"photo_filled" template:YES] ?: [UIImage systemImageNamed:@"photo"];
            UIAction *expandCoverAction = [UIAction actionWithTitle:@"Expand Cover" image:coverIcon identifier:nil handler:^(__unused UIAction *action) {
                if (currentMediaBlock) {
                    id current = currentMediaBlock() ?: nil;
                    id base = baseMediaBlock ? baseMediaBlock() : current;
                    NSInteger index = currentIndexBlock ? currentIndexBlock() : 0;
                    SCIExpandCoverMediaCandidate(base ?: current, current, index, button, failureCopy);
                }
            }];
            [menuChildren addObject:expandCoverAction];
        }
    }

    [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [button removeTarget:nil action:NULL forControlEvents:UIControlEventPrimaryActionTriggered];
    [button removeTarget:nil action:NULL forControlEvents:UIControlEventMenuActionTriggered];
    if ([button respondsToSelector:@selector(sci_menuActionTriggered:)]) {
        [button addTarget:button action:@selector(sci_menuActionTriggered:) forControlEvents:UIControlEventMenuActionTriggered];
    }

    button.menu = [UIMenu menuWithChildren:menuChildren];
    button.showsMenuAsPrimaryAction = YES;
    SCISetButtonDesiredAlpha(button, button.alpha);
}

static id SCIResolvedDirectMediaCandidate(id message) {
    if (!message) return nil;

    id rawVideo = SCIObjectForSelector(message, @"rawVideo") ?: [SCIUtils getIvarForObj:message name:"_rawVideo"];
    if ([SCIUtils getVideoUrl:rawVideo]) {
        return rawVideo;
    }

    id rawPhoto = SCIObjectForSelector(message, @"rawPhoto") ?: [SCIUtils getIvarForObj:message name:"_rawPhoto"];
    if ([SCIUtils getPhotoUrl:rawPhoto]) {
        return rawPhoto;
    }

    id media = SCIObjectForSelector(message, @"media");
    if (SCIVideoURLFromCandidate(media) || SCIPhotoURLFromCandidate(media)) {
        return media;
    }

    id visualMessage = SCIObjectForSelector(message, @"visualMessage");
    if (SCIVideoURLFromCandidate(visualMessage) || SCIPhotoURLFromCandidate(visualMessage)) {
        return visualMessage;
    }

    if (SCIVideoURLFromCandidate(message) || SCIPhotoURLFromCandidate(message)) {
        return message;
    }

    return nil;
}

static BOOL SCIDownloadMediaCandidate(id baseMedia, id currentMedia, UIView *anchorView, NSString *failureDescription) {
    SCIInitDownloadButtonDownloaders();

    SCIVaultSaveMetadata *meta = SCIVaultMetadataForMediaCandidate(baseMedia, currentMedia, anchorView);

    id video = nil;
    id photo = nil;

    if ([currentMedia isKindOfClass:%c(IGVideo)]) {
        video = currentMedia;
    } else if ([currentMedia isKindOfClass:%c(IGPhoto)]) {
        photo = currentMedia;
    } else {
        video = SCIObjectForSelector(currentMedia, @"video");
        photo = SCIObjectForSelector(currentMedia, @"photo");
    }

    NSURL *videoURL = [SCIUtils getVideoUrl:video];
    if (videoURL) {
        dlBtnVideoDelegate.pendingVaultSaveMetadata = meta;
        [dlBtnVideoDelegate downloadFileWithURL:videoURL
                                  fileExtension:videoURL.pathExtension
                                       hudLabel:nil];
        return YES;
    }

    NSURL *photoURL = [SCIUtils getPhotoUrl:photo];
    if (photoURL) {
        dlBtnImageDelegate.pendingVaultSaveMetadata = meta;
        [dlBtnImageDelegate downloadFileWithURL:photoURL
                                 fileExtension:photoURL.pathExtension
                                      hudLabel:nil];
        return YES;
    }

    if (failureDescription.length) {
        [SCIUtils showErrorHUDWithDescription:failureDescription];
    }

    return NO;
}

static BOOL SCIDownloadDirectMessage(id message) {
    SCIInitDownloadButtonDownloaders();

    SCIVaultSaveMetadata *meta = SCIVaultMetadataForMediaCandidate(message, message, nil);

    id rawVideo = SCIObjectForSelector(message, @"rawVideo") ?: [SCIUtils getIvarForObj:message name:"_rawVideo"];
    NSURL *videoURL = [SCIUtils getVideoUrl:rawVideo];
    if (videoURL) {
        dlBtnVideoDelegate.pendingVaultSaveMetadata = meta;
        [dlBtnVideoDelegate downloadFileWithURL:videoURL
                                 fileExtension:videoURL.pathExtension
                                      hudLabel:nil];
        return YES;
    }

    id rawPhoto = SCIObjectForSelector(message, @"rawPhoto") ?: [SCIUtils getIvarForObj:message name:"_rawPhoto"];
    NSURL *photoURL = [SCIUtils getPhotoUrl:rawPhoto];
    if (photoURL) {
        dlBtnImageDelegate.pendingVaultSaveMetadata = meta;
        [dlBtnImageDelegate downloadFileWithURL:photoURL
                                 fileExtension:photoURL.pathExtension
                                      hudLabel:nil];
        return YES;
    }

    if (SCIDownloadMediaCandidate(message, message, nil, nil)) {
        return YES;
    }

    id media = SCIObjectForSelector(message, @"media");
    if (SCIDownloadMediaCandidate(media, media, nil, nil)) {
        return YES;
    }

    id visualMessage = SCIObjectForSelector(message, @"visualMessage");
    if (SCIDownloadMediaCandidate(visualMessage, visualMessage, nil, nil)) {
        return YES;
    }

    [SCIUtils showErrorHUDWithDescription:@"Could not extract media from visual message"];
    return NO;
}

static void SCIUpdateFeedDownloadButton(UIView *view, id target, SEL action) {
    UIButton *existingButton = (UIButton *)[view viewWithTag:kSCIDownloadButtonTag];
    if (![SCIUtils getBoolPref:@"show_download_button"]) {
        [existingButton removeFromSuperview];
        return;
    }

    UIButton *button = SCIDownloadButtonInContainer(view, kSCIDownloadButtonTag, target, action, 18.0, UIColor.labelColor);

    CGRect referenceFrame = SCIAnyFeedButtonFrameFromView(view);
    UIView *firstRightButton = SCIFirstRightFeedButton(view);
    CGRect rightFrame = SCIFrameInContainer(firstRightButton, view);

    CGFloat width = CGRectGetWidth(referenceFrame) > 0.0 ? CGRectGetWidth(referenceFrame) : 40.0;
    if (!CGRectIsEmpty(rightFrame) && CGRectGetWidth(rightFrame) > 0.0) {
        width = CGRectGetWidth(rightFrame);
    }

    CGFloat height = CGRectGetHeight(referenceFrame) > 0.0 ? CGRectGetHeight(referenceFrame) : 48.0;
    if (!CGRectIsEmpty(rightFrame) && CGRectGetHeight(rightFrame) > 0.0) {
        height = CGRectGetHeight(rightFrame);
    }

    CGFloat anchorX = CGRectGetWidth(view.bounds);
    if (!CGRectIsEmpty(rightFrame)) {
        anchorX = CGRectGetMinX(rightFrame);
    }

    button.contentEdgeInsets = SCIContentInsetsFromView(firstRightButton);
    button.frame = CGRectIntegral(CGRectMake(anchorX - width, CGRectGetMinY(referenceFrame), width, height));
    SCISetButtonDesiredAlpha(button, 1.0);
    SCIAllowContextMenuOverflow(button);

    __weak UIView *weakView = view;
    SCIConfigureButtonContextMenu(button,
                                  ^id{
        return SCIBaseFeedMediaFromView(weakView);
    },
                                  ^id{
        return SCIResolvedFeedMediaFromView(weakView);
    },
                                  ^NSInteger{
        return SCIPageIndexForFeedView(weakView);
    },
                                  @"Could not extract media from post");

    [view bringSubviewToFront:button];
}

static void SCIUpdateReelDownloadButton(UIView *view, id target, SEL action) {
    UIButton *existingButton = (UIButton *)[view viewWithTag:kSCIDownloadButtonTag];
    if (![SCIUtils getBoolPref:@"show_download_button"]) {
        [existingButton removeFromSuperview];
        return;
    }

    UIButton *button = SCIDownloadButtonInContainer(view, kSCIDownloadButtonTag, target, action, 19.0, UIColor.whiteColor);
    CGFloat side = 38.0;
    button.frame = CGRectIntegral(CGRectMake((CGRectGetWidth(view.bounds) - side) / 2.0, -(side + 5.0), side, side));
    SCISetButtonDesiredAlpha(button, 1.0);
    SCIAllowContextMenuOverflow(button);

    __weak UIView *weakView = view;
    SCIConfigureButtonContextMenu(button,
                                  ^id{
        return SCIReelMediaFromView(weakView);
    },
                                  ^id{
        return SCIResolvedReelMediaFromView(weakView);
    },
                                  ^NSInteger{
        return SCIReelPageIndexFromView(weakView);
    },
                                  @"Could not extract media from reel");

    [view bringSubviewToFront:button];
}

static void SCIUpdateStoryDownloadButton(UIView *overlay, id target, SEL action) {
    UIButton *existingButton = (UIButton *)[overlay viewWithTag:kSCIDownloadButtonTag];
    if (![SCIUtils getBoolPref:@"show_download_button"]) {
        [existingButton removeFromSuperview];
        return;
    }

    if (SCIIsDirectVisualMessageContext(overlay)) {
        [existingButton removeFromSuperview];
        return;
    }

    UIButton *button = SCIDownloadButtonInContainer(overlay, kSCIDownloadButtonTag, target, action, 19.0, UIColor.whiteColor);

    UIView *mediaView = [SCIUtils getIvarForObj:overlay name:"_mediaView"];
    UIView *footerView = [SCIUtils getIvarForObj:overlay name:"_footerContainerView"];
    UIView *hypeView = [SCIUtils getIvarForObj:overlay name:"_hypeFaceswarmView"];
    BOOL showCommentsPreview = SCIKVCBool(overlay, @"_showCommentsPreview", NO) || SCIKVCBool(overlay, @"showCommentsPreview", NO);

    CGFloat side = 38.0;
    CGFloat x = CGRectGetWidth(overlay.bounds) - side - 7.0;
    CGFloat y = 7.0;

    if (mediaView) {
        y = CGRectGetMaxY(mediaView.frame) - side - 7.0;

        if (footerView && CGRectGetMinY(footerView.frame) < CGRectGetMaxY(mediaView.frame)) {
            y -= 50.0;
        }
    } else if (footerView) {
        y = CGRectGetMinY(footerView.frame) - side - 12.0;
    }

    if (showCommentsPreview) {
        CGFloat buttonBottom = y + side;

        if (hypeView && CGRectGetMinY(hypeView.frame) < buttonBottom) {
            y = CGRectGetMinY(hypeView.frame) - side - 2.0;
        } else {
            y -= 35.0;
        }
    }

    button.frame = CGRectIntegral(CGRectMake(x, MAX(7.0, y), side, side));
    SCISetButtonDesiredAlpha(button, footerView ? footerView.alpha : 1.0);
    SCIAllowContextMenuOverflow(button);

    __weak UIView *weakOverlay = overlay;
    SCIConfigureButtonContextMenu(button,
                                  ^id{
        return SCIStoryMediaFromOverlay(weakOverlay);
    },
                                  ^id{
        return SCIStoryMediaFromOverlay(weakOverlay);
    },
                                  ^NSInteger{
        return NSNotFound;
    },
                                  @"Could not extract media from story");

    [overlay bringSubviewToFront:button];
}

static void SCIUpdateDirectDownloadButton(UIViewController *controller, id target, SEL action) {
    UIView *overlayView = SCIDirectOverlayView(controller);
    UIButton *existingButton = (UIButton *)[overlayView viewWithTag:kSCIDirectDownloadButtonTag];
    if (![SCIUtils getBoolPref:@"show_download_button"]) {
        [existingButton removeFromSuperview];
        return;
    }

    if (!overlayView) return;

    UIButton *button = SCIDownloadButtonInContainer(overlayView, kSCIDirectDownloadButtonTag, target, action, 19.0, UIColor.whiteColor);

    UIView *inputView = [SCIUtils getIvarForObj:controller name:"_inputView"];
    CGFloat bottomInset = controller.view.safeAreaInsets.bottom + 12.0 + CGRectGetHeight(inputView.frame);
    CGFloat side = 44.0;
    CGFloat x = CGRectGetWidth(overlayView.bounds) - side - 10.0;
    CGFloat y = CGRectGetHeight(overlayView.bounds) - bottomInset - side;

    button.frame = CGRectIntegral(CGRectMake(x, MAX(10.0, y), side, side));
    SCISetButtonDesiredAlpha(button, 1.0);
    SCIAllowContextMenuOverflow(button);
    objc_setAssociatedObject(button, kSCIDirectVaultHostControllerKey, controller, OBJC_ASSOCIATION_ASSIGN);

    __weak UIViewController *weakController = controller;
    SCIConfigureButtonContextMenu(button,
                                  ^id{
        id message = SCIDirectCurrentMessage(weakController);
        return SCIResolvedDirectMediaCandidate(message);
    },
                                  ^id{
        id message = SCIDirectCurrentMessage(weakController);
        return SCIResolvedDirectMediaCandidate(message);
    },
                                  ^NSInteger{
        return NSNotFound;
    },
                                  @"Could not extract media from visual message");

    [overlayView bringSubviewToFront:button];
}

static void SCIHandleSocialUFIDownloadTap(id self, SEL _cmd, UIButton *sender) {
    id baseMedia = SCIBaseFeedMediaFromView((UIView *)self);
    id media = SCIResolvedFeedMediaFromView((UIView *)self);
    NSInteger index = SCIPageIndexForFeedView((UIView *)self);
    SCIPresentMediaActionSheet(sender, baseMedia, media, index, @"Could not extract media from post");
}

static void SCIHookedSocialUFILayoutSubviews(id self, SEL _cmd) {
    orig_socialUFI_layoutSubviews(self, _cmd);
    SCIUpdateFeedDownloadButton((UIView *)self, self, @selector(sciDownloadButtonTapped:));
}

#pragma mark - Long Press to Expand (Feed)

static NSInteger const kSCIExpandGestureTag = 8315932;

static void SCIAddExpandLongPressIfNeeded(UIView *view, SEL action) {
    for (UIGestureRecognizer *gr in view.gestureRecognizers) {
        if ([gr isKindOfClass:[UILongPressGestureRecognizer class]] && gr.view.tag == kSCIExpandGestureTag) {
            return;
        }
    }

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:view action:action];
    longPress.minimumPressDuration = 0.3;
    view.tag = kSCIExpandGestureTag;
    [view addGestureRecognizer:longPress];
}

static void SCIHandleFeedExpandLongPress(UIView *view, UILongPressGestureRecognizer *sender) {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    id baseMedia = SCIBaseFeedMediaFromView(view);
    id currentMedia = SCIResolvedFeedMediaFromView(view);
    NSInteger index = SCIPageIndexForFeedView(view);

    if (!currentMedia && !baseMedia) {
        return;
    }

    SCIExpandMediaCandidate(baseMedia ?: currentMedia, currentMedia ?: baseMedia, index, view, nil);
}

%hook IGFeedPhotoView
- (void)didMoveToSuperview {
    %orig;

    SCIAddExpandLongPressIfNeeded(self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
    SCIHandleFeedExpandLongPress(self, sender);
}
%end

%hook IGFeedItemVideoView
- (void)didMoveToSuperview {
    %orig;

    SCIAddExpandLongPressIfNeeded(self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
    SCIHandleFeedExpandLongPress(self, sender);
}
%end

%hook IGFeedItemMediaCell
- (void)didMoveToSuperview {
    %orig;

    SCIAddExpandLongPressIfNeeded(self, @selector(sci_mediaCell_handleExpandLongPress:));
}

- (void)layoutSubviews {
    %orig;

    SCIAddExpandLongPressIfNeeded(self, @selector(sci_mediaCell_handleExpandLongPress:));
}

%new - (void)sci_mediaCell_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
    SCIHandleFeedExpandLongPress(self, sender);
}
%end

%hook IGModernFeedVideoCell
- (void)didMoveToSuperview {
    %orig;

    SCIAddExpandLongPressIfNeeded(self, @selector(sci_handleExpandLongPress:));
}

- (void)layoutSubviews {
    %orig;

    SCIAddExpandLongPressIfNeeded(self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
    SCIHandleFeedExpandLongPress(self, sender);
}
%end

%hook IGPageMediaView
- (void)didMoveToSuperview {
    %orig;

    SCIAddExpandLongPressIfNeeded(self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
    SCIHandleFeedExpandLongPress(self, sender);
}
%end

%hook IGUFIButtonBarView
- (void)layoutSubviews {
    %orig;

    SCIUpdateFeedDownloadButton((UIView *)self, self, @selector(sciDownloadButtonTapped:));
}

%new - (void)sciDownloadButtonTapped:(UIButton *)sender {
    id baseMedia = SCIBaseFeedMediaFromView((UIView *)self);
    id media = SCIResolvedFeedMediaFromView((UIView *)self);
    NSInteger index = SCIPageIndexForFeedView((UIView *)self);
    SCIPresentMediaActionSheet(sender, baseMedia, media, index, @"Could not extract media from post");
}
%end

%hook IGUFIInteractionCountsView
- (void)layoutSubviews {
    %orig;

    SCIUpdateFeedDownloadButton((UIView *)self, self, @selector(sciDownloadButtonTapped:));
}

%new - (void)sciDownloadButtonTapped:(UIButton *)sender {
    id baseMedia = SCIBaseFeedMediaFromView((UIView *)self);
    id media = SCIResolvedFeedMediaFromView((UIView *)self);
    NSInteger index = SCIPageIndexForFeedView((UIView *)self);
    SCIPresentMediaActionSheet(sender, baseMedia, media, index, @"Could not extract media from post");
}
%end

%hook IGSundialViewerVerticalUFI
- (void)layoutSubviews {
    %orig;

    SCIUpdateReelDownloadButton((UIView *)self, self, @selector(sciDownloadButtonTapped:));
}

%new - (void)sciDownloadButtonTapped:(UIButton *)sender {
    id baseMedia = SCIReelMediaFromView(self);
    id media = SCIResolvedReelMediaFromView(self);
    NSInteger index = SCIReelPageIndexFromView(self);
    SCIPresentMediaActionSheet(sender, baseMedia, media, index, @"Could not extract media from reel");
}
%end

%hook IGStoryViewerViewController
- (void)fullscreenSectionController:(id)sectionController willDisplayFullscreenCell:(id)cell {
    objc_setAssociatedObject(self, kSCIStorySectionControllerKey, sectionController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig;
}

- (void)fullscreenSectionController:(id)sectionController didDisplayStoryModel:(id)storyModel {
    objc_setAssociatedObject(self, kSCIStorySectionControllerKey, sectionController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig;
}
%end

%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
    %orig;

    SCIUpdateStoryDownloadButton((UIView *)self, self, @selector(sciDownloadButtonTapped:));
}

%new - (void)sciDownloadButtonTapped:(UIButton *)sender {
    id baseMedia = SCIStoryMediaFromOverlay(self);
    id media = SCIStoryMediaFromOverlay(self);
    SCIPresentMediaActionSheet(sender, baseMedia, media, NSNotFound, @"Could not extract media from story");
}
%end

%hook IGDirectVisualMessageViewerController
- (void)viewDidAppear:(BOOL)animated {
    %orig;

    SCIUpdateDirectDownloadButton(self, self, @selector(sciDownloadButtonTapped:));
}

- (void)viewDidLayoutSubviews {
    %orig;

    SCIUpdateDirectDownloadButton(self, self, @selector(sciDownloadButtonTapped:));
}

%new - (void)sciDownloadButtonTapped:(UIButton *)sender {
    id message = SCIDirectCurrentMessage(self);
    if (!message) {
        [SCIUtils showErrorHUDWithDescription:@"Could not extract media from visual message"];
        return;
    }

    id media = SCIResolvedDirectMediaCandidate(message);
    SCIPresentMediaActionSheet(sender, media, media, NSNotFound, @"Could not extract media from visual message");
}
%end

static void SCIExpandFeedLongPressAction(id self, SEL _cmd, UILongPressGestureRecognizer *sender) {
    SCIHandleFeedExpandLongPress((UIView *)self, sender);
}

static void (*orig_swiftModernFeedVideo_didMove)(id, SEL);
static void (*orig_swiftModernFeedVideo_layout)(id, SEL);

static void SCIHookSwiftModernFeedVideoDidMove(id self, SEL _cmd) {
    if (orig_swiftModernFeedVideo_didMove) {
        orig_swiftModernFeedVideo_didMove(self, _cmd);
    }

    SCIAddExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

static void SCIHookSwiftModernFeedVideoLayout(id self, SEL _cmd) {
    if (orig_swiftModernFeedVideo_layout) {
        orig_swiftModernFeedVideo_layout(self, _cmd);
    }

    SCIAddExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%ctor {
    Class socialUFIClass = objc_getClass("IGSocialUFIView.IGSocialUFIView");
    if (socialUFIClass) {
        class_addMethod(socialUFIClass, @selector(sciDownloadButtonTapped:), (IMP)SCIHandleSocialUFIDownloadTap, "v@:@");
        MSHookMessageEx(socialUFIClass, @selector(layoutSubviews), (IMP)SCIHookedSocialUFILayoutSubviews, (IMP *)&orig_socialUFI_layoutSubviews);
    }

    Class modernObjCName = objc_getClass("IGModernFeedVideoCell");
    Class modernSwiftRuntime = objc_getClass("IGModernFeedVideoCell.IGModernFeedVideoCell");
    if (modernSwiftRuntime && modernSwiftRuntime != modernObjCName) {
        class_addMethod(modernSwiftRuntime, @selector(sci_handleExpandLongPress:), (IMP)SCIExpandFeedLongPressAction, "v@:@");
        MSHookMessageEx(modernSwiftRuntime, @selector(didMoveToSuperview), (IMP)SCIHookSwiftModernFeedVideoDidMove, (IMP *)&orig_swiftModernFeedVideo_didMove);
        MSHookMessageEx(modernSwiftRuntime, @selector(layoutSubviews), (IMP)SCIHookSwiftModernFeedVideoLayout, (IMP *)&orig_swiftModernFeedVideo_layout);
    }
}
