#import <objc/runtime.h>

#import "../../Shared/ActionButton/ActionButtonLookupUtils.h"
#import "../../Utils.h"

static const void *kSCIShareCopyLongPressAssocKey = &kSCIShareCopyLongPressAssocKey;
static __weak UIView *SCIShareActiveStoryOverlayView = nil;
static NSHashTable<UIGestureRecognizer *> *SCIShareCopyLongPressRecognizers(void) {
    static NSHashTable<UIGestureRecognizer *> *recognizers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recognizers = [NSHashTable weakObjectsHashTable];
    });
    return recognizers;
}

static inline BOOL SCIShareLongPressCopyEnabled(void) {
    return [SCIUtils getBoolPref:@"share_button_long_press_copy_link"];
}

static NSString *SCIShareStringValue(id value) {
    NSString *string = SCIStringFromValue(value);
    return string.length > 0 ? string : nil;
}

static NSURL *SCIInstagramPostURLForCode(NSString *code, id object) {
    if (code.length == 0) return nil;
    NSString *path = @"p";
    for (NSString *selectorName in @[@"productType", @"mediaType", @"mediaSource", @"inventorySource"]) {
        NSString *value = SCIShareStringValue(SCIObjectForSelector(object, selectorName));
        if (value.length == 0) value = SCIShareStringValue(SCIKVCObject(object, selectorName));
        value = value.lowercaseString;
        if ([value containsString:@"reel"] || [value containsString:@"clips"]) {
            path = @"reel";
            break;
        }
    }
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://www.instagram.com/%@/%@/", path, code]];
}

static NSString *SCIShareMediaIDFromObject(id object) {
    for (NSString *selectorName in @[@"pk", @"id", @"mediaID", @"mediaId", @"mediaIdentifier"]) {
        NSString *identifier = SCIShareStringValue(SCIObjectForSelector(object, selectorName));
        if (identifier.length == 0) identifier = SCIShareStringValue(SCIKVCObject(object, selectorName));
        if (identifier.length > 0) {
            NSArray<NSString *> *parts = [identifier componentsSeparatedByString:@"_"];
            NSString *mediaID = parts.firstObject ?: identifier;
            return mediaID.length > 0 ? mediaID : identifier;
        }
    }
    return nil;
}

