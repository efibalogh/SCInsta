#import "SCIStoriesSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSString * const kSCIStoriesActionButtonEnabledKey = @"action_button_stories_enabled";
static NSString * const kSCIStoriesActionButtonDefaultActionKey = @"action_button_stories_default_action";

@implementation SCIStoriesSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Stories", @"story", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Enable Action Button" subtitle:@"Adds the action button to stories" defaultsKey:kSCIStoriesActionButtonEnabledKey],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Tap runs this action. Long press opens the full menu" menu:SCIActionButtonDefaultActionMenu(kSCIStoriesActionButtonDefaultActionKey, @"Stories", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceStories))],
            SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSourceStories, @"Stories", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceStories), SCIActionButtonDefaultSectionsForSource(SCIActionButtonSourceStories))
        ], nil),
        SCITopicSection(@"Privacy & Visibility", @[
            [SCISetting switchCellWithTitle:@"Manually Mark Stories as Seen" subtitle:@"Prevents automatic seen receipts and adds an eye button to mark the current story as seen manually" defaultsKey:@"no_seen_receipt"],
            [SCISetting switchCellWithTitle:@"Mark Seen on Like" subtitle:@"Marks the current story as viewed when you like it" defaultsKey:@"story_mark_seen_on_like"],
            [SCISetting switchCellWithTitle:@"Mark Seen on Reply" subtitle:@"Marks the current story as viewed when you reply or react" defaultsKey:@"story_mark_seen_on_reply"],
            [SCISetting switchCellWithTitle:@"Stop Story Auto Advance" subtitle:@"Prevents stories from automatically moving to the next item after playback ends" defaultsKey:@"stop_story_auto_advance"],
            [SCISetting switchCellWithTitle:@"Advance on Eye Button" subtitle:@"After marking a story as seen with the eye button, advance to the next story" defaultsKey:@"advance_story_when_marking_seen"],
            [SCISetting switchCellWithTitle:@"Advance on Story Like" subtitle:@"After liking and marking a story as seen, advance to the next story" defaultsKey:@"advance_story_when_like_marked_seen"],
            [SCISetting switchCellWithTitle:@"Advance on Story Reply" subtitle:@"After replying and marking a story as seen, advance to the next story" defaultsKey:@"advance_story_when_reply_marked_seen"],
            [SCISetting switchCellWithTitle:@"Story Mentions Button" subtitle:@"Shows the mentions button in story overlays when a story has mentions" defaultsKey:@"story_mentions_button"],
            [SCISetting switchCellWithTitle:@"Show Poll Vote Counts" subtitle:@"Adds the current vote count next to each poll option while viewing stories" defaultsKey:@"story_poll_vote_counts"]
        ], nil),
        SCITopicSection(@"Creation", @[
            [SCISetting switchCellWithTitle:@"Use Detailed Color Picker" subtitle:@"Long press on the eyedropper tool in stories to customize text color more precisely" defaultsKey:@"detailed_color_picker"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Likes" subtitle:@"Shows an alert when you like a story to confirm the action" defaultsKey:@"like_confirm_stories"],
            [SCISetting switchCellWithTitle:@"Confirm Sticker Interaction" subtitle:@"Shows an alert when you tap a sticker on someone's story to confirm the action" defaultsKey:@"sticker_interact_confirm"]
        ], nil)
    ]);
}

@end
