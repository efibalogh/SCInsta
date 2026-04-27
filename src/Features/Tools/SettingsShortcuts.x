#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Settings/SCISettingsViewController.h"
#import "../../Shared/Gallery/SCIGalleryViewController.h"

static const void *kSCIHomeTabSettingsLongPressAssocKey = &kSCIHomeTabSettingsLongPressAssocKey;
static const void *kSCIDirectTabGalleryLongPressAssocKey = &kSCIDirectTabGalleryLongPressAssocKey;
static const NSTimeInterval kSCIHomeTabLongPressDuration = 0.3;
static const NSTimeInterval kSCIDirectTabGalleryLongPressDuration = 1.0;

@interface IGTabBarButton (SCIQuickActions)
- (void)sci_addLongPressWithAction:(SEL)action marker:(const void *)marker minimumDuration:(NSTimeInterval)minimumDuration;
- (void)handleHomeTabLongPress:(UILongPressGestureRecognizer *)sender;
- (void)handleDirectInboxTabLongPress:(UILongPressGestureRecognizer *)sender;
@end

// Show SCInsta tweak settings by holding on the settings/more icon under profile for ~1 second
%hook IGBadgedNavigationButton
- (void)didMoveToWindow {
    %orig;

    if ([self.accessibilityIdentifier isEqualToString:@"profile-more-button"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}

%new - (void)addLongPressGestureRecognizer {
    if ([self.gestureRecognizers count] == 0) {
        NSLog(@"[SCInsta] Adding tweak settings long press gesture recognizer");

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self addGestureRecognizer:longPress];
    }
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    
    NSLog(@"[SCInsta] Tweak settings gesture activated");

    [SCIUtils showSettingsVC:[self window]];
}
%end

// Quick access to tweak settings by holding on home tab button
%hook IGTabBarButton
- (void)didMoveToSuperview {
    %orig;

    NSString *identifier = self.accessibilityIdentifier ?: @"";
    if ([identifier isEqualToString:@"mainfeed-tab"] && [SCIUtils getBoolPref:@"settings_shortcut"]) {
        [self sci_addLongPressWithAction:@selector(handleHomeTabLongPress:) marker:kSCIHomeTabSettingsLongPressAssocKey minimumDuration:kSCIHomeTabLongPressDuration];
    } else if ([identifier isEqualToString:@"direct-inbox-tab"] && [SCIUtils getBoolPref:@"header_long_press_gallery"]) {
        [self sci_addLongPressWithAction:@selector(handleDirectInboxTabLongPress:) marker:kSCIDirectTabGalleryLongPressAssocKey minimumDuration:kSCIDirectTabGalleryLongPressDuration];
    }
}

%new - (void)sci_addLongPressWithAction:(SEL)action marker:(const void *)marker minimumDuration:(NSTimeInterval)minimumDuration {
    for (UIGestureRecognizer *gesture in self.gestureRecognizers) {
        if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]]) continue;
        if (objc_getAssociatedObject(gesture, marker)) {
            return;
        }
    }

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:action];
    longPress.minimumPressDuration = minimumDuration;

    for (UIGestureRecognizer *existing in self.gestureRecognizers) {
        [existing requireGestureRecognizerToFail:longPress];
    }

    [self addGestureRecognizer:longPress];
    objc_setAssociatedObject(longPress, marker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new - (void)handleHomeTabLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    [SCIUtils showSettingsVC:[self window]];
}

%new - (void)handleDirectInboxTabLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    [SCIGalleryViewController presentGallery];
}
%end
