#import <substrate.h>
#import <objc/runtime.h>
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Shared/MediaPreview/SCIFullScreenMediaPlayer.h"

@interface IGProfileAvatarView : UIView
@end

@interface IGProfilePhotoView : UIView
@end

static id SCIObjectForSelector(id target, NSString *selectorName) {
    if (!target || !selectorName.length) return nil;

    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return nil;

    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static id SCIUserFromViewHierarchy(UIView *view) {
    if (!view) return nil;

    id user = SCIObjectForSelector(view, @"user");
    if (user) return user;

    user = SCIObjectForSelector(view, @"userGQL");
    if (user) return user;

    id profilePicImageView = SCIObjectForSelector(view, @"profilePicImageView");
    if (!profilePicImageView) {
        profilePicImageView = [SCIUtils getIvarForObj:view name:"_profilePicImageView"];
    }
    user = SCIObjectForSelector(profilePicImageView, @"user");
    if (user) return user;

    UIViewController *ancestorController = [SCIUtils viewControllerForAncestralView:view];
    user = SCIObjectForSelector(ancestorController, @"user");
    if (user) return user;

    user = SCIObjectForSelector(ancestorController, @"userGQL");
    if (user) return user;

    UIResponder *responder = view;
    while ((responder = [responder nextResponder])) {
        user = SCIObjectForSelector(responder, @"user");
        if (user && [user isKindOfClass:NSClassFromString(@"IGUser")]) return user;

        user = SCIObjectForSelector(responder, @"userGQL");
        if (user && [user isKindOfClass:NSClassFromString(@"IGUser")]) return user;
    }

    return nil;
}

static NSString *SCIUsernameFromIGUser(id user) {
    if (!user) {
        return nil;
    }
    id name = nil;
    @try {
        name = [user valueForKey:@"username"];
    } @catch (__unused NSException *e) {
    }
    if ([name isKindOfClass:[NSString class]] && [(NSString *)name length] > 0) {
        return (NSString *)name;
    }
    return nil;
}

static NSURL *SCIImageURLFromViewHierarchy(UIView *view) {
    Class igImageViewClass = NSClassFromString(@"IGImageView");
    if (igImageViewClass && [view isKindOfClass:igImageViewClass]) {
        IGImageView *iv = (IGImageView *)view;
        if (iv.imageSpecifier && iv.imageSpecifier.url) {
            return iv.imageSpecifier.url;
        }
    }
    for (UIView *sub in view.subviews) {
        NSURL *url = SCIImageURLFromViewHierarchy(sub);
        if (url) return url;
    }
    return nil;
}

static BOOL SCIShouldInterceptProfileLongPress(UILongPressGestureRecognizer *gesture) {
    if (![SCIUtils getBoolPref:@"profile_photo_zoom"]) {
        return NO;
    }

    if (!gesture || gesture.state != UIGestureRecognizerStateBegan) {
        return NO;
    }

    UIView *view = gesture.view;
    if (!view) {
        return NO;
    }

    id user = SCIUserFromViewHierarchy(view);
    NSURL *url = [SCIUtils getBestProfilePictureURLForUser:user];
    if (!url) {
        url = SCIImageURLFromViewHierarchy(view);
    }
    if (!url) {
        return NO;
    }

    NSString *username = SCIUsernameFromIGUser(user);
    [SCIFullScreenMediaPlayer showRemoteImageURL:url profileUsername:username];
    return YES;
}

static void (*orig_coinFlipLongPress)(id, SEL, UILongPressGestureRecognizer *);
static void SCIHookedCoinFlipLongPress(id self, SEL _cmd, UILongPressGestureRecognizer *gesture) {
    if (SCIShouldInterceptProfileLongPress(gesture)) {
        return;
    }

    if (orig_coinFlipLongPress) {
        orig_coinFlipLongPress(self, _cmd, gesture);
    }
}


%hook IGProfileAvatarView
- (void)_profilePictureLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (SCIShouldInterceptProfileLongPress(gesture)) {
        return;
    }

    %orig;
}
%end

%hook IGProfilePhotoView
- (void)_profilePictureLongPress:(UILongPressGestureRecognizer *)gesture {
    if (SCIShouldInterceptProfileLongPress(gesture)) {
        return;
    }

    %orig;
}
%end

%ctor {
    Class coinFlipClass = NSClassFromString(@"IGProfilePhotoCoinFlipUI.IGProfilePhotoCoinFlipView");
    SEL selector = NSSelectorFromString(@"viewLongPressedWithGesture:");

    if (coinFlipClass && class_getInstanceMethod(coinFlipClass, selector)) {
        MSHookMessageEx(coinFlipClass,
                        selector,
                        (IMP)SCIHookedCoinFlipLongPress,
                        (IMP *)&orig_coinFlipLongPress);
    }
}
