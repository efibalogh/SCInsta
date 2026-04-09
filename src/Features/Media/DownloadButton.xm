#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Downloader/Download.h"

@interface IGUFIButtonBarView : UIView
@end

@interface IGStoryViewerViewController : UIViewController
@end

static SCIDownloadDelegate *dlBtnImageDelegate;
static SCIDownloadDelegate *dlBtnVideoDelegate;

static NSInteger const kSCIDownloadButtonTag = 8315931;
static NSInteger const kSCIDirectDownloadButtonTag = 13123;
static void *kSCIStorySectionControllerKey = &kSCIStorySectionControllerKey;
static void (*orig_socialUFI_layoutSubviews)(id, SEL);

static void SCIInitDownloadButtonDownloaders(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dlBtnImageDelegate = [[SCIDownloadDelegate alloc] initWithAction:preview showProgress:YES];
        dlBtnVideoDelegate = [[SCIDownloadDelegate alloc] initWithAction:preview showProgress:YES];
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

static NSBundle *SCIResourcesBundle(void) {
    static NSBundle *bundle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray<NSString *> *candidatePaths = @[
            @"/var/jb/Library/Application Support/SCInsta.bundle",
            @"/Library/Application Support/SCInsta.bundle",
            @"/var/jb/Library/MobileSubstrate/DynamicLibraries/SCInsta.bundle",
            @"/Library/MobileSubstrate/DynamicLibraries/SCInsta.bundle"
        ];

        for (NSString *path in candidatePaths) {
            if ([fileManager fileExistsAtPath:path]) {
                bundle = [NSBundle bundleWithPath:path];
                if (bundle) break;
            }
        }

        if (!bundle) {
            bundle = [NSBundle bundleForClass:[SCIUtils class]];
        }
    });

    return bundle;
}

static UIImage *SCIShareButtonImage(void) {
    static UIImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = SCIResourcesBundle();
        image = [UIImage imageNamed:@"share_button" inBundle:bundle compatibleWithTraitCollection:nil];

        if (!image) {
            NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            NSArray<NSString *> *liveContainerPaths = @[
                [documentsPath stringByAppendingPathComponent:@"Tweaks/SCInsta/share_button@3x.png"],
                [documentsPath stringByAppendingPathComponent:@"Tweaks/SCInsta/share_button@2x.png"]
            ];

            for (NSString *path in liveContainerPaths) {
                if (!path.length) continue;

                image = [UIImage imageWithContentsOfFile:path];
                if (image) break;
            }
        }

        if (!image) {
            NSArray<NSString *> *candidateNames = @[@"share_button@3x", @"share_button@2x", @"share_button"];
            for (NSString *name in candidateNames) {
                NSString *path = [bundle pathForResource:name ofType:@"png"];
                if (!path.length) continue;

                image = [UIImage imageWithContentsOfFile:path];
                if (image) break;
            }
        }

        if (!image) {
            image = [UIImage imageNamed:@"share_button"];
        }

        if (image) {
            image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    });

    return image;
}

static BOOL SCIIsDirectVisualMessageContext(UIView *view) {
    UIViewController *controller = [SCIUtils nearestViewControllerForView:view];
    return [controller isKindOfClass:%c(IGDirectVisualMessageViewerController)];
}

