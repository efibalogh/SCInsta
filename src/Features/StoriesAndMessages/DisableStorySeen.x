#import "../../Utils.h"
#import "../../Tweak.h"

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