static NSURL *SCIInstagramStoryURLForMedia(id media) {
    NSString *username = SCIUsernameFromMediaObject(media);
    NSString *identifier = SCIShareMediaIDFromObject(media);
    if (username.length == 0 || identifier.length == 0) return nil;

    NSString *encodedUsername = [username stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    NSString *encodedIdentifier = [identifier stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    if (encodedUsername.length == 0 || encodedIdentifier.length == 0) return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://www.instagram.com/stories/%@/%@/", encodedUsername, encodedIdentifier]];
}

static NSURL *SCIShareURLFromObjectAtDepth(id object, NSInteger depth) {
    if (!object || depth > 3) return nil;

    for (NSString *selectorName in @[@"permalink", @"permaLink", @"shareURL", @"shareUrl", @"canonicalURL", @"canonicalUrl", @"permalinkURL", @"instagramURL", @"instagramUrl", @"webURL", @"webUrl", @"url"]) {
        NSURL *url = SCIURLFromValue(SCIObjectForSelector(object, selectorName));
        if (url) return url;
        url = SCIURLFromValue(SCIKVCObject(object, selectorName));
        if (url) return url;
    }

    for (NSString *selectorName in @[@"code", @"shortCode", @"shortcode", @"mediaCode", @"mediaShortcode", @"shortCodeToken"]) {
        NSString *code = SCIShareStringValue(SCIObjectForSelector(object, selectorName));
        if (code.length == 0) code = SCIShareStringValue(SCIKVCObject(object, selectorName));
        NSURL *url = SCIInstagramPostURLForCode(code, object);
        if (url) return url;
    }

    for (NSString *selectorName in @[@"media", @"post", @"story", @"storyItem", @"storyMedia", @"mediaItem", @"reelMediaItem", @"item", @"currentStoryItem", @"visualMessage", @"model"]) {
        id nested = SCIObjectForSelector(object, selectorName);
        if (!nested) nested = SCIKVCObject(object, selectorName);
        NSURL *url = SCIShareURLFromObjectAtDepth(nested, depth + 1);
        if (url) return url;
    }

    return nil;
}

static id SCIShareStorySectionControllerFromOverlay(UIView *overlayView) {
    NSArray<NSString *> *delegateSelectors = @[@"mediaOverlayDelegate", @"retryDelegate", @"tappableOverlayDelegate", @"buttonDelegate"];
    Class sectionControllerClass = NSClassFromString(@"IGStoryFullscreenSectionController");
    for (NSString *selectorName in delegateSelectors) {
        id delegate = SCIObjectForSelector(overlayView, selectorName);
        if (!delegate) delegate = SCIKVCObject(overlayView, selectorName);
        if (!delegate) continue;
        if (!sectionControllerClass || [delegate isKindOfClass:sectionControllerClass]) return delegate;
    }
    return nil;
}

static id SCIShareStoryMediaFromAnyObject(id object) {
    if (!object) return nil;
    for (NSString *selectorName in @[@"media", @"mediaItem", @"storyItem", @"item", @"model"]) {
        id candidate = SCIObjectForSelector(object, selectorName);
        if (!candidate) candidate = SCIKVCObject(object, selectorName);
        if (candidate && candidate != object) return candidate;
    }
    return object;
}

static id SCIShareStoryMediaFromOverlay(UIView *overlayView) {
    if (!overlayView) return nil;

    id sectionController = SCIShareStorySectionControllerFromOverlay(overlayView);
    UIViewController *viewerController = [SCIUtils nearestViewControllerForView:overlayView];
    if (!sectionController) {
        sectionController = SCIObjectForSelector(viewerController, @"currentSectionController");
        if (!sectionController) sectionController = SCIKVCObject(viewerController, @"currentSectionController");
        if (!sectionController) sectionController = [SCIUtils getIvarForObj:viewerController name:"_currentSectionController"];
    }

    for (id object in @[sectionController ?: (id)NSNull.null, viewerController ?: (id)NSNull.null]) {
        if (object == (id)NSNull.null) continue;
        for (NSString *selectorName in @[@"currentStoryItem", @"currentItem", @"item"]) {
            id media = SCIObjectForSelector(object, selectorName);
            if (!media) media = SCIKVCObject(object, selectorName);
            media = SCIShareStoryMediaFromAnyObject(media);
            if (media) return media;
        }
    }
    return nil;
}

static NSURL *SCIShareStoryURLFromOverlay(UIView *overlayView) {
    id media = SCIShareStoryMediaFromOverlay(overlayView);
    NSURL *url = SCIInstagramStoryURLForMedia(media);
    if (url) return url;
    return SCIShareURLFromObjectAtDepth(media, 0);
}

static NSURL *SCIShareStoryURLFromView(UIView *view) {
    for (UIView *walker = view; walker; walker = walker.superview) {
        if (![NSStringFromClass(walker.class) containsString:@"IGStoryFullscreenOverlayView"]) continue;
        NSURL *url = SCIShareStoryURLFromOverlay(walker);
        if (url) return url;
    }

    NSURL *activeURL = SCIShareStoryURLFromOverlay(SCIShareActiveStoryOverlayView);
    if (activeURL) return activeURL;
    return nil;
}

static NSURL *SCIShareURLFromViewHierarchy(UIView *view) {
    NSURL *storyURL = SCIShareStoryURLFromView(view);
    if (storyURL) return storyURL;

    UIView *walker = view;
    for (NSInteger depth = 0; walker && depth < 24; depth++, walker = walker.superview) {
        NSURL *url = SCIShareURLFromObjectAtDepth(walker, 0);
        if (url) return url;

        id delegate = SCIObjectForSelector(walker, @"delegate");
        url = SCIShareURLFromObjectAtDepth(delegate, 0);
        if (url) return url;

        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(walker.class, &count);
        for (unsigned int i = 0; i < count; i++) {
            const char *type = ivar_getTypeEncoding(ivars[i]);
            if (!type || type[0] != '@') continue;
            id value = nil;
            @try { value = object_getIvar(walker, ivars[i]); } @catch (__unused NSException *exception) {}
            url = SCIShareURLFromObjectAtDepth(value, 0);
            if (url) {
                if (ivars) free(ivars);
                return url;
            }
        }
        if (ivars) free(ivars);
    }

    UIViewController *controller = [SCIUtils nearestViewControllerForView:view];
    return SCIShareURLFromObjectAtDepth(controller, 0);
}

static void SCICopyShareURLForView(UIView *view) {
    if (!SCIShareLongPressCopyEnabled()) return;
    NSURL *url = SCIShareURLFromViewHierarchy(view);
    if ([SCIUtils getBoolPref:@"remove_user_from_copied_share_link"]) {
        url = [SCIUtils sanitizedInstagramShareURL:url] ?: url;
    }
    if (url.absoluteString.length == 0) {
        [SCIUtils showToastForDuration:1.5 title:@"No link found"];
        return;
    }
    UIPasteboard.generalPasteboard.string = url.absoluteString;
    [SCIUtils showToastForDuration:1.5 title:@"Copied link"];
}

static void SCIUpdateShareLongPressRecognizerStates(void) {
    BOOL enabled = SCIShareLongPressCopyEnabled();
    for (UIGestureRecognizer *gesture in SCIShareCopyLongPressRecognizers()) {
        gesture.enabled = enabled;
    }
}

static BOOL SCIShareViewLooksLikeSendControl(UIView *view) {
    NSString *label = (view.accessibilityLabel ?: view.accessibilityIdentifier ?: @"").lowercaseString;
    if ([label containsString:@"send"] || [label containsString:@"share"] || [label containsString:@"paper"] || [label containsString:@"airplane"] || [label containsString:@"direct"]) {
        return YES;
    }
    return NO;
}

static NSArray<UIView *> *SCIShareCandidateSubviews(UIView *root, NSInteger maxDepth) {
    if (!root || maxDepth < 0) return @[];
    NSMutableArray<UIView *> *matches = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *queue = [NSMutableArray arrayWithObject:@{@"view": root, @"depth": @0}];
    while (queue.count > 0) {
        NSDictionary *entry = queue.firstObject;
        [queue removeObjectAtIndex:0];
        UIView *view = entry[@"view"];
        NSInteger depth = [entry[@"depth"] integerValue];
        if (view != root && SCIShareViewLooksLikeSendControl(view)) {
            [matches addObject:view];
        }
        if (depth >= maxDepth) continue;
        for (UIView *subview in view.subviews) {
            [queue addObject:@{@"view": subview, @"depth": @(depth + 1)}];
        }
    }
    return matches;
}

static UIView *SCIShareViewForSelectorOrIvar(id container, NSString *name) {
    id candidate = SCIObjectForSelector(container, name);
    if (![candidate isKindOfClass:[UIView class]]) {
        NSString *ivarName = [NSString stringWithFormat:@"_%@", name];
        candidate = [SCIUtils getIvarForObj:container name:ivarName.UTF8String];
    }
    return [candidate isKindOfClass:[UIView class]] ? (UIView *)candidate : nil;
}

static void SCIInstallShareLongPressOnView(UIView *view) {
    if (!view) return;
    UIGestureRecognizer *existingRecognizer = objc_getAssociatedObject(view, kSCIShareCopyLongPressAssocKey);
    if (existingRecognizer) {
        existingRecognizer.enabled = SCIShareLongPressCopyEnabled();
        [SCIShareCopyLongPressRecognizers() addObject:existingRecognizer];
        return;
    }
    view.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:view action:@selector(sci_copyShareLinkLongPressed:)];
    gesture.minimumPressDuration = 0.22;
    gesture.cancelsTouchesInView = YES;
    gesture.delaysTouchesBegan = YES;
    gesture.delaysTouchesEnded = YES;
    gesture.enabled = SCIShareLongPressCopyEnabled();
    for (UIGestureRecognizer *existing in view.gestureRecognizers.copy) {
        if ([existing isKindOfClass:UILongPressGestureRecognizer.class] && existing != gesture) {
            [existing requireGestureRecognizerToFail:gesture];
        }
    }
    [view addGestureRecognizer:gesture];
    objc_setAssociatedObject(view, kSCIShareCopyLongPressAssocKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [SCIShareCopyLongPressRecognizers() addObject:gesture];
}

static void SCIInstallShareLongPressOnNativeRecognizerHosts(UIView *view, UIView *container) {
    for (UIView *walker = view.superview; walker && walker != container.superview; walker = walker.superview) {
        BOOL hasNativeLongPress = NO;
        for (UIGestureRecognizer *gesture in walker.gestureRecognizers) {
            if ([gesture isKindOfClass:UILongPressGestureRecognizer.class] &&
                !objc_getAssociatedObject(gesture, kSCIShareCopyLongPressAssocKey)) {
                hasNativeLongPress = YES;
                break;
            }
        }
        if (hasNativeLongPress) {
            SCIInstallShareLongPressOnView(walker);
        }
        if (walker == container) break;
    }
}

static void SCIInstallShareLongPressInContainer(UIView *container, NSArray<NSString *> *preferredNames, BOOL includeNativeHosts) {
    if (!container) return;
    for (NSString *name in preferredNames) {
        UIView *view = SCIShareViewForSelectorOrIvar(container, name);
        if (view) {
            SCIInstallShareLongPressOnView(view);
            if (includeNativeHosts) SCIInstallShareLongPressOnNativeRecognizerHosts(view, container);
        }
    }
    for (UIView *candidate in SCIShareCandidateSubviews(container, 4)) {
        SCIInstallShareLongPressOnView(candidate);
        if (includeNativeHosts) SCIInstallShareLongPressOnNativeRecognizerHosts(candidate, container);
    }
}

%group SCIShareLongPressCopyHooks

%hook UIView
%new - (void)sci_copyShareLinkLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    SCICopyShareURLForView((UIView *)self);
}
%end

%hook IGUFIButtonBarView
- (void)layoutSubviews {
    %orig;
    SCIInstallShareLongPressInContainer((UIView *)self, @[@"sendButton", @"shareButton", @"reshareButton"], YES);
}
%end

%hook IGUFIInteractionCountsView
- (void)layoutSubviews {
    %orig;
    SCIInstallShareLongPressInContainer((UIView *)self, @[@"sendButton", @"shareButton", @"reshareButton"], YES);
}
%end

%hook IGSundialViewerVerticalUFI
- (void)layoutSubviews {
    %orig;
    SCIInstallShareLongPressInContainer((UIView *)self, @[@"sendButton", @"shareButton", @"reshareButton"], YES);
}
%end

%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
    %orig;
    SCIShareActiveStoryOverlayView = (UIView *)self;
    SCIInstallShareLongPressInContainer((UIView *)self, @[@"sendButton", @"shareButton", @"reshareButton"], NO);
}
%end

%hook IGDirectVisualMessageViewerController
- (void)viewDidLayoutSubviews {
    %orig;
    SCIInstallShareLongPressInContainer(((UIViewController *)self).view, @[@"sendButton", @"shareButton"], NO);
}
%end

%end

extern "C" void SCIInstallShareLongPressCopyHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIShareLongPressCopyHooks);
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *notification) {
            SCIUpdateShareLongPressRecognizerStates();
        }];
    });
}
