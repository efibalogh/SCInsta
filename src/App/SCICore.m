#import "SCICore.h"

#import "../Tweak.h"
#import "../Utils.h"
#import "SCIStartupHooks.h"
#import "SCIStartupProfiler.h"

static NSDictionary *SCIBootstrapDefaults(void) {
    return @{
        @"disable_safe_mode": @(NO),
        @"flex_app_launch": @(NO),
        @"flex_app_start": @(NO),
        @"flex_instagram": @(NO),
        @"liquid_glass_buttons": @(NO),
        @"liquid_glass_surfaces": @(NO),
        @"nav_icon_ordering": @"default",
        @"swipe_nav_tabs": @"default",
        @"hide_feed_tab": @(NO),
        @"hide_reels_tab": @(NO),
        @"hide_messages_tab": @(NO),
        @"hide_explore_tab": @(NO),
        @"hide_create_tab": @(NO),
        @"search_bar_open_clipboard_link": @(YES),
        @"settings_shortcut": @(NO),
        @"header_long_press_gallery": @(NO),
        @"gallery_long_press_tab": @"direct-inbox-tab",
        @"tweak_settings_app_launch": @(NO),
    };
}

static NSDictionary *SCIFeatureDefaults(void) {
    NSMutableDictionary *defaults = [@{
        @"hide_ads": @(YES),
        @"copy_description": @(YES),
        @"detailed_color_picker": @(YES),
        @"remove_screenshot_alert": @(YES),
        @"share_button_long_press_copy_link": @(YES),
        @"story_mark_seen_on_like": @(YES),
        @"story_mark_seen_on_reply": @(YES),
        @"advance_story_when_like_marked_seen": @(NO),
        @"advance_story_when_reply_marked_seen": @(NO),
        @"dm_refresh_confirm": @(YES),
        @"advance_direct_visual_when_marking_seen": @(NO),
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
        @"action_button_feed_action_download_gallery_enabled": @(YES),
        @"action_button_feed_action_download_all_library_enabled": @(YES),
        @"action_button_feed_action_download_all_share_enabled": @(YES),
        @"action_button_feed_action_download_all_gallery_enabled": @(YES),
        @"action_button_feed_action_download_all_clipboard_enabled": @(YES),
        @"action_button_feed_action_download_all_links_enabled": @(YES),
        @"action_button_feed_action_expand_enabled": @(YES),
        @"action_button_feed_action_view_thumbnail_enabled": @(YES),
        @"action_button_feed_action_copy_caption_enabled": @(YES),
        @"action_button_feed_action_open_topic_settings_enabled": @(YES),
        @"action_button_feed_action_repost_enabled": @(YES),
        @"action_button_reels_action_download_library_enabled": @(YES),
        @"action_button_reels_action_download_share_enabled": @(YES),
        @"action_button_reels_action_copy_download_link_enabled": @(YES),
        @"action_button_reels_action_download_gallery_enabled": @(YES),
        @"action_button_reels_action_download_all_library_enabled": @(YES),
        @"action_button_reels_action_download_all_share_enabled": @(YES),
        @"action_button_reels_action_download_all_gallery_enabled": @(YES),
        @"action_button_reels_action_download_all_clipboard_enabled": @(YES),
        @"action_button_reels_action_download_all_links_enabled": @(YES),
        @"action_button_reels_action_expand_enabled": @(YES),
        @"action_button_reels_action_view_thumbnail_enabled": @(YES),
        @"action_button_reels_action_copy_caption_enabled": @(YES),
        @"action_button_reels_action_open_topic_settings_enabled": @(YES),
        @"action_button_reels_action_repost_enabled": @(YES),
        @"action_button_stories_action_download_library_enabled": @(YES),
        @"action_button_stories_action_download_share_enabled": @(YES),
        @"action_button_stories_action_copy_download_link_enabled": @(YES),
        @"action_button_stories_action_download_gallery_enabled": @(YES),
        @"action_button_stories_action_download_all_library_enabled": @(YES),
        @"action_button_stories_action_download_all_share_enabled": @(YES),
        @"action_button_stories_action_download_all_gallery_enabled": @(YES),
        @"action_button_stories_action_download_all_clipboard_enabled": @(YES),
        @"action_button_stories_action_download_all_links_enabled": @(YES),
        @"action_button_stories_action_expand_enabled": @(YES),
        @"action_button_stories_action_view_thumbnail_enabled": @(YES),
        @"action_button_stories_action_open_topic_settings_enabled": @(YES),
        @"action_button_messages_action_download_library_enabled": @(YES),
        @"action_button_messages_action_download_share_enabled": @(YES),
        @"action_button_messages_action_copy_download_link_enabled": @(YES),
        @"action_button_messages_action_download_gallery_enabled": @(YES),
        @"action_button_messages_action_expand_enabled": @(YES),
        @"action_button_messages_action_view_thumbnail_enabled": @(YES),
        @"action_button_messages_action_open_topic_settings_enabled": @(YES),
        @"enable_long_press_expand": @(NO),
        @"expanded_video_start_muted": @(NO),
        @"story_mentions_button": @(YES),
        @"reels_tap_control": @"default",
        @"enable_notes_customization": @(YES),
        @"custom_note_themes": @(YES),
        @"disable_disappearing_swipe_up": @(NO),
        @"hide_vanish_screenshot": @(NO),
        @"disable_auto_unmuting_reels": @(YES),
        @"doom_scrolling_reel_count": @(1),
        @"disable_bg_refresh": @(NO),
        @"cache_auto_clear_mode": @"never",
        @"enhanced_media_resolution": @(NO),
        @"media_video_quality_default": @"always_ask",
        @"media_photo_quality_default": @"high",
        @"media_advanced_encoding_enabled": @(NO),
        @"media_encoding_speed": @"medium",
        @"media_encoding_video_codec": @"videotoolbox",
        @"media_encoding_preset": @"medium",
        @"media_encoding_h264_profile": @"high",
        @"media_encoding_h264_level": @"auto",
        @"media_encoding_crf": @"",
        @"media_encoding_video_bitrate_kbps": @"",
        @"media_encoding_max_resolution": @"original",
        @"media_encoding_audio_bitrate_kbps": @"128",
        @"media_encoding_audio_channels": @"original",
        @"media_encoding_pixel_format": @"default",
        @"media_encoding_faststart": @(YES),
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
        @"show_favorites_at_top": @(NO),
        @"remove_user_from_copied_share_link": @(YES),
        @"hide_create_group_button": @(NO)
    } mutableCopy];

    id legacyStoryInteraction = [[NSUserDefaults standardUserDefaults] objectForKey:@"story_mark_seen_on_interaction"];
    if ([legacyStoryInteraction respondsToSelector:@selector(boolValue)]) {
        NSNumber *legacyValue = @([legacyStoryInteraction boolValue]);
        defaults[@"story_mark_seen_on_like"] = legacyValue;
        defaults[@"story_mark_seen_on_reply"] = legacyValue;
    }

    return defaults;
}

