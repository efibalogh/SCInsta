#import "SCIStoriesSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"

static NSString * const kSCIStoriesActionButtonEnabledKey = @"action_button_stories_enabled";
static NSString * const kSCIStoriesActionButtonDefaultActionKey = @"action_button_stories_default_action";

@implementation SCIStoriesSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Stories", @"story", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Enable Action Button" subtitle:@"Adds the action button to stories" defaultsKey:kSCIStoriesActionButtonEnabledKey],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Tap runs this action. Long press opens the full menu" menu:SCIActionButtonDefaultActionMenu(kSCIStoriesActionButtonDefaultActionKey)]
        ], nil),
        SCITopicSection(@"Privacy & Visibility", @[
            [SCISetting switchCellWithTitle:@"Disable Story Seen Receipt" subtitle:@"Prevents automatic story seen receipts and adds an eye button to mark the current story as seen manually" defaultsKey:@"no_seen_receipt"],
            [SCISetting switchCellWithTitle:@"Stop Story Auto Advance" subtitle:@"Prevents stories from automatically moving to the next item after playback ends" defaultsKey:@"stop_story_auto_advance"],
            [SCISetting switchCellWithTitle:@"Advance When Marked as Seen" subtitle:@"After manually marking a story as seen with the eye button, advance to the next story" defaultsKey:@"advance_story_when_marking_seen"]
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
