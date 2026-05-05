#import "../../Utils.h"

%group SCIVisualMsgModifierHooks

%hook IGDirectVisualMessage
- (NSInteger)viewMode {
    NSInteger mode = %orig;

    // * Modes *
    // 0 - View Once
    // 1 - Replayable

    if ([SCIUtils getBoolPref:@"disable_view_once_limitations"]) {
        if (mode == 0) {
            mode = 1;

            NSLog(@"[SCInsta] Modifying visual message from read-once to replayable");
        }
    }
    
    return mode;
}
%end

%end

void SCIInstallVisualMsgModifierHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"disable_view_once_limitations"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIVisualMsgModifierHooks);
    });
}
