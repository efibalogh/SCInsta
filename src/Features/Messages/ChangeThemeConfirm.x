#import "../../InstagramHeaders.h"
#import "../../Utils.h"

%group SCIChangeThemeConfirmHooks

%hook IGDirectThreadThemePickerViewController
- (void)themeNewPickerSectionController:(id)arg1 didSelectTheme:(id)arg2 atIndex:(NSInteger)arg3 {
    if ([SCIUtils getBoolPref:@"change_direct_theme_confirm"]) {
        NSLog(@"[SCInsta] Confirm change direct theme triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }];
    } else {
        return %orig;
    }
}
- (void)themePickerSectionController:(id)arg1 didSelectThemeId:(id)arg2 {
    if ([SCIUtils getBoolPref:@"change_direct_theme_confirm"]) {
        NSLog(@"[SCInsta] Confirm change direct theme triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }];
    } else {
        return %orig;
    }
}
%end

%hook IGDirectThreadThemeKitSwift.IGDirectThreadThemePreviewController
- (void)primaryButtonTapped {
    if ([SCIUtils getBoolPref:@"change_direct_theme_confirm"]) {
        NSLog(@"[SCInsta] Confirm change direct theme triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }];
    } else {
        return %orig;
    }
}
%end

%end

void SCIInstallChangeThemeConfirmHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"change_direct_theme_confirm"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIChangeThemeConfirmHooks);
    });
}
