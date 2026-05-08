#import "../../Utils.h"

// Legacy hook (for non ai voices interface)
%group SCIDMAudioMsgConfirmHooks

%hook IGDirectThreadViewController
- (void)voiceRecordViewController:(id)arg1 didRecordAudioClipWithURL:(id)arg2 waveform:(id)arg3 duration:(CGFloat)arg4 entryPoint:(NSInteger)arg5 {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) {
        NSLog(@"[SCInsta] DM audio message confirm triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }
                                 title:@"Confirm Send Voice Message"
                               message:@"Are you sure you want to send this voice message?"];
    } else {
        return %orig;
    }
}
%end

// Workaround until I can figure out how to stop long press recording from automatically sending
%hook IGDirectComposer
- (void)_didLongPressVoiceMessage:(id)arg1 {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) {
        return;
    } else {
        return %orig;
    }
}
%end

// Demangled name: IGDirectAIVoiceUIKit.CompactBarContentView
%hook _TtC20IGDirectAIVoiceUIKitP33_5754F7617E0D924F9A84EFA352BBD29A21CompactBarContentView
- (void)didTapSend {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) {
        NSLog(@"[SCInsta] DM audio message confirm triggered");

        [SCIUtils showConfirmation:^(void) { %orig; }
                                 title:@"Confirm Send Voice Message"
                               message:@"Are you sure you want to send this voice message?"];
    } else {
        return %orig;
    }
}
%end

%end

void SCIInstallDMAudioMsgConfirmHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"voice_message_confirm"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIDMAudioMsgConfirmHooks);
    });
}
