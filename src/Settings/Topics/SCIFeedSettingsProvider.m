#import "SCIFeedSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSString * const kSCIFeedActionButtonEnabledKey = @"action_button_feed_enabled";
static NSString * const kSCIFeedActionButtonDefaultActionKey = @"action_button_feed_default_action";

@implementation SCIFeedSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Feed", @"feed", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Enable Action Button" subtitle:@"Adds the action button to feed posts" defaultsKey:kSCIFeedActionButtonEnabledKey],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Tap runs this action. Long press opens the full menu" menu:SCIActionButtonDefaultActionMenu(kSCIFeedActionButtonDefaultActionKey, @"Feed", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceFeed))],
            SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSourceFeed, @"Feed", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceFeed), SCIActionButtonDefaultSectionsForSource(SCIActionButtonSourceFeed))
        ], nil),
        SCITopicSection(@"Content", @[
            [SCISetting switchCellWithTitle:@"Hide Stories Tray" subtitle:@"Hides the story tray at the top and within your feed" defaultsKey:@"hide_stories_tray"],
            [SCISetting switchCellWithTitle:@"Hide Entire Feed" subtitle:@"Removes all content from your home feed, including posts" defaultsKey:@"hide_entire_feed"],
            [SCISetting switchCellWithTitle:@"No Suggested Posts" subtitle:@"Removes suggested posts from your feed" defaultsKey:@"no_suggested_post"],
            [SCISetting switchCellWithTitle:@"No Suggested Accounts" subtitle:@"Hides suggested accounts for you to follow in the feed" defaultsKey:@"no_suggested_account"],
            [SCISetting switchCellWithTitle:@"No Suggested Reels" subtitle:@"Hides suggested reels to watch in the feed" defaultsKey:@"no_suggested_reels"],
            [SCISetting switchCellWithTitle:@"No Suggested Threads Posts" subtitle:@"Hides suggested Threads posts in the feed" defaultsKey:@"no_suggested_threads"],
            [SCISetting switchCellWithTitle:@"Disable Video Autoplay" subtitle:@"Prevents videos in your feed from playing automatically" defaultsKey:@"disable_feed_autoplay"],
            [SCISetting switchCellWithTitle:@"Hide Repost Button" subtitle:@"Removes the repost button from feed posts" defaultsKey:@"hide_repost_button_feed"],
            [SCISetting switchCellWithTitle:@"Hide Metrics" subtitle:@"Hides the metrics numbers under posts and reels, including likes, comments, reposts, and shares" defaultsKey:@"hide_metrics"],
            [SCISetting switchCellWithTitle:@"Disable Home Tab Tap Refresh" subtitle:@"Prevents feed refresh when re-tapping the home tab button" defaultsKey:@"disable_home_button_refresh"],
            [SCISetting switchCellWithTitle:@"Disable Background Feed Refresh" subtitle:@"Prevents Instagram from refreshing your home feed in the background" defaultsKey:@"disable_bg_refresh"]
        ], nil),
        SCITopicSection(@"Media", @[
            [SCISetting switchCellWithTitle:@"Start Expanded Videos Muted" subtitle:@"When enabled, expanded videos open muted. You can still unmute from player controls." defaultsKey:@"expanded_video_start_muted"],
            [SCISetting switchCellWithTitle:@"Enable Long Press to Expand" subtitle:@"When enabled, long-pressing media in the feed opens the expanded viewer" defaultsKey:@"enable_long_press_expand"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Likes" subtitle:@"Shows an alert when you like a feed post to confirm the action" defaultsKey:@"like_confirm_feed"],
            [SCISetting switchCellWithTitle:@"Confirm Repost" subtitle:@"Shows an alert when you repost a feed post to confirm the action" defaultsKey:@"repost_confirm_feed"],
            [SCISetting switchCellWithTitle:@"Confirm Posting Comment" subtitle:@"Shows an alert when you post a comment to confirm the action" defaultsKey:@"post_comment_confirm"]
        ], nil)
    ]);
}

@end
