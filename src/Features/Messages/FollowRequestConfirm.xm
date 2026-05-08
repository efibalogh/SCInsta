#import "../../Utils.h"

%group SCIFollowRequestConfirmHooks

%hook IGPendingRequestView
- (void)_onApproveButtonTapped {
    if ([SCIUtils getBoolPref:@"follow_request_confirm"]) {
        NSLog(@"[SCInsta] Confirm follow request triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }
                                 title:@"Confirm Accept Request"
                               message:@"Are you sure you want to accept this follow request?"];
    } else {
        return %orig;
    }
}
- (void)_onIgnoreButtonTapped {
    if ([SCIUtils getBoolPref:@"follow_request_confirm"]) {
        NSLog(@"[SCInsta] Confirm follow request triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }
                                 title:@"Confirm Decline Request"
                               message:@"Are you sure you want to decline this follow request?"];
    } else {
        return %orig;
    }
}
%end

%end

extern "C" void SCIInstallFollowRequestConfirmHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"follow_request_confirm"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIFollowRequestConfirmHooks);
    });
}
