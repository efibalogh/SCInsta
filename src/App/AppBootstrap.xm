#import "../InstagramHeaders.h"
#import "../Tweak.h"
#import "../Utils.h"

%hook IGInstagramAppDelegate
- (_Bool)application:(UIApplication *)application willFinishLaunchingWithOptions:(id)arg2 {
    NSDictionary *sciDefaults = @{
        @"hide_ads": @(YES),
        @"copy_description": @(YES),
        @"detailed_color_picker": @(YES),
        @"remove_screenshot_alert": @(YES),
        @"like_confirm_feed": @(NO),
        @"like_confirm_stories": @(NO),
        @"call_confirm": @(YES),
        @"confirm_create_group_button": @(NO),
        @"keep_deleted_message": @(YES),
        @"profile_photo_zoom": @(YES),
        @"follow_indicator": @(NO),
        @"action_button_feed_enabled": @(NO),
        @"action_button_feed_default_action": @"none",
        @"action_button_reels_enabled": @(NO),
        @"action_button_reels_default_action": @"none",
        @"action_button_stories_enabled": @(NO),
        @"action_button_stories_default_action": @"none",
        @"action_button_messages_enabled": @(NO),
        @"action_button_messages_default_action": @"none",
        @"action_button_profile_enabled": @(YES),
        @"action_button_profile_default_action": @"none",
        @"action_button_feed_action_download_library_enabled": @(YES),
        @"action_button_feed_action_download_share_enabled": @(YES),
        @"action_button_feed_action_copy_download_link_enabled": @(YES),
        @"action_button_feed_action_download_vault_enabled": @(YES),
        @"action_button_feed_action_expand_enabled": @(YES),
        @"action_button_feed_action_view_thumbnail_enabled": @(YES),
        @"action_button_feed_action_copy_caption_enabled": @(YES),
        @"action_button_feed_action_open_topic_settings_enabled": @(YES),
        @"action_button_feed_action_repost_enabled": @(YES),
        @"action_button_reels_action_download_library_enabled": @(YES),
        @"action_button_reels_action_download_share_enabled": @(YES),
        @"action_button_reels_action_copy_download_link_enabled": @(YES),
        @"action_button_reels_action_download_vault_enabled": @(YES),
        @"action_button_reels_action_expand_enabled": @(YES),
        @"action_button_reels_action_view_thumbnail_enabled": @(YES),
        @"action_button_reels_action_copy_caption_enabled": @(YES),
        @"action_button_reels_action_open_topic_settings_enabled": @(YES),
        @"action_button_reels_action_repost_enabled": @(YES),
        @"action_button_stories_action_download_library_enabled": @(YES),
        @"action_button_stories_action_download_share_enabled": @(YES),
        @"action_button_stories_action_copy_download_link_enabled": @(YES),
        @"action_button_stories_action_download_vault_enabled": @(YES),
        @"action_button_stories_action_expand_enabled": @(YES),
        @"action_button_stories_action_view_thumbnail_enabled": @(YES),
        @"action_button_stories_action_open_topic_settings_enabled": @(YES),
        @"action_button_messages_action_download_library_enabled": @(YES),
        @"action_button_messages_action_download_share_enabled": @(YES),
        @"action_button_messages_action_copy_download_link_enabled": @(YES),
        @"action_button_messages_action_download_vault_enabled": @(YES),
        @"action_button_messages_action_expand_enabled": @(YES),
        @"action_button_messages_action_view_thumbnail_enabled": @(YES),
        @"action_button_messages_action_open_topic_settings_enabled": @(YES),
        @"enable_long_press_expand": @(NO),
        @"expanded_video_start_muted": @(NO),
        @"story_mentions_button": @(YES),
        @"reels_tap_control": @"default",
        @"nav_icon_ordering": @"default",
        @"swipe_nav_tabs": @"default",
        @"enable_notes_customization": @(YES),
        @"custom_note_themes": @(YES),
        @"disable_disappearing_swipe_up": @(NO),
        @"hide_vanish_screenshot": @(NO),
        @"disable_auto_unmuting_reels": @(YES),
        @"doom_scrolling_reel_count": @(1),
        @"disable_bg_refresh": @(NO),
        @"cache_auto_clear_mode": @"never",
        @"disable_home_button_refresh": @(NO),
        @"disable_reels_tab_refresh": @(NO),
        @"stop_story_auto_advance": @(NO),
        @"advance_story_when_marking_seen": @(NO),
        @"seen_auto_on_send": @(NO),
        @"repost_confirm_feed": @(NO),
        @"repost_confirm_reels": @(NO),
        @"hide_repost_button_feed": @(NO),
        @"hide_repost_button_reels": @(NO),
        @"story_poll_vote_counts": @(YES),
        @"search_bar_open_clipboard_link": @(YES),
        @"show_favorites_at_top": @(NO),
        @"remove_user_from_copied_share_link": @(YES),
        @"hide_create_group_button": @(NO)
    };
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:sciDefaults];

    [SCIUtils sci_normalizeLiquidGlassPreferences];

    if ([SCIUtils getBoolPref:@"liquid_glass_buttons"]) {
        [defaults setValue:@(YES) forKey:@"instagram.override.project.lucent.navigation"];
    } else {
        [defaults setValue:@(NO) forKey:@"instagram.override.project.lucent.navigation"];
    }

    if ([SCIUtils getBoolPref:@"liquid_glass_surfaces"]) {
        [defaults setBool:YES forKey:@"liquid_glass_override_enabled"];
        [defaults setBool:YES forKey:@"IGLiquidGlassOverrideEnabled"];
    } else {
        [defaults setBool:NO forKey:@"liquid_glass_override_enabled"];
        [defaults setBool:NO forKey:@"IGLiquidGlassOverrideEnabled"];
    }
    [SCIUtils applyLiquidGlassNavigationExperimentOverride];

    return %orig;
}

- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    %orig;

    double openDelay = [SCIUtils getBoolPref:@"tweak_settings_app_launch"] ? 0.0 : 5.0;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(openDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (
            ![[[NSUserDefaults standardUserDefaults] objectForKey:@"SCInstaFirstRun"] isEqualToString:SCIVersionString]
            || [SCIUtils getBoolPref:@"tweak_settings_app_launch"]
        ) {
            NSLog(@"[SCInsta] First run, initializing");
            NSLog(@"[SCInsta] Displaying SCInsta first-time settings modal");
            [SCIUtils showSettingsVC:[self window]];
        }
    });
    if ([SCIUtils getBoolPref:@"flex_app_launch"]) {
        [[objc_getClass("FLEXManager") sharedManager] showExplorer];
    }

    return true;
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;

    [SCIUtils evaluateAutomaticCacheClearIfNeeded];

    if ([SCIUtils getBoolPref:@"flex_app_start"]) {
        [[objc_getClass("FLEXManager") sharedManager] showExplorer];
    }
}
%end
