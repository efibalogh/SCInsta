#import "SCIReelsSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSString * const kSCIReelsActionButtonEnabledKey = @"action_button_reels_enabled";
static NSString * const kSCIReelsActionButtonDefaultActionKey = @"action_button_reels_default_action";

@implementation SCIReelsSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Reels", @"reels_prism", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Enable Action Button" subtitle:@"Adds the action button to reels" defaultsKey:kSCIReelsActionButtonEnabledKey],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Tap runs this action. Long press opens the full menu" menu:SCIActionButtonDefaultActionMenu(kSCIReelsActionButtonDefaultActionKey, @"Reels", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceReels))],
            SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSourceReels, @"Reels", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceReels), SCIActionButtonDefaultSectionsForSource(SCIActionButtonSourceReels))
        ], nil),
        SCITopicSection(@"Behavior", @[
            [SCISetting menuCellWithTitle:@"Tap Controls" subtitle:@"Change what happens when you tap on a reel" menu:SCIReelsTapControlMenu()],
            [SCISetting switchCellWithTitle:@"Always Show Progress Scrubber" subtitle:@"Forces the progress bar to appear on every reel" defaultsKey:@"reels_show_scrubber"],
            [SCISetting switchCellWithTitle:@"Disable Auto-Unmuting Reels" subtitle:@"Prevents reels from unmuting when the volume or silent button is pressed" defaultsKey:@"disable_auto_unmuting_reels" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Confirm Reel Refresh" subtitle:@"Shows an alert when you trigger a reels refresh" defaultsKey:@"refresh_reel_confirm"],
            [SCISetting switchCellWithTitle:@"Disable Reels Tab Tap Refresh" subtitle:@"Prevents reels refresh when re-tapping the reels tab button" defaultsKey:@"disable_reels_tab_refresh"],
            [SCISetting switchCellWithTitle:@"Hide Repost Button" subtitle:@"Removes the repost button from reels" defaultsKey:@"hide_repost_button_reels"]
        ], nil),
        SCITopicSection(@"Layout", @[
            [SCISetting switchCellWithTitle:@"Hide Reels Header" subtitle:@"Hides the top navigation bar when watching reels" defaultsKey:@"hide_reels_header"]
        ], nil),
        SCITopicSection(@"Limits", @[
            [SCISetting switchCellWithTitle:@"Disable Scrolling Reels" subtitle:@"Prevents reels from being scrolled to the next video" defaultsKey:@"disable_scrolling_reels" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Prevent Doom Scrolling" subtitle:@"Limits the amount of reels available to scroll at any given time and prevents refreshing" defaultsKey:@"prevent_doom_scrolling"],
            [SCISetting stepperCellWithTitle:@"Doom Scrolling Limit" subtitle:@"Only loads %@ %@" defaultsKey:@"doom_scrolling_reel_count" min:1 max:100 step:1 label:@"reels" singularLabel:@"reel"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Like" subtitle:@"Shows an alert when you like a reel to confirm the action" defaultsKey:@"like_confirm_reels"],
            [SCISetting switchCellWithTitle:@"Confirm Repost" subtitle:@"Shows an alert when you repost a reel to confirm the action" defaultsKey:@"repost_confirm_reels"]
        ], nil)
    ]);
}

@end
