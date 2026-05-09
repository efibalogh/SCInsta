#import "SCIMessagesSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSString * const kSCIMessagesActionButtonEnabledKey = @"action_button_messages_enabled";
static NSString * const kSCIMessagesActionButtonDefaultActionKey = @"action_button_messages_default_action";

@implementation SCIMessagesSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Messages", @"messages", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Enable Action Button" subtitle:@"Adds the action button to visual messages" defaultsKey:kSCIMessagesActionButtonEnabledKey],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Tap runs this action. Long press opens the full menu" menu:SCIActionButtonDefaultActionMenu(kSCIMessagesActionButtonDefaultActionKey, @"Messages", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceDirect))],
            SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSourceDirect, @"Messages", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceDirect), SCIActionButtonDefaultSectionsForSource(SCIActionButtonSourceDirect))
        ], nil),
        SCITopicSection(@"Privacy & Behavior", @[
            [SCISetting switchCellWithTitle:@"Keep Deleted Messages" subtitle:@"Saves deleted messages in chat conversations" defaultsKey:@"keep_deleted_message"],
            [SCISetting switchCellWithTitle:@"Manually Mark Messages as Seen" subtitle:@"Adds a button to DM threads that marks messages as seen" defaultsKey:@"remove_lastseen"],
            [SCISetting switchCellWithTitle:@"Auto-Seen on Send" subtitle:@"Marks messages as seen automatically right after you send a message in the thread" defaultsKey:@"seen_auto_on_send"],
            [SCISetting switchCellWithTitle:@"Advance After Manual Seen" subtitle:@"After marking a visual message as seen, move to the next viewer item when available" defaultsKey:@"advance_direct_visual_when_marking_seen"],
            [SCISetting switchCellWithTitle:@"Confirm Inbox Refresh" subtitle:@"Shows an alert before pull-to-refresh reloads the messages list" defaultsKey:@"dm_refresh_confirm"],
            [SCISetting switchCellWithTitle:@"Disable Disappearing Swipe-Up" subtitle:@"Blocks swipe-up gesture paths used to enter or toggle disappearing mode" defaultsKey:@"disable_disappearing_swipe_up"],
            [SCISetting switchCellWithTitle:@"Disable Typing Status" subtitle:@"Prevents the typing indicator from being shown to others when you're typing in DMs" defaultsKey:@"disable_typing_status"],
            [SCISetting switchCellWithTitle:@"No Suggested Chats" subtitle:@"Hides the suggested broadcast channels in direct messages" defaultsKey:@"no_suggested_chats"],
            [SCISetting switchCellWithTitle:@"Hide Create Group Button" subtitle:@"Removes the share-sheet button that appears after selecting multiple recipients, including its layout space" defaultsKey:@"hide_create_group_button"],
            [SCISetting switchCellWithTitle:@"Hide Reels Blend Button" subtitle:@"Hides the button in DMs that opens a reels blend" defaultsKey:@"hide_reels_blend"]
        ], nil),
        SCITopicSection(@"Visual Messages", @[
            [SCISetting switchCellWithTitle:@"Unlimited Replay of Visual Messages" subtitle:@"Replay direct visual messages unlimited times and mark them as seen manually with the eye button" defaultsKey:@"unlimited_replay"],
            [SCISetting switchCellWithTitle:@"Disable View-Once Limitations" subtitle:@"Makes view-once messages behave like normal visual messages" defaultsKey:@"disable_view_once_limitations"],
            [SCISetting switchCellWithTitle:@"Disable Screenshot Detection" subtitle:@"Removes screenshot-prevention features for visual messages in DMs" defaultsKey:@"remove_screenshot_alert"],
            [SCISetting switchCellWithTitle:@"Hide Vanish Screenshot Events" subtitle:@"Suppresses screenshot and screen-record callbacks while disappearing mode is active" defaultsKey:@"hide_vanish_screenshot"],
            [SCISetting switchCellWithTitle:@"Disable Instants Creation" subtitle:@"Hides the functionality to create or send instants" defaultsKey:@"disable_instants_creation" requiresRestart:YES]
        ], nil),
        SCITopicSection(@"Notes", @[
            [SCISetting switchCellWithTitle:@"Hide Notes Tray" subtitle:@"Hides the notes tray in the DM inbox" defaultsKey:@"hide_notes_tray"],
            [SCISetting switchCellWithTitle:@"Hide Friends Map" subtitle:@"Hides the friends map icon in the notes tray" defaultsKey:@"hide_friends_map"],
            [SCISetting switchCellWithTitle:@"Enable Note Theming" subtitle:@"Enables the ability to use the notes theme picker" defaultsKey:@"enable_notes_customization"],
            [SCISetting switchCellWithTitle:@"Custom Note Themes" subtitle:@"Provides an option to set custom emojis and background or text colors" defaultsKey:@"custom_note_themes"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Call" subtitle:@"Shows an alert when you tap the audio or video call button to confirm before calling" defaultsKey:@"call_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Create Group Button" subtitle:@"Shows a confirmation alert before using the share-sheet button that creates or sends to a group from multiple selected recipients" defaultsKey:@"confirm_create_group_button"],
            [SCISetting switchCellWithTitle:@"Confirm Voice Messages" subtitle:@"Shows an alert to confirm before sending a voice message" defaultsKey:@"voice_message_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Follow Requests" subtitle:@"Shows an alert when you accept or decline a follow request" defaultsKey:@"follow_request_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Shh Mode" subtitle:@"Shows an alert to confirm before toggling disappearing messages" defaultsKey:@"shh_mode_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Changing Theme" subtitle:@"Shows an alert when you change a chat theme to confirm the action" defaultsKey:@"change_direct_theme_confirm"]
        ], nil)
    ]);
}

@end
