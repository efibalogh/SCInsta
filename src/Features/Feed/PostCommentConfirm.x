#import "../../Utils.h"

%group SCIPostCommentConfirmHooks

%hook IGCommentComposer.IGCommentComposerController
- (void)onSendButtonTap {
    if ([SCIUtils getBoolPref:@"post_comment_confirm"]) {
        NSLog(@"[SCInsta] Confirm post comment triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }];
    } else {
        return %orig;
    }
}
%end

%end

void SCIInstallPostCommentConfirmHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"post_comment_confirm"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIPostCommentConfirmHooks);
    });
}
