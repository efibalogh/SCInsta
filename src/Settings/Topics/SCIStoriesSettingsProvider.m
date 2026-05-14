#import "SCIStoriesSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSString * const kSCIStoriesActionButtonEnabledKey = @"action_button_stories_enabled";
static NSString * const kSCIStoriesActionButtonDefaultActionKey = @"action_button_stories_default_action";

@implementation SCIStoriesSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Stories", @"story", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Stories Action Button" subtitle:@"" defaultsKey:kSCIStoriesActionButtonEnabledKey],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Long press to open the full menu" menu:SCIActionButtonDefaultActionMenu(kSCIStoriesActionButtonDefaultActionKey, @"Stories", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceStories))],
            SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSourceStories, @"Stories", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceStories), SCIActionButtonDefaultSectionsForSource(SCIActionButtonSourceStories))
        ], nil),
        SCITopicSection(@"Privacy & Visibility", @[
            [SCISetting switchCellWithTitle:@"Manually Mark Seen" subtitle:@"Prevent automatic seen receipts and add a button to mark the current story as seen" defaultsKey:@"no_seen_receipt"],
            [SCISetting switchCellWithTitle:@"Mark Seen on Like" subtitle:@"Mark the current story as viewed when you like it" defaultsKey:@"story_mark_seen_on_like"],
            [SCISetting switchCellWithTitle:@"Mark Seen on Reply" subtitle:@"Mark the current story as viewed when you reply or react" defaultsKey:@"story_mark_seen_on_reply"],
            [SCISetting switchCellWithTitle:@"Stop Auto Advance" subtitle:@"Prevent automatically moving to the next story" defaultsKey:@"stop_story_auto_advance"],
            [SCISetting switchCellWithTitle:@"Advance on Eye Button" subtitle:@"Move to the next story after marking as seen" defaultsKey:@"advance_story_when_marking_seen"],
            [SCISetting switchCellWithTitle:@"Advance on Story Like" subtitle:@"Move to the next story after liking" defaultsKey:@"advance_story_when_like_marked_seen"],
            [SCISetting switchCellWithTitle:@"Advance on Story Reply" subtitle:@"Move to the next story after replying" defaultsKey:@"advance_story_when_reply_marked_seen"],
            [SCISetting switchCellWithTitle:@"Show Story Mentions" subtitle:@"Shows a button in story overlays when a story has mentions" defaultsKey:@"story_mentions_button"],
            [SCISetting switchCellWithTitle:@"Show Poll Vote Counts" subtitle:@"Polls will display the vote counts next to each option" defaultsKey:@"story_poll_vote_counts"]
        ], nil),
        SCITopicSection(@"Creation", @[
            [SCISetting switchCellWithTitle:@"Use Detailed Color Picker" subtitle:@"Long press on the eyedropper tool in stories to customize text color more precisely" defaultsKey:@"detailed_color_picker"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Like" subtitle:@"" defaultsKey:@"like_confirm_stories"],
            [SCISetting switchCellWithTitle:@"Confirm Sticker Interaction" subtitle:@"" defaultsKey:@"sticker_interact_confirm"]
        ], nil)
    ]);
}

@end