void SCICoreRegisterBootstrapDefaults(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSUserDefaults standardUserDefaults] registerDefaults:SCIBootstrapDefaults()];
        SCIStartupMark(@"bootstrap defaults registered");
    });
}

void SCICoreRegisterDefaults(void) {
    SCICoreRegisterBootstrapDefaults();

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSUserDefaults standardUserDefaults] registerDefaults:SCIFeatureDefaults()];
        SCIStartupMark(@"feature defaults registered");
    });
}

void SCICoreInstallLaunchCriticalHooks(void) {
    SCICoreRegisterBootstrapDefaults();
    SCIInstallLaunchCriticalHooks();
}

void SCICoreInstallSurfaceHooks(SCISurface surface) {
    SCICoreRegisterDefaults();

    switch (surface) {
        case SCISurfaceGeneralUI:
            SCIInstallGeneralUIHooksIfNeeded();
            break;
        case SCISurfaceFeed:
            SCIInstallFeedSurfaceHooksIfNeeded();
            break;
        case SCISurfaceStories:
            SCIInstallStorySurfaceHooksIfNeeded();
            break;
        case SCISurfaceReels:
            SCIInstallReelsSurfaceHooksIfNeeded();
            break;
        case SCISurfaceMessages:
            SCIInstallMessagesSurfaceHooksIfNeeded();
            break;
        case SCISurfaceProfile:
            SCIInstallProfileSurfaceHooksIfNeeded();
            break;
    }
}

void SCICoreShowSettingsIfNeeded(UIWindow *window) {
    SCICoreRegisterDefaults();
    [SCIUtils showSettingsVC:window];
}
