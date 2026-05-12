#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Tweak.h"

static inline BOOL SCIShouldBlockStoryAutoAdvance(void) {
    return [SCIUtils getBoolPref:@"stop_story_auto_advance"] && !SCIForceStoryAutoAdvance;
}

%group SCIDisableStorySeenHooks

%hook IGStoryViewerViewController
- (void)fullscreenSectionController:(id)arg1 didMarkItemAsSeen:(id)arg2 {
    (void)arg1;
    BOOL forcedStoryMatches = SCIForceMarkStoryAsSeen;
    if (forcedStoryMatches && SCIForcedStorySeenMediaPK.length > 0) {
        NSString *mediaPK = SCIStoryMediaIdentifier(arg2);
        forcedStoryMatches = [mediaPK isEqualToString:SCIForcedStorySeenMediaPK];
    }

    if ([SCIUtils getBoolPref:@"no_seen_receipt"] && !forcedStoryMatches) {
        NSLog(@"[SCInsta] Prevented automatic story seen marking");
        return;
    }

    %orig;
}
%end

%hook IGStoryFullscreenSectionController
- (void)storyPlayerMediaViewDidPlayToEnd:(id)arg1 {
    if (SCIShouldBlockStoryAutoAdvance()) {
        return;
    }

    %orig;
}

- (void)advanceToNextReelForAutoScroll {
    if (SCIShouldBlockStoryAutoAdvance()) {
        return;
    }

    %orig;
}
%end

%end

void SCIInstallDisableStorySeenHooksIfNeeded(void) {
    if (![SCIUtils getBoolPref:@"no_seen_receipt"] &&
        ![SCIUtils getBoolPref:@"stop_story_auto_advance"]) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIDisableStorySeenHooks);
    });
}
