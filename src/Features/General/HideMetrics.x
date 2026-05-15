#import "../../Utils.h"

%group SCIHideMetricsHooks

%hook IGSundialViewerVerticalUFI
- (void)setNumLikes:(NSInteger)num {
    return %orig([SCIUtils getBoolPref:@"hide_reels_like_count"] ? 0 : num);
}
- (void)setNumReshares:(NSInteger)num {
    return %orig([SCIUtils getBoolPref:@"hide_reels_reshare_count"] ? 0 : num);
}
- (void)setNumComments:(NSInteger)num {
    return %orig([SCIUtils getBoolPref:@"hide_reels_comment_count"] ? 0 : num);
}
- (void)setNumReposts:(NSInteger)num {
    return %orig([SCIUtils getBoolPref:@"hide_reels_repost_count"] ? 0 : num);
}
- (void)setNumSaves:(NSInteger)num {
    return %orig([SCIUtils getBoolPref:@"hide_reels_save_count"] ? 0 : num);
}
%end

%hook IGUFIButtonWithCountsView
- (void)setCountString:(id)string showButton:(BOOL)showButton {
    return %orig([SCIUtils getBoolPref:@"hide_metrics"] ? @"" : string, showButton);
}
%end

%end

void SCIInstallHideMetricsHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"hide_metrics"] &&
        ![SCIUtils getBoolPref:@"hide_reels_like_count"] &&
        ![SCIUtils getBoolPref:@"hide_reels_reshare_count"] &&
        ![SCIUtils getBoolPref:@"hide_reels_comment_count"] &&
        ![SCIUtils getBoolPref:@"hide_reels_repost_count"] &&
        ![SCIUtils getBoolPref:@"hide_reels_save_count"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIHideMetricsHooks);
    });
}
