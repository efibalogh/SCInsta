#import "TweakSettings.h"

@interface SCITweakSettings ()
+ (NSArray *)sciFeatureSections;
@end

@implementation SCITweakSettings

// MARK: - Sections

///
/// This returns an array of sections, with each section consisting of a dictionary
///
/// `"title"`: The section title (leave blank for no title)
///
/// `"rows"`: An array of **SCISetting** classes, potentially containing a "navigationCellWithTitle" initializer to allow for nested setting pages.
///
/// `"footer`: The section footer (leave blank for no footer)

+ (NSArray *)sections {
    return [self sciFeatureSections];
}

+ (NSArray *)sciFeatureSections {
    return @[
        @{
            @"header": @"",
            @"rows": @[
                [SCISetting linkCellWithTitle:@"Donate" subtitle:@"Consider donating to support this tweak's development!" icon:[SCISymbol symbolWithName:@"heart.circle.fill" color:[UIColor systemPinkColor] size:20.0] url:@"https://ko-fi.com/SoCuul"]
            ]
        },
        @{
            @"header": @"",
            @"rows": @[
                [SCISetting navigationCellWithTitle:@"General"
                                           subtitle:@""
                                               icon:[SCISymbol resourceSymbolWithName:@"settings" color:[UIColor labelColor] size:24]
                                        navSections:@[@{
                                            @"header": @"Core",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide ads" subtitle:@"Removes all ads from the Instagram app" defaultsKey:@"hide_ads"],
                                                [SCISetting switchCellWithTitle:@"Hide Meta AI" subtitle:@"Hides the meta ai buttons/functionality within the app" defaultsKey:@"hide_meta_ai"],
                                                [SCISetting switchCellWithTitle:@"Copy description" subtitle:@"Copy description text fields by long-pressing on them" defaultsKey:@"copy_description"],
                                                [SCISetting switchCellWithTitle:@"Do not save recent searches" subtitle:@"Search bars will no longer save your recent searches" defaultsKey:@"no_recent_searches"],
                                                [SCISetting switchCellWithTitle:@"Enable liquid glass buttons" subtitle:@"Enables experimental liquid glass buttons within the app" defaultsKey:@"liquid_glass_buttons" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Enable liquid glass surfaces" subtitle:@"Enables liquid glass for other elements, such as menus. When on, also sets Instagram's liquid glass override defaults (liquid_glass_override_enabled / IGLiquidGlassOverrideEnabled)." defaultsKey:@"liquid_glass_surfaces" requiresRestart:YES],
                                            ]
                                        },
                                        @{
                                            @"header": @"Media",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Enhanced media resolution" subtitle:@"Increases the screen size reported to Instagram in outgoing requests (User-Agent), allowing higher-resolution media in feeds and downloads—especially on smaller devices." defaultsKey:@"enhanced_media_resolution"],
                                                [SCISetting switchCellWithTitle:@"Start expanded videos muted" subtitle:@"When enabled, expanded videos open muted. You can still unmute from player controls." defaultsKey:@"expanded_video_start_muted"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Recommendations",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"No suggested users" subtitle:@"Hides all suggested users for you to follow, outside your feed" defaultsKey:@"no_suggested_users"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Confirmation",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Confirm follow" subtitle:@"Shows an alert when you click the follow button to confirm the follow" defaultsKey:@"follow_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm unfollow" subtitle:@"Shows an alert when you click the unfollow button to confirm" defaultsKey:@"unfollow_confirm"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Action button",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Show action button" subtitle:@"Adds an action button to feed posts, reels, stories, and visual messages" defaultsKey:@"show_action_button"],
                                                [SCISetting menuCellWithTitle:@"Default tap action" subtitle:@"Tap runs this action. Long press opens the full menu" menu:[self menus][@"action_button_default_action"]],
                                                [SCISetting switchCellWithTitle:@"Enable long press to expand" subtitle:@"When enabled, long-pressing media in feed opens the expanded viewer" defaultsKey:@"enable_long_press_expand"]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Interface"
                                           subtitle:@""
                                               icon:[SCISymbol resourceSymbolWithName:@"interface" color:[UIColor labelColor] size:24]
                                        navSections:@[@{
                                            @"header": @"Navigation",
                                            @"rows": @[
                                                [SCISetting menuCellWithTitle:@"Icon order" subtitle:@"The order of the icons on the bottom navigation bar" menu:[self menus][@"nav_icon_ordering"]],
                                                [SCISetting menuCellWithTitle:@"Swipe between tabs" subtitle:@"Lets you swipe to switch between navigation bar tabs" menu:[self menus][@"swipe_nav_tabs"]],
                                            ]
                                        },
                                        @{
                                            @"header": @"Appearance",
                                            @"rows": @[
                                                [SCISetting menuCellWithTitle:@"Feedback pill style" subtitle:@"Neutral glass vs. tone-tinted pill chrome" menu:[self menus][@"feedback_pill_style"]],
                                                [SCISetting switchCellWithTitle:@"Enable teen app icons" subtitle:@"When enabled, hold down on the Instagram logo to change the app icon" defaultsKey:@"teen_app_icons" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Disable app haptics" subtitle:@"Disables haptics/vibrations within the Instagram app" defaultsKey:@"disable_haptics"],
                                            ]
                                        },
                                        @{
                                            @"header": @"",
                                            @"rows": @[
                                                [SCISetting navigationCellWithTitle:@"Liquid glass (experimental)"
                                                                           subtitle:@"Unsafe per-hook overrides; use General → Core for normal options"
                                                                               icon:[SCISymbol symbolWithName:@"exclamationmark.triangle.fill" color:[UIColor systemOrangeColor] size:24]
                                                                        navSections:@[@{
                                                    @"header": @"Unsafe / experimental",
                                                    @"footer": @"Restart Instagram after changes. These override Instagram's internal liquid-glass gates and may crash or mis-render UI. Prefer “Enable liquid glass surfaces / buttons” under General → Core. For the five launcher-driven surfaces below, leaving a switch unset follows Core “surfaces” (same as stock SCInsta before granular toggles). Icon bar and internal debugger unset always follow Instagram's stock value unless you override them here.",
                                                    @"rows": @[
                                                        [SCISetting switchCellWithTitle:@"In-app notifications (launcher)" subtitle:@"Forces liquid-glass styling for in-app notification surfaces when enabled; unset follows Core “surfaces”." defaultsKey:@"liquid_glass_in_app_notifications" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Context menus (launcher)" subtitle:@"Forces liquid-glass styling for context menus when enabled; unset follows Core “surfaces”." defaultsKey:@"liquid_glass_context_menus" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Toasts (launcher)" subtitle:@"Toast chrome from launcher config; unset follows Core “surfaces”." defaultsKey:@"liquid_glass_toasts" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Toast peek (launcher)" subtitle:@"Peek-style toast treatment; unset follows Core “surfaces”." defaultsKey:@"liquid_glass_toast_peek" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Alert dialogs (launcher)" subtitle:@"System-style alert dialogs gated by launcher; unset follows Core “surfaces”." defaultsKey:@"liquid_glass_alert_dialogs" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Icon bar buttons (launcher)" subtitle:@"Small icon strip / accessory controls; unset keeps Instagram's default (not tied to Core surfaces)." defaultsKey:@"liquid_glass_icon_bar_buttons" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Internal liquid glass debugger" subtitle:@"Enables Instagram's internal debugger entry points; unset keeps stock. High risk." defaultsKey:@"liquid_glass_internal_debugger" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"IGLiquidGlass +isEnabled" subtitle:@"Global IGLiquidGlass class gate; may affect many surfaces at once." defaultsKey:@"liquid_glass_core_class" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Navigation experiment: isEnabled" subtitle:@"IGLiquidGlassNavigationExperimentHelper shared state." defaultsKey:@"liquid_glass_nav_is_enabled" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Navigation experiment: isDefaultValueSet" subtitle:@"Whether IG considers the nav experiment default applied." defaultsKey:@"liquid_glass_nav_default_value_set" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Navigation experiment: home feed header" subtitle:@"Liquid glass on the main feed header chrome." defaultsKey:@"liquid_glass_nav_home_feed_header" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Internal swizzle toggle" subtitle:@"IGLiquidGlassSwizzleToggle; affects method swizzling used for liquid glass rollout." defaultsKey:@"liquid_glass_swizzle_toggle" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Badged navigation buttons" subtitle:@"Tab / nav buttons that show notification badges." defaultsKey:@"liquid_glass_badged_nav_button" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Unified video back button" subtitle:@"Back control in unified video viewer." defaultsKey:@"liquid_glass_video_back_button" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Unified video camera entry" subtitle:@"Camera entry control in unified video flow." defaultsKey:@"liquid_glass_video_camera_button" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Alert dialog action buttons" subtitle:@"Primary/secondary actions on IGDS alert dialogs." defaultsKey:@"liquid_glass_alert_dialog_actions" requiresRestart:YES],
                                                        [SCISetting switchCellWithTitle:@"Interactive liquid tab bar" subtitle:@"Replaces IGTabBar with IGLiquidGlassInteractiveTabBar and forces tab bar style; can break navigation." defaultsKey:@"liquid_glass_interactive_tab_bar" requiresRestart:YES],
                                                    ]
                                                }]]
                                            ]
                                        },
                                        @{
                                            @"header": @"Explore",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide explore posts grid" subtitle:@"Hides the grid of suggested posts on the explore/search tab" defaultsKey:@"hide_explore_grid"],
                                                [SCISetting switchCellWithTitle:@"Hide trending searches" subtitle:@"Hides the trending searches under the explore search bar" defaultsKey:@"hide_trending_searches"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Hide tabs",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide feed tab" subtitle:@"Hides the feed/home tab on the bottom navigation bar" defaultsKey:@"hide_feed_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Hide explore tab" subtitle:@"Hides the explore/search tab on the bottom navigation bar" defaultsKey:@"hide_explore_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Hide messages tab" subtitle:@"Hides the direct messages tab on the bottom navigation bar" defaultsKey:@"hide_messages_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Hide reels tab" subtitle:@"Hides the reels tab on the bottom navigation bar" defaultsKey:@"hide_reels_tab" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Hide create tab" subtitle:@"Hides the create tab on the bottom navigation bar" defaultsKey:@"hide_create_tab" requiresRestart:YES]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Feed"
                                           subtitle:@""
                                               icon:[SCISymbol resourceSymbolWithName:@"feed" color:[UIColor labelColor] size:24]
                                        navSections:@[@{
                                            @"header": @"Content",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide stories tray" subtitle:@"Hides the story tray at the top and within your feed" defaultsKey:@"hide_stories_tray"],
                                                [SCISetting switchCellWithTitle:@"Hide entire feed" subtitle:@"Removes all content from your home feed, including posts" defaultsKey:@"hide_entire_feed"],
                                                [SCISetting switchCellWithTitle:@"No suggested posts" subtitle:@"Removes suggested posts from your feed" defaultsKey:@"no_suggested_post"],
                                                [SCISetting switchCellWithTitle:@"No suggested for you" subtitle:@"Hides suggested accounts for you to follow" defaultsKey:@"no_suggested_account"],
                                                [SCISetting switchCellWithTitle:@"No suggested reels" subtitle:@"Hides suggested reels to watch" defaultsKey:@"no_suggested_reels"],
                                                [SCISetting switchCellWithTitle:@"No suggested threads posts" subtitle:@"Hides suggested threads posts" defaultsKey:@"no_suggested_threads"],
                                                [SCISetting switchCellWithTitle:@"Disable video autoplay" subtitle:@"Prevents videos on your feed from playing automatically" defaultsKey:@"disable_feed_autoplay"],
                                                [SCISetting switchCellWithTitle:@"Hide repost button" subtitle:@"Removes the repost button from feed posts" defaultsKey:@"hide_repost_button_feed"],
                                                [SCISetting switchCellWithTitle:@"Hide metrics" subtitle:@"Hides the metrics numbers under posts & reels (likes, comments, reshares, shares)" defaultsKey:@"hide_metrics"],
                                                [SCISetting switchCellWithTitle:@"Disable home tab tap refresh" subtitle:@"Prevents feed refresh when re-tapping the home tab button" defaultsKey:@"disable_home_button_refresh"],
                                                [SCISetting switchCellWithTitle:@"Disable background feed refresh" subtitle:@"Prevents Instagram from refreshing your home feed in the background" defaultsKey:@"disable_bg_refresh"]
                                            ]
                                        },
                                        @{
                                            @"header": @"Confirmation",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Confirm likes" subtitle:@"Shows an alert when you click the like button on feed posts to confirm the like" defaultsKey:@"like_confirm_feed"],
                                                [SCISetting switchCellWithTitle:@"Confirm repost" subtitle:@"Shows an alert when you click the repost button on feed posts to confirm before reposting" defaultsKey:@"repost_confirm_feed"],
                                                [SCISetting switchCellWithTitle:@"Confirm posting comment" subtitle:@"Shows an alert when you click the post comment button to confirm" defaultsKey:@"post_comment_confirm"]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Reels"
                                           subtitle:@""
                                               icon:[SCISymbol resourceSymbolWithName:@"reels_prism" color:[UIColor labelColor] size:24]
                                        navSections:@[@{
                                            @"header": @"Behavior",
                                            @"rows": @[
                                                [SCISetting menuCellWithTitle:@"Tap Controls" subtitle:@"Change what happens when you tap on a reel" menu:[self menus][@"reels_tap_control"]],
                                                [SCISetting switchCellWithTitle:@"Always show progress scrubber" subtitle:@"Forces the progress bar to appear on every reel" defaultsKey:@"reels_show_scrubber"],
                                                [SCISetting switchCellWithTitle:@"Disable auto-unmuting reels" subtitle:@"Prevents reels from unmuting when the volume/silent button is pressed" defaultsKey:@"disable_auto_unmuting_reels" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Confirm reel refresh" subtitle:@"Shows an alert when you trigger a reels refresh" defaultsKey:@"refresh_reel_confirm"],
                                                [SCISetting switchCellWithTitle:@"Disable reels tab tap refresh" subtitle:@"Prevents reels refresh when re-tapping the reels tab button" defaultsKey:@"disable_reels_tab_refresh"],
                                                [SCISetting switchCellWithTitle:@"Hide repost button" subtitle:@"Removes the repost button from reels" defaultsKey:@"hide_repost_button_reels"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Layout",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide reels header" subtitle:@"Hides the top navigation bar when watching reels" defaultsKey:@"hide_reels_header"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Limits",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Disable scrolling reels" subtitle:@"Prevents reels from being scrolled to the next video" defaultsKey:@"disable_scrolling_reels" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Prevent doom scrolling" subtitle:@"Limits the amount of reels available to scroll at any given time, and prevents refreshing" defaultsKey:@"prevent_doom_scrolling"],
                                                [SCISetting stepperCellWithTitle:@"Doom scrolling limit" subtitle:@"Only loads %@ %@" defaultsKey:@"doom_scrolling_reel_count" min:1 max:100 step:1 label:@"reels" singularLabel:@"reel"]
                                            ]
                                        },
                                        @{
                                            @"header": @"Confirmation",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Confirm like" subtitle:@"Shows an alert when you click the like button on reels to confirm the like" defaultsKey:@"like_confirm_reels"],
                                                [SCISetting switchCellWithTitle:@"Confirm repost" subtitle:@"Shows an alert when you click the repost button on reels to confirm before reposting" defaultsKey:@"repost_confirm_reels"]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Stories"
                                           subtitle:@""
                                               icon:[SCISymbol resourceSymbolWithName:@"story" color:[UIColor labelColor] size:24]
                                        navSections:@[@{
                                            @"header": @"Privacy & visibility",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Disable story seen receipt" subtitle:@"Prevents automatic story seen receipts and adds an eye button to mark the current story as seen manually" defaultsKey:@"no_seen_receipt"],
                                                [SCISetting switchCellWithTitle:@"Stop story auto advance" subtitle:@"Prevents stories from automatically moving to the next item after playback ends" defaultsKey:@"stop_story_auto_advance"],
                                                [SCISetting switchCellWithTitle:@"Advance when marked as seen" subtitle:@"After manually marking a story as seen with the eye button, advance to the next story" defaultsKey:@"advance_story_when_marking_seen"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Creation",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Use detailed color picker" subtitle:@"Long press on the eyedropper tool in stories to customize the text color more precisely" defaultsKey:@"detailed_color_picker"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Confirmation",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Confirm likes" subtitle:@"Shows an alert when you click the like button on stories to confirm the like" defaultsKey:@"like_confirm_stories"],
                                                [SCISetting switchCellWithTitle:@"Confirm sticker interaction" subtitle:@"Shows an alert when you click a sticker on someone's story to confirm the action" defaultsKey:@"sticker_interact_confirm"]
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Profile"
                                           subtitle:@""
                                               icon:[SCISymbol resourceSymbolWithName:@"profile" color:[UIColor labelColor] size:22]
                                        navSections:@[@{
                                            @"header": @"Profile picture",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Long press to expand photo" subtitle:@"When enabled, long-pressing a profile picture opens the full-size expanded view" defaultsKey:@"profile_photo_zoom"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Indicators",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Show following indicator" subtitle:@"Shows whether the profile user follows you" defaultsKey:@"follow_indicator"],
                                            ]
                                        }]
                ],
                [SCISetting navigationCellWithTitle:@"Messages"
                                           subtitle:@""
                                               icon:[SCISymbol resourceSymbolWithName:@"messages" color:[UIColor labelColor] size:24]
                                        navSections:@[@{
                                            @"header": @"Messages",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Keep deleted messages" subtitle:@"Saves deleted messages in chat conversations" defaultsKey:@"keep_deleted_message"],
                                                [SCISetting switchCellWithTitle:@"Manually mark messages as seen" subtitle:@"Adds a button to DM threads, which will mark messages as seen" defaultsKey:@"remove_lastseen"],
                                                [SCISetting switchCellWithTitle:@"Auto-seen on send" subtitle:@"Marks messages as seen automatically right after you send a message in the thread" defaultsKey:@"seen_auto_on_send"],
                                                [SCISetting switchCellWithTitle:@"Disable disappearing swipe-up" subtitle:@"Blocks swipe-up gesture paths used to enter/toggle disappearing mode" defaultsKey:@"disable_disappearing_swipe_up"],
                                                [SCISetting switchCellWithTitle:@"Disable typing status" subtitle:@"Prevents the typing indicator from being shown to others when you're typing in DMs" defaultsKey:@"disable_typing_status"],
                                                [SCISetting switchCellWithTitle:@"No suggested chats" subtitle:@"Hides the suggested broadcast channels in direct messages" defaultsKey:@"no_suggested_chats"],
                                                [SCISetting switchCellWithTitle:@"Hide reels blend button" subtitle:@"Hides the button in DMs to open a reels blend" defaultsKey:@"hide_reels_blend"]
                                            ]
                                        },
                                        @{
                                            @"header": @"Visual messages",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Unlimited replay of visual messages" subtitle:@"Replay direct visual messages unlimited times and mark them as seen manually with the eye button" defaultsKey:@"unlimited_replay"],
                                                [SCISetting switchCellWithTitle:@"Disable view-once limitations" subtitle:@"Makes view-once messages behave like normal visual messages (loopable/pauseable)" defaultsKey:@"disable_view_once_limitations"],
                                                [SCISetting switchCellWithTitle:@"Disable screenshot detection" subtitle:@"Removes the screenshot-prevention features for visual messages in DMs" defaultsKey:@"remove_screenshot_alert"],
                                                [SCISetting switchCellWithTitle:@"Hide vanish screenshot events" subtitle:@"Suppresses screenshot/screen-record callbacks while disappearing mode is active" defaultsKey:@"hide_vanish_screenshot"],
                                                [SCISetting switchCellWithTitle:@"Disable instants creation" subtitle:@"Hides the functionality to create/send instants" defaultsKey:@"disable_instants_creation" requiresRestart:YES]
                                            ]
                                        },
                                        @{
                                            @"header": @"Notes",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Hide notes tray" subtitle:@"Hides the notes tray in the dm inbox" defaultsKey:@"hide_notes_tray"],
                                                [SCISetting switchCellWithTitle:@"Hide friends map" subtitle:@"Hides the friends map icon in the notes tray" defaultsKey:@"hide_friends_map"],
                                                [SCISetting switchCellWithTitle:@"Enable note theming" subtitle:@"Enables the ability to use the notes theme picker" defaultsKey:@"enable_notes_customization"],
                                                [SCISetting switchCellWithTitle:@"Custom note themes" subtitle:@"Provides an option to set custom emojis and background/text colors" defaultsKey:@"custom_note_themes"],
                                            ]
                                        },
                                        @{
                                            @"header": @"Confirmation",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Confirm call" subtitle:@"Shows an alert when you click the audio/video call button to confirm before calling" defaultsKey:@"call_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm voice messages" subtitle:@"Shows an alert to confirm before sending a voice message" defaultsKey:@"voice_message_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm follow requests" subtitle:@"Shows an alert when you accept/decline a follow request" defaultsKey:@"follow_request_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm shh mode" subtitle:@"Shows an alert to confirm before toggling disappearing messages" defaultsKey:@"shh_mode_confirm"],
                                                [SCISetting switchCellWithTitle:@"Confirm changing theme" subtitle:@"Shows an alert when you change a chat theme to confirm" defaultsKey:@"change_direct_theme_confirm"],
                                            ]
                                        }]
                ],
                [SCISetting buttonCellWithTitle:@"Media Vault"
                                       subtitle:@""
                                           icon:[SCISymbol resourceSymbolWithName:@"media" color:[UIColor labelColor] size:24]
                                         action:^(void) { [SCIVaultViewController presentVault]; }
                ],
                [SCISetting navigationCellWithTitle:@"Debug"
                                           subtitle:@""
                                               icon:[SCISymbol resourceSymbolWithName:@"toolbox" color:[UIColor labelColor] size:24]
                                        navSections:@[@{
                                            @"header": @"FLEX",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Enable FLEX gesture" subtitle:@"Allows you to hold 5 fingers on the screen to open the FLEX explorer" defaultsKey:@"flex_instagram"],
                                                [SCISetting switchCellWithTitle:@"Open FLEX on app launch" subtitle:@"Automatically opens the FLEX explorer when the app launches" defaultsKey:@"flex_app_launch"],
                                                [SCISetting switchCellWithTitle:@"Open FLEX on app focus" subtitle:@"Automatically opens the FLEX explorer when the app is focused" defaultsKey:@"flex_app_start"]
                                            ]
                                        },
                                        @{
                                            @"header": @"SCInsta",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Enable tweak settings quick-access" subtitle:@"Allows you to hold on the home tab to open the SCInsta settings" defaultsKey:@"settings_shortcut" requiresRestart:YES],
                                                [SCISetting switchCellWithTitle:@"Show tweak settings on app launch" subtitle:@"Automatically opens the SCInsta settings when the app launches" defaultsKey:@"tweak_settings_app_launch"],
                                                [SCISetting buttonCellWithTitle:@"Reset onboarding completion state"
                                                                           subtitle:@""
                                                                               icon:nil
                                                                             action:^(void) { [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SCInstaFirstRun"]; [SCIUtils showRestartConfirmation];}
                                                ],
                                            ]
                                        },
                                        @{
                                            @"header": @"Instagram",
                                            @"rows": @[
                                                [SCISetting switchCellWithTitle:@"Disable safe mode" subtitle:@"Makes Instagram not reset settings after subsequent crashes (at your own risk)" defaultsKey:@"disable_safe_mode"]
                                            ]
                                        },
                                        @{
                                            @"header": @"_ Example",
                                            @"rows": @[
                                                [SCISetting staticCellWithTitle:@"Static Cell" subtitle:@"" icon:[SCISymbol symbolWithName:@"tablecells"]],
                                                [SCISetting switchCellWithTitle:@"Switch Cell" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell"],
                                                [SCISetting switchCellWithTitle:@"Switch Cell (Restart)" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell_restart" requiresRestart:YES],
                                                [SCISetting stepperCellWithTitle:@"Stepper cell" subtitle:@"I have %@%@" defaultsKey:@"test_stepper_cell" min:-10 max:1000 step:5.5 label:@"$" singularLabel:@"$"],
                                                [SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using icon" icon:[SCISymbol symbolWithName:@"link" color:[UIColor systemTealColor] size:20.0] url:@"https://google.com"],
                                                [SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using image" imageUrl:@"https://i.imgur.com/c9CbytZ.png" url:@"https://google.com"],
                                                [SCISetting buttonCellWithTitle:@"Button Cell"
                                                                           subtitle:@""
                                                                               icon:[SCISymbol symbolWithName:@"oval.inset.filled"]
                                                                             action:^(void) { [SCIUtils showConfirmation:^(void){}]; }
                                                ],
                                                [SCISetting menuCellWithTitle:@"Menu Cell" subtitle:@"Change the value on the right" menu:[self menus][@"test"]],
                                                [SCISetting navigationCellWithTitle:@"Navigation Cell"
                                                                           subtitle:@""
                                                                               icon:[SCISymbol symbolWithName:@"rectangle.stack"]
                                                                        navSections:@[@{
                                                                            @"header": @"",
                                                                            @"rows": @[]
                                                                        }]
                                                ]
                                            ],
                                            @"footer": @"_ Example"
                                        }
                                        ]]
                ]
        },
        @{
            @"header": @"Credits",
            @"rows": @[
                [SCISetting linkCellWithTitle:@"Developer" subtitle:@"SoCuul" imageUrl:@"https://i.imgur.com/c9CbytZ.png" url:@"https://socuul.dev"],
                [SCISetting linkCellWithTitle:@"View Repo" subtitle:@"View the tweak's source code on GitHub" imageUrl:@"https://i.imgur.com/BBUNzeP.png" url:@"https://github.com/SoCuul/SCInsta"]
            ],
            @"footer": [NSString stringWithFormat:@"SCInsta %@\n\nInstagram v%@", SCIVersionString, [SCIUtils IGVersionString]]
        }
    ];
}

// MARK: - Title

///
/// This is the title displayed on the initial settings page view controller
///

+ (NSString *)title {
    return @"SCInsta Settings";
}


// MARK: - Menus

///
/// This returns a dictionary where each key corresponds to a certain menu that can be displayed.
/// Each "propertyList"  item is an NSDictionary containing the following items:
///
/// `"defaultsKey"`: The key to save the selected value under in NSUserDefaults
///
/// `"value"`: A unique string corresponding to the menu item which is selected
///
/// `"requiresRestart"`: (optional) Causes a popup to appear detailing you have to restart to use these features
///

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

+ (NSDictionary *)menus {
    return @{
        @"action_button_default_action": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"None"
                                  image:[[SCISymbol resourceSymbolWithName:@"action_alt" color:[UIColor labelColor] size:18] image]
                                 action:@selector(menuChanged:)
                           propertyList:@{
                                @"defaultsKey": @"action_button_default_action",
                                @"value": @"none"
                            }
            ],
            [UICommand commandWithTitle:@"Download"
                                  image:[[SCISymbol resourceSymbolWithName:@"download" color:[UIColor labelColor] size:18] image]
                                 action:@selector(menuChanged:)
                           propertyList:@{
                                @"defaultsKey": @"action_button_default_action",
                                @"value": @"download_library"
                            }
            ],
            [UICommand commandWithTitle:@"Share"
                                  image:[[SCISymbol resourceSymbolWithName:@"share" color:[UIColor labelColor] size:18] image]
                                 action:@selector(menuChanged:)
                           propertyList:@{
                                @"defaultsKey": @"action_button_default_action",
                                @"value": @"download_share"
                            }
            ],
            [UICommand commandWithTitle:@"Copy Link"
                                  image:[[SCISymbol resourceSymbolWithName:@"link" color:[UIColor labelColor] size:18] image]
                                 action:@selector(menuChanged:)
                           propertyList:@{
                                @"defaultsKey": @"action_button_default_action",
                                @"value": @"copy_download_link"
                            }
            ],
            [UICommand commandWithTitle:@"Download to Vault"
                                  image:[[SCISymbol resourceSymbolWithName:@"media" color:[UIColor labelColor] size:18] image]
                                 action:@selector(menuChanged:)
                           propertyList:@{
                                @"defaultsKey": @"action_button_default_action",
                                @"value": @"download_vault"
                            }
            ],
            [UICommand commandWithTitle:@"Expand"
                                  image:[[SCISymbol resourceSymbolWithName:@"expand_alt" color:[UIColor labelColor] size:18] image]
                                 action:@selector(menuChanged:)
                           propertyList:@{
                                @"defaultsKey": @"action_button_default_action",
                                @"value": @"expand"
                            }
            ],
            [UICommand commandWithTitle:@"View Thumbnail"
                                  image:[[SCISymbol resourceSymbolWithName:@"photo" color:[UIColor labelColor] size:18] image]
                                 action:@selector(menuChanged:)
                           propertyList:@{
                                @"defaultsKey": @"action_button_default_action",
                                @"value": @"view_thumbnail"
                           }
            ],
        ]],

        @"reels_tap_control": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Default"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"reels_tap_control",
                                @"value": @"default",
                                @"requiresRestart": @YES
                            }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"Pause/Play"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"reels_tap_control",
                                                    @"value": @"pause",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Mute/Unmute"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"reels_tap_control",
                                                    @"value": @"mute",
                                                    @"requiresRestart": @YES
                                                }
                                ]
                            ]
            ]
        ]],

        @"nav_icon_ordering": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Default"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"nav_icon_ordering",
                                @"value": @"default",
                                @"requiresRestart": @YES
                            }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"Classic"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"nav_icon_ordering",
                                                    @"value": @"classic",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Standard"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"nav_icon_ordering",
                                                    @"value": @"standard",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Alternate"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"nav_icon_ordering",
                                                    @"value": @"alternate",
                                                    @"requiresRestart": @YES
                                                }
                                ]
                            ]
            ]
        ]],
        @"swipe_nav_tabs": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Default"
                                    image:nil
                                    action:@selector(menuChanged:)
                            propertyList:@{
                                @"defaultsKey": @"swipe_nav_tabs",
                                @"value": @"default",
                                @"requiresRestart": @YES
                            }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"Enabled"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"swipe_nav_tabs",
                                                    @"value": @"enabled",
                                                    @"requiresRestart": @YES
                                                }
                                ],
                                [UICommand commandWithTitle:@"Disabled"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"swipe_nav_tabs",
                                                    @"value": @"disabled",
                                                    @"requiresRestart": @YES
                                                }
                                ]
                            ]
            ]
        ]],
        @"feedback_pill_style": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:@"Clean"
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{
                               @"defaultsKey": @"feedback_pill_style",
                               @"value": @"clean"
                           }
            ],
            [UICommand commandWithTitle:@"Colorful"
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{
                               @"defaultsKey": @"feedback_pill_style",
                               @"value": @"colorful"
                           }
            ],
        ]],
        @"test": [UIMenu menuWithChildren:@[
            [UIMenu menuWithTitle:@""
                            image:nil
                        identifier:nil
                            options:UIMenuOptionsDisplayInline
                            children:@[
                                [UICommand commandWithTitle:@"ABC"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"test_menu_cell",
                                                    @"value": @"abc"
                                                }
                                ],
                                [UICommand commandWithTitle:@"123"
                                                        image:nil
                                                        action:@selector(menuChanged:)
                                                propertyList:@{
                                                    @"defaultsKey": @"test_menu_cell",
                                                    @"value": @"123"
                                                }
                                ]
                            ]
            ],
            [UICommand commandWithTitle:@"Requires restart"
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{
                               @"defaultsKey": @"test_menu_cell",
                               @"value": @"requires_restart",
                               @"requiresRestart": @YES
                           }
            ],
        ]]
    };
}

#pragma clang diagnostic pop

@end
