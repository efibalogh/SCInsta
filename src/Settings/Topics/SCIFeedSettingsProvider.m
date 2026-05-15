#import "SCIFeedSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSString * const kSCIFeedActionButtonEnabledKey = @"action_button_feed_enabled";
static NSString * const kSCIFeedActionButtonDefaultActionKey = @"action_button_feed_default_action";

@implementation SCIFeedSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Feed", @"feed", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Feed Action Button" subtitle:@"" defaultsKey:kSCIFeedActionButtonEnabledKey],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Long press to open the full menu" menu:SCIActionButtonDefaultActionMenu(kSCIFeedActionButtonDefaultActionKey, @"Feed", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceFeed))],
            SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSourceFeed, @"Feed", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceFeed), SCIActionButtonDefaultSectionsForSource(SCIActionButtonSourceFeed))
        ], nil),
        SCITopicSection(@"Visibility", @[
            [SCISetting switchCellWithTitle:@"Hide Stories Tray" subtitle:@"" defaultsKey:@"hide_stories_tray"],
            [SCISetting switchCellWithTitle:@"Hide Entire Feed" subtitle:@"" defaultsKey:@"hide_entire_feed"],
            [SCISetting switchCellWithTitle:@"Hide Suggested Posts" subtitle:@"" defaultsKey:@"no_suggested_post"],
            [SCISetting switchCellWithTitle:@"Hide Suggested Accounts" subtitle:@"" defaultsKey:@"hide_suggested_users_feed"],
            [SCISetting switchCellWithTitle:@"Hide Suggested Reels" subtitle:@"" defaultsKey:@"no_suggested_reels"],
            [SCISetting switchCellWithTitle:@"Hide Suggested Threads" subtitle:@"" defaultsKey:@"no_suggested_threads"],
            [SCISetting switchCellWithTitle:@"Hide Repost Button" subtitle:@"" defaultsKey:@"hide_repost_button_feed" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Hide Metrics" subtitle:@"" defaultsKey:@"hide_metrics"]
        ], nil),
        SCITopicSection(@"Media", @[
            [SCISetting switchCellWithTitle:@"Long Press to Expand" subtitle:@"Long press media in the feed to expand it" defaultsKey:@"enable_long_press_expand"],
            [SCISetting switchCellWithTitle:@"Disable Video Autoplay" subtitle:@"Prevents videos in your feed from playing automatically" defaultsKey:@"disable_feed_autoplay"],
            [SCISetting switchCellWithTitle:@"Start Expanded Videos Muted" subtitle:@"" defaultsKey:@"expanded_video_start_muted"],
        ], nil),
        SCITopicSection(@"Refresh", @[
            [SCISetting switchCellWithTitle:@"Disable Home Tab Tap Refresh" subtitle:@"Prevents feed refresh when re-tapping the home tab button" defaultsKey:@"disable_home_button_refresh"],
            [SCISetting switchCellWithTitle:@"Disable Background Feed Refresh" subtitle:@"Prevents feed refresh in the background" defaultsKey:@"disable_bg_refresh"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Post Likes" subtitle:@"" defaultsKey:@"like_confirm_feed_post_likes"],
            [SCISetting switchCellWithTitle:@"Confirm Media Double-Tap Likes" subtitle:@"" defaultsKey:@"like_confirm_feed_double_tap_likes"],
            [SCISetting switchCellWithTitle:@"Confirm Repost" subtitle:@"" defaultsKey:@"repost_confirm_feed"],
            [SCISetting switchCellWithTitle:@"Confirm Posting Comment" subtitle:@"" defaultsKey:@"post_comment_confirm"]
        ], nil),
        SCITopicSection(@"Comments", @[
            [SCISetting switchCellWithTitle:@"Confirm Comment Likes" subtitle:@"" defaultsKey:@"like_confirm_comment_likes"],
            [SCISetting switchCellWithTitle:@"Hide Comment Shopping" subtitle:@"Hide commerce carousels in comment threads" defaultsKey:@"hide_comment_commerce_carousel"]
        ], nil)
    ]);
}

@end
