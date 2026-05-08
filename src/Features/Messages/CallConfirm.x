#import "../../Utils.h"

%group SCICallConfirmHooks

%hook IGDirectThreadCallButtonsCoordinator
// Voice Call
- (void)_didTapAudioButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"call_confirm"]) {
        NSLog(@"[SCInsta] Call confirm triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }
                                 title:@"Confirm Audio Call"
                               message:@"Are you sure you want to start an audio call?"];
    } else {
        return %orig;
    }
}

// Video Call
- (void)_didTapVideoButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"call_confirm"]) {
        NSLog(@"[SCInsta] Call confirm triggered");
        
        [SCIUtils showConfirmation:^(void) { %orig; }
                                 title:@"Confirm Video Call"
                               message:@"Are you sure you want to start a video call?"];
    } else {
        return %orig;
    }
}
%end

%end

void SCIInstallCallConfirmHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"call_confirm"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCICallConfirmHooks);
    });
}