static UIButton *SCIDownloadButtonInContainer(UIView *container, NSInteger tag, id target, SEL action, CGFloat pointSize, UIColor *tintColor) {
    UIButton *button = (UIButton *)[container viewWithTag:tag];
    if (![button isKindOfClass:[UIButton class]]) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = tag;
        button.accessibilityIdentifier = @"com.socuul.scinsta.download-button";
        button.adjustsImageWhenHighlighted = YES;
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        [container addSubview:button];
    }

    UIImage *image = SCIShareButtonImage();
    if (!image) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightMedium];
        image = [[UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:configuration] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

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
    [button removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

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

static id SCIDirectCurrentMessage(id controller) {
    id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
    if (!dataSource) return nil;

    id currentMessage = [SCIUtils getIvarForObj:dataSource name:"_currentMessage"];
    if (currentMessage) return currentMessage;

    return SCIObjectForSelector(dataSource, @"currentMessage");
}

static id SCIDirectOverlayView(id controller) {
    id viewerContainerView = [SCIUtils getIvarForObj:controller name:"_viewerContainerView"];
    if (!viewerContainerView) return nil;

    return SCIObjectForSelector(viewerContainerView, @"overlayView");
}

static BOOL SCIDownloadMediaCandidate(id candidate, NSString *failureDescription) {
    SCIInitDownloadButtonDownloaders();

    id video = nil;
    id photo = nil;

    if ([candidate isKindOfClass:%c(IGVideo)]) {
        video = candidate;
    } else if ([candidate isKindOfClass:%c(IGPhoto)]) {
        photo = candidate;
    } else {
        video = SCIObjectForSelector(candidate, @"video");
        photo = SCIObjectForSelector(candidate, @"photo");
    }

    NSURL *videoURL = [SCIUtils getVideoUrl:video];
    if (videoURL) {
        [dlBtnVideoDelegate downloadFileWithURL:videoURL
                                 fileExtension:videoURL.pathExtension
                                      hudLabel:nil];
        return YES;
    }

    NSURL *photoURL = [SCIUtils getPhotoUrl:photo];
    if (photoURL) {
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

    id rawVideo = SCIObjectForSelector(message, @"rawVideo") ?: [SCIUtils getIvarForObj:message name:"_rawVideo"];
    NSURL *videoURL = [SCIUtils getVideoUrl:rawVideo];
    if (videoURL) {
        [dlBtnVideoDelegate downloadFileWithURL:videoURL
                                 fileExtension:videoURL.pathExtension
                                      hudLabel:nil];
        return YES;
    }

    id rawPhoto = SCIObjectForSelector(message, @"rawPhoto") ?: [SCIUtils getIvarForObj:message name:"_rawPhoto"];
    NSURL *photoURL = [SCIUtils getPhotoUrl:rawPhoto];
    if (photoURL) {
        [dlBtnImageDelegate downloadFileWithURL:photoURL
                                 fileExtension:photoURL.pathExtension
                                      hudLabel:nil];
        return YES;
    }

    if (SCIDownloadMediaCandidate(message, nil)) {
        return YES;
    }

    id media = SCIObjectForSelector(message, @"media");
    if (SCIDownloadMediaCandidate(media, nil)) {
        return YES;
    }

    id visualMessage = SCIObjectForSelector(message, @"visualMessage");
    if (SCIDownloadMediaCandidate(visualMessage, nil)) {
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
    button.alpha = footerView ? footerView.alpha : 1.0;

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

    [overlayView bringSubviewToFront:button];
}

static void SCIHandleSocialUFIDownloadTap(id self, SEL _cmd, UIButton *sender) {
    id media = SCIResolvedFeedMediaFromView((UIView *)self);
    SCIDownloadMediaCandidate(media, @"Could not extract media from post");
}

static void SCIHookedSocialUFILayoutSubviews(id self, SEL _cmd) {
    orig_socialUFI_layoutSubviews(self, _cmd);
    SCIUpdateFeedDownloadButton((UIView *)self, self, @selector(sciDownloadButtonTapped:));
}

%hook IGUFIButtonBarView
- (void)layoutSubviews {
    %orig;

    SCIUpdateFeedDownloadButton((UIView *)self, self, @selector(sciDownloadButtonTapped:));
}

%new - (void)sciDownloadButtonTapped:(UIButton *)sender {
    id media = SCIResolvedFeedMediaFromView((UIView *)self);
    SCIDownloadMediaCandidate(media, @"Could not extract media from post");
}
%end

%hook IGUFIInteractionCountsView
- (void)layoutSubviews {
    %orig;

    SCIUpdateFeedDownloadButton((UIView *)self, self, @selector(sciDownloadButtonTapped:));
}

%new - (void)sciDownloadButtonTapped:(UIButton *)sender {
    id media = SCIResolvedFeedMediaFromView((UIView *)self);
    SCIDownloadMediaCandidate(media, @"Could not extract media from post");
}
%end

%hook IGSundialViewerVerticalUFI
- (void)layoutSubviews {
    %orig;

    SCIUpdateReelDownloadButton((UIView *)self, self, @selector(sciDownloadButtonTapped:));
}

%new - (void)sciDownloadButtonTapped:(UIButton *)sender {
    id media = SCIResolvedReelMediaFromView(self);
    SCIDownloadMediaCandidate(media, @"Could not extract media from reel");
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
    id media = SCIStoryMediaFromOverlay(self);
    SCIDownloadMediaCandidate(media, @"Could not extract media from story");
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

    SCIDownloadDirectMessage(message);
}
%end

%ctor {
    Class socialUFIClass = objc_getClass("IGSocialUFIView.IGSocialUFIView");
    if (!socialUFIClass) return;

    class_addMethod(socialUFIClass, @selector(sciDownloadButtonTapped:), (IMP)SCIHandleSocialUFIDownloadTap, "v@:@");
    MSHookMessageEx(socialUFIClass, @selector(layoutSubviews), (IMP)SCIHookedSocialUFILayoutSubviews, (IMP *)&orig_socialUFI_layoutSubviews);
}
