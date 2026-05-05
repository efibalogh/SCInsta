#import "../../Utils.h"

%group SCIStickerInteractConfirmHooks

%hook IGStoryViewerTapTarget
- (void)_didTap:(id)arg1 forEvent:(id)arg2 {
    if ([SCIUtils getBoolPref:@"sticker_interact_confirm"]) {
        NSLog(@"[SCInsta] Confirm sticker interact triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }];
    } else {
        return %orig;
    }
}
%end

%end

void SCIInstallStickerInteractConfirmHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"sticker_interact_confirm"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIStickerInteractConfirmHooks);
    });
}
