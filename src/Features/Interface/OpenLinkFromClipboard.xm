#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"

static const void *kSCIClipboardExploreGestureKey = &kSCIClipboardExploreGestureKey;

static NSURL *SCINormalizedInstagramClipboardURL(NSString *raw) {
    if (raw.length == 0) return nil;

    NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return nil;
    if (![trimmed containsString:@"://"]) {
        trimmed = [@"https://" stringByAppendingString:trimmed];
    }

    NSURL *url = [NSURL URLWithString:trimmed];
    NSString *scheme = url.scheme.lowercaseString ?: @"";
    if ([scheme isEqualToString:@"instagram"]) {
        return url;
    }
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        return nil;
    }

    NSString *host = url.host.lowercaseString ?: @"";
    if (host.length == 0) return nil;

    if ([host isEqualToString:@"instagram.com"] ||
        [host hasSuffix:@".instagram.com"] ||
        [host isEqualToString:@"instagr.am"] ||
        [host isEqualToString:@"ig.me"]) {
        return url;
    }

    if ([host containsString:@"instagram"]) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        components.scheme = @"https";
        components.host = @"www.instagram.com";
        return components.URL;
    }

    return nil;
}

static BOOL SCICanAttemptOpenInstagramClipboardURL(NSURL *url) {
    if (!url) return NO;

    NSString *scheme = url.scheme.lowercaseString ?: @"";
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        return url.host.length > 0;
    }

    if ([scheme isEqualToString:@"instagram"]) {
        UIApplication *application = [UIApplication sharedApplication];
        id<UIApplicationDelegate> delegate = application.delegate;
        return [application canOpenURL:url] || [delegate respondsToSelector:@selector(application:openURL:options:)];
    }

    return NO;
}

@interface SCIClipboardExploreLinkHandler : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)sharedHandler;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation SCIClipboardExploreLinkHandler

+ (instancetype)sharedHandler {
    static SCIClipboardExploreLinkHandler *handler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[SCIClipboardExploreLinkHandler alloc] init];
    });
    return handler;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    (void)gestureRecognizer;
    if (![SCIUtils getBoolPref:@"search_bar_open_clipboard_link"]) return NO;

    NSURL *url = SCINormalizedInstagramClipboardURL(UIPasteboard.generalPasteboard.string);
    return SCICanAttemptOpenInstagramClipboardURL(url);
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    NSURL *url = SCINormalizedInstagramClipboardURL(UIPasteboard.generalPasteboard.string);
    if (!SCICanAttemptOpenInstagramClipboardURL(url)) return;
    if (![SCIUtils openInstagramMediaURL:url]) return;

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
}

@end

static void SCIAttachClipboardGestureToExploreButton(UIButton *button) {
    if (!button || objc_getAssociatedObject(button, kSCIClipboardExploreGestureKey)) return;

    SCIClipboardExploreLinkHandler *handler = [SCIClipboardExploreLinkHandler sharedHandler];
    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:handler action:@selector(handleLongPress:)];
    gesture.minimumPressDuration = 0.5;
    gesture.delegate = handler;
    gesture.cancelsTouchesInView = YES;
    [button addGestureRecognizer:gesture];
    objc_setAssociatedObject(button, kSCIClipboardExploreGestureKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%hook IGTabBarController

- (void)viewDidLayoutSubviews {
    %orig;

    Ivar exploreButtonIvar = class_getInstanceVariable([self class], "_exploreButton");
    if (!exploreButtonIvar) return;

    id exploreButton = object_getIvar(self, exploreButtonIvar);
    if ([exploreButton isKindOfClass:[UIButton class]]) {
        SCIAttachClipboardGestureToExploreButton((UIButton *)exploreButton);
    }
}

%end
