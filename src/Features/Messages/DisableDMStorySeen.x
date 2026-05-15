#import "../../Utils.h"
#import "../../Tweak.h"

static inline BOOL SCIUnlimitedReplayEnabled(void) {
    return [SCIUtils getBoolPref:@"unlimited_replay"];
}

static inline BOOL SCIShouldPassThroughManualDirectSeen(id message) {
    return (message && SCIPendingDirectVisualMessageToMarkSeen && message == SCIPendingDirectVisualMessageToMarkSeen);
}

%group SCIDisableDMStorySeenHooks

%hook IGDirectVisualMessageViewerEventHandler
- (void)visualMessageViewerController:(id)arg1 didBeginPlaybackForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    if (!SCIUnlimitedReplayEnabled()) {
        return %orig;
    }

    if (SCIShouldPassThroughManualDirectSeen(arg2)) {
        return %orig;
    }
}

- (void)visualMessageViewerController:(id)arg1 didEndPlaybackForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 mediaCurrentTime:(CGFloat)arg4 forNavType:(NSInteger)arg5 {
    if (!SCIUnlimitedReplayEnabled()) {
        return %orig;
    }

    if (SCIShouldPassThroughManualDirectSeen(arg2)) {
        return %orig;
    }
}
%end

%end

void SCIInstallDisableDMStorySeenHooksIfNeeded(void) {
    if (![SCIUtils getBoolPref:@"unlimited_replay"]) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIDisableDMStorySeenHooks);
    });
}
