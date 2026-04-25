#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Tweak.h"

static inline BOOL SCIShouldBlockStoryAutoAdvance(void) {
    return [SCIUtils getBoolPref:@"stop_story_auto_advance"] && !SCIForceStoryAutoAdvance;
}

%hook IGStoryViewerViewController
- (void)fullscreenSectionController:(id)arg1 didMarkItemAsSeen:(id)arg2 {
    (void)arg1;
    (void)arg2;
    if ([SCIUtils getBoolPref:@"no_seen_receipt"] && !SCIForceMarkStoryAsSeen) {
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
