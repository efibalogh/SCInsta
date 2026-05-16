#import "SCIMessagesSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSString * const kSCIMessagesActionButtonEnabledKey = @"action_button_messages_enabled";
static NSString * const kSCIMessagesActionButtonDefaultActionKey = @"action_button_messages_default_action";

@implementation SCIMessagesSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Messages", @"messages", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Visual Messages Action Button" subtitle:@"" defaultsKey:kSCIMessagesActionButtonEnabledKey],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Long press to open the full menu" menu:SCIActionButtonDefaultActionMenu(kSCIMessagesActionButtonDefaultActionKey, @"Messages", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceDirect))],
            SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSourceDirect, @"Messages", SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceDirect), SCIActionButtonDefaultSectionsForSource(SCIActionButtonSourceDirect))
        ], nil),
        SCITopicSection(@"Messages", @[
            /// TODO: fix
            [SCISetting switchCellWithTitle:@"Keep Deleted Messages" subtitle:@"" defaultsKey:@"keep_deleted_message"],
            [SCISetting switchCellWithTitle:@"Manually Mark Seen" subtitle:@"" defaultsKey:@"remove_lastseen"],
            [SCISetting switchCellWithTitle:@"Mark Seen on Send" subtitle:@"Marks messages as seen automatically when you send a message or react" defaultsKey:@"seen_auto_on_send"],
            [SCISetting switchCellWithTitle:@"Disable Typing Status" subtitle:@"Prevents the typing indicator from being shown to others when you're typing in DMs" defaultsKey:@"disable_typing_status"],
            /// TODO: fix
            [SCISetting switchCellWithTitle:@"Confirm Inbox Refresh" subtitle:@"Shows an alert before pull-to-refresh reloads the messages list" defaultsKey:@"dm_refresh_confirm"],
            [SCISetting switchCellWithTitle:@"No Suggested Chats" subtitle:@"Hides the suggested broadcast channels in direct messages" defaultsKey:@"no_suggested_chats"],
            [SCISetting switchCellWithTitle:@"Hide Reels Blend Button" subtitle:@"Hides the button in DMs that opens a reels blend" defaultsKey:@"hide_reels_blend"]
        ], nil),
        SCITopicSection(@"Visual Messages", @[
            [SCISetting switchCellWithTitle:@"Manually Mark Seen" subtitle:@"" defaultsKey:@"unlimited_replay"],
            [SCISetting switchCellWithTitle:@"Advance After Manual Seen" subtitle:@"After marking a visual message as seen, move to the next viewer item when available" defaultsKey:@"advance_direct_visual_when_marking_seen"],
            [SCISetting switchCellWithTitle:@"Disable View-Once Limitations" subtitle:@"Makes view-once messages behave like normal visual messages" defaultsKey:@"disable_view_once_limitations"],
            [SCISetting switchCellWithTitle:@"Disable Screenshot Detection" subtitle:@"" defaultsKey:@"remove_screenshot_alert"],
            [SCISetting switchCellWithTitle:@"Disable Instants Creation" subtitle:@"Hides the functionality to create or send instants" defaultsKey:@"disable_instants_creation" requiresRestart:YES]
        ], nil),
        SCITopicSection(@"Vanish Mode", @[
            [SCISetting switchCellWithTitle:@"Hide Vanish Screenshot Events" subtitle:@"Suppresses screenshot and screen-record callbacks while disappearing mode is active" defaultsKey:@"hide_vanish_screenshot"],
            [SCISetting switchCellWithTitle:@"Disable Swipe-Up to Enable" subtitle:@"Block swipe-up gesture to enable vanish mode" defaultsKey:@"disable_disappearing_swipe_up"],
        ], nil),
        SCITopicSection(@"Notes", @[
            [SCISetting switchCellWithTitle:@"Hide Notes Tray" subtitle:@"" defaultsKey:@"hide_notes_tray"],
            [SCISetting switchCellWithTitle:@"Hide Friends Map" subtitle:@"" defaultsKey:@"hide_friends_map"],
            [SCISetting switchCellWithTitle:@"Note Theming" subtitle:@"Enables the ability to use the notes theme picker" defaultsKey:@"enable_notes_customization"],
            [SCISetting switchCellWithTitle:@"Custom Note Themes" subtitle:@"Provides an option to set custom emojis and background or text colors" defaultsKey:@"custom_note_themes"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Call" subtitle:@"" defaultsKey:@"call_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Message Double Tap" subtitle:@"Shows an alert before double-tap liking a message" defaultsKey:@"dm_message_double_tap_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Message Reactions" subtitle:@"Shows an alert before sending a message reaction" defaultsKey:@"dm_message_reaction_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Voice Messages" subtitle:@"" defaultsKey:@"voice_message_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Follow Requests" subtitle:@"" defaultsKey:@"follow_request_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Vanish Mode" subtitle:@"" defaultsKey:@"shh_mode_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Changing Theme" subtitle:@"" defaultsKey:@"change_direct_theme_confirm"]
        ], nil)
    ]);
}

@end
