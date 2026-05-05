#import "../../Utils.h"

// Demangled name: IGFeedPlayback.IGFeedPlaybackStrategy
%group SCIDisableFeedAutoplayHooks

%hook _TtC14IGFeedPlayback22IGFeedPlaybackStrategy
- (id)initWithShouldDisableAutoplay:(_Bool)autoplay {
    if ([SCIUtils getBoolPref:@"disable_feed_autoplay"]) return %orig(true);

    return %orig(autoplay);
}
%end

%end

void SCIInstallDisableFeedAutoplayHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"disable_feed_autoplay"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIDisableFeedAutoplayHooks);
    });
}
