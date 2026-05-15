#import "SCIReelsSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSString * const kSCIReelsActionButtonEnabledKey = @"action_button_reels_enabled";
static NSString * const kSCIReelsActionButtonDefaultActionKey = @"action_button_reels_default_action";

@implementation SCIReelsSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Reels", @"reels", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Reels Action Button" subtitle:@"" defaultsKey:kSCIReelsActionButtonEnabledKey],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Long press to open the full menu" menu:SCIActionButtonDefaultActionMenu(kSCIReelsActionButtonDefaultActionKey, @"Reels", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceReels))],
            SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSourceReels, @"Reels", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceReels), SCIActionButtonDefaultSectionsForSource(SCIActionButtonSourceReels))
        ], nil),
        SCITopicSection(@"Behavior", @[
            [SCISetting menuCellWithTitle:@"Tap Controls" subtitle:@"Change what happens when you tap on a reel" menu:SCIReelsTapControlMenu()],
            [SCISetting switchCellWithTitle:@"Always Show Progress Scrubber" subtitle:@"Force the progress bar to appear on every reel" defaultsKey:@"reels_show_scrubber"],
            [SCISetting switchCellWithTitle:@"Disable Auto-Unmuting Reels" subtitle:@"Prevent reels from unmuting when the volume or silent button is pressed" defaultsKey:@"disable_auto_unmuting_reels" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Disable Reels Tab Tap to Refresh" subtitle:@"Prevent reels refresh when re-tapping the reels tab button" defaultsKey:@"disable_reels_tab_refresh"]
        ], nil),
        SCITopicSection(@"Limits", @[
            [SCISetting switchCellWithTitle:@"Disable Scrolling Reels" subtitle:@"" defaultsKey:@"disable_scrolling_reels" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Prevent Doom Scrolling" subtitle:@"" defaultsKey:@"prevent_doom_scrolling"],
            [SCISetting stepperCellWithTitle:@"Doom Scrolling Limit" subtitle:@"Only loads %@ %@" defaultsKey:@"doom_scrolling_reel_count" min:1 max:100 step:1 label:@"reels" singularLabel:@"reel"]
        ], nil),
        SCITopicSection(@"Layout", @[
            [SCISetting switchCellWithTitle:@"Hide Reels Header" subtitle:@"" defaultsKey:@"hide_reels_header"],
            [SCISetting switchCellWithTitle:@"Hide Repost Button" subtitle:@"" defaultsKey:@"hide_repost_button_reels" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Hide Suggested Accounts" subtitle:@"" defaultsKey:@"hide_suggested_users_reels"]
        ], nil),
        SCITopicSection(@"Metrics", @[
            [SCISetting switchCellWithTitle:@"Hide Like Count" subtitle:@"" defaultsKey:@"hide_reels_like_count"],
            [SCISetting switchCellWithTitle:@"Hide Comment Count" subtitle:@"" defaultsKey:@"hide_reels_comment_count"],
            [SCISetting switchCellWithTitle:@"Hide Repost Count" subtitle:@"" defaultsKey:@"hide_reels_repost_count"],
            [SCISetting switchCellWithTitle:@"Hide Reshare Count" subtitle:@"" defaultsKey:@"hide_reels_reshare_count"],
            [SCISetting switchCellWithTitle:@"Hide Save Count" subtitle:@"" defaultsKey:@"hide_reels_save_count"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Like" subtitle:@"" defaultsKey:@"like_confirm_reels"],
            [SCISetting switchCellWithTitle:@"Confirm Reel Refresh" subtitle:@"" defaultsKey:@"refresh_reel_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Repost" subtitle:@"" defaultsKey:@"repost_confirm_reels"]
        ], nil)
    ]);
}

@end
