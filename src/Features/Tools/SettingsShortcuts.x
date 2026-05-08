#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Settings/SCISettingsViewController.h"
#import "../../Shared/Gallery/SCIGalleryViewController.h"

static const void *kSCIHomeTabSettingsLongPressAssocKey = &kSCIHomeTabSettingsLongPressAssocKey;
static const void *kSCIGalleryTabLongPressAssocKey = &kSCIGalleryTabLongPressAssocKey;
static const NSTimeInterval kSCIHomeTabLongPressDuration = 0.3;
static const NSTimeInterval kSCIGalleryTabLongPressDuration = 0.65;

@interface IGTabBarButton (SCIQuickActions)
- (void)sci_addLongPressWithAction:(SEL)action marker:(const void *)marker minimumDuration:(NSTimeInterval)minimumDuration;
- (void)handleHomeTabLongPress:(UILongPressGestureRecognizer *)sender;
- (void)handleDirectInboxTabLongPress:(UILongPressGestureRecognizer *)sender;
@end

static NSString *SCIGalleryShortcutTabIdentifier(void) {
    NSString *identifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"gallery_long_press_tab"];
    return identifier.length > 0 ? identifier : @"direct-inbox-tab";
}

static BOOL SCITabIdentifierMatchesGalleryShortcut(NSString *identifier, NSString *label) {
    NSString *target = SCIGalleryShortcutTabIdentifier();
    NSString *candidate = [NSString stringWithFormat:@"%@ %@", identifier ?: @"", label ?: @""].lowercaseString;
    if ([identifier isEqualToString:target]) return YES;
    if ([target isEqualToString:@"mainfeed-tab"] && ([candidate containsString:@"mainfeed"] || [candidate containsString:@"home"])) return YES;
    if ([target isEqualToString:@"clips-tab"] && ([candidate containsString:@"clips"] || [candidate containsString:@"reels"])) return YES;
    if ([target isEqualToString:@"direct-inbox-tab"] && ([candidate containsString:@"direct"] || [candidate containsString:@"inbox"] || [candidate containsString:@"message"])) return YES;
    if ([target isEqualToString:@"profile-tab"] && ([candidate containsString:@"profile"] || [candidate containsString:@"tab_avatar"])) return YES;
    return NO;
}

// Show SCInsta tweak settings by holding on the settings/more icon under profile for ~1 second
%group SCISettingsShortcutsHooks

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
    NSString *label = self.accessibilityLabel ?: @"";
    if ([identifier isEqualToString:@"mainfeed-tab"] && [SCIUtils getBoolPref:@"settings_shortcut"]) {
        if (![SCIUtils getBoolPref:@"header_long_press_gallery"] || ![SCIGalleryShortcutTabIdentifier() isEqualToString:@"mainfeed-tab"]) {
            [self sci_addLongPressWithAction:@selector(handleHomeTabLongPress:) marker:kSCIHomeTabSettingsLongPressAssocKey minimumDuration:kSCIHomeTabLongPressDuration];
        }
    }
    if ([SCIUtils getBoolPref:@"header_long_press_gallery"] && SCITabIdentifierMatchesGalleryShortcut(identifier, label)) {
        [self sci_addLongPressWithAction:@selector(handleDirectInboxTabLongPress:) marker:kSCIGalleryTabLongPressAssocKey minimumDuration:kSCIGalleryTabLongPressDuration];
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
    BOOL opensGallery = marker == kSCIGalleryTabLongPressAssocKey;
    longPress.cancelsTouchesInView = opensGallery;
    longPress.delaysTouchesBegan = opensGallery;
    longPress.delaysTouchesEnded = opensGallery;

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

%end

void SCIInstallSettingsShortcutsHooksIfNeeded(void) {
    if (![SCIUtils getBoolPref:@"settings_shortcut"] &&
        ![SCIUtils getBoolPref:@"header_long_press_gallery"]) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCISettingsShortcutsHooks);
    });
}
