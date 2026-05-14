#import "SCIGeneralSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/MediaDownload/SCIMediaFFmpeg.h"
#import "../../Shared/MediaDownload/SCIMediaQualityManager.h"
#import "../../Utils.h"
#import "../../AssetUtils.h"

@implementation SCIGeneralSettingsProvider

+ (SCISetting *)rootSetting {
    BOOL ffmpegAvailable = [SCIMediaFFmpeg isAvailable];
    if (!ffmpegAvailable) {
        [[NSUserDefaults standardUserDefaults] setObject:@"high_ignore_dash" forKey:@"media_video_quality_default"];
    }

    SCISetting *videoQualitySetting = [SCISetting menuCellWithTitle:@"Default Video Quality"
                                                           subtitle:(ffmpegAvailable ? @"" : @"Requires FFmpegKit")
                                                               menu:SCIMediaVideoQualityMenu()];
    videoQualitySetting.userInfo = @{@"enabled": @(ffmpegAvailable)};

    SCISetting *encodingSettings = [SCISetting navigationCellWithTitle:@"Encoding Settings"
                                                              subtitle:(ffmpegAvailable ? @"Default-mode speed plus advanced codec, preset, bitrate, CRF, and fast-start controls" : @"Requires FFmpegKit")
                                                                  icon:nil
                                                        viewController:[SCIMediaQualityManager encodingSettingsViewController]];
    encodingSettings.userInfo = @{@"enabled": @(ffmpegAvailable)};

    SCISetting *encodingLogs = [SCISetting navigationCellWithTitle:@"View Encoding Logs"
                                                          subtitle:(ffmpegAvailable ? @"Inspect or share recent FFmpeg loader, merge, and validation logs inside the app" : @"Requires FFmpegKit")
                                                              icon:nil
                                                    viewController:[SCIMediaFFmpeg logsViewController]];
    encodingLogs.userInfo = @{@"enabled": @(ffmpegAvailable)};

    NSString *qualityFooter = ffmpegAvailable ? @"\"High\" merges DASH files for best quality. \"High (Ignore Dash)\" uses ready-to-play files. \"Always Ask\" prompts for selection." : @"FFmpegKit is required for video quality options and encoding features.";

    return SCITopicNavigationSetting(@"General", @"settings", 24.0, @[
        SCITopicSection(@"Behavior", @[
            [SCISetting switchCellWithTitle:@"Copy Description" subtitle:@"Long press on text fields" defaultsKey:@"copy_description"],
            [SCISetting switchCellWithTitle:@"Do Not Save Recent Searches" subtitle:@"Search bars will no longer save recent searches" defaultsKey:@"no_recent_searches"],
            [SCISetting switchCellWithTitle:@"Remove User from Copied Link" subtitle:@"Copy links without tracking parameters" defaultsKey:@"remove_user_from_copied_share_link"],
            [SCISetting switchCellWithTitle:@"Long Press Send to Copy Post Link" subtitle:@"" defaultsKey:@"share_button_long_press_copy_link"],
        ], nil),
        SCITopicSection(@"", @[
            [SCISetting switchCellWithTitle:@"Hide Create Group Button" subtitle:@"" defaultsKey:@"hide_create_group_button"],
            [SCISetting switchCellWithTitle:@"Confirm Create Group Button" subtitle:@"" defaultsKey:@"confirm_create_group_button"],
    ], nil),
        SCITopicSection(@"Recommendations", @[
            [SCISetting switchCellWithTitle:@"Hide Ads" subtitle:@"" defaultsKey:@"hide_ads"],
            [SCISetting switchCellWithTitle:@"Hide Meta AI" subtitle:@"Hides the Meta AI buttons and related functionality" defaultsKey:@"hide_meta_ai"],
            [SCISetting switchCellWithTitle:@"No Suggested Users" subtitle:@"Hides all suggested users for you to follow outside your feed" defaultsKey:@"no_suggested_users"]
        ], nil),
        SCITopicSection(@"Media Saving", @[
            [SCISetting switchCellWithTitle:@"Enhanced Media Resolution" subtitle:@"Allows higher-resolution media downloads" defaultsKey:@"enhanced_media_resolution"],
            [SCISetting menuCellWithTitle:@"Default Photo Quality" subtitle:@"" menu:SCIMediaPhotoQualityMenu()],
            videoQualitySetting,
            encodingSettings,
            encodingLogs
        ], qualityFooter),
        SCITopicSection(@"Storage", @[
            [SCISetting buttonCellWithTitle:@"Clear Cache" subtitle:@"" icon:[SCIAssetUtils instagramIconNamed:@"trash" pointSize:24.0] action:^(void) {
                [SCIUtils cleanCache];
                SCINotify(kSCINotificationSettingsClearCache, @"Cache cleared", nil, @"circle_check_filled", SCINotificationToneForIconResource(@"circle_check_filled"));
            }],
            [SCISetting menuCellWithTitle:@"Auto Clear Cache" subtitle:@"" icon:[SCIAssetUtils instagramIconNamed:@"clock" pointSize:24.0] menu:SCICacheAutoClearMenu()]
        ], @"Automatic clearing is checked whenever Instagram becomes active."),
        SCITopicSection(@"App", @[
            [SCISetting switchCellWithTitle:@"Change App Icon" subtitle:@"Hold down on the Instagram logo to bring up the app icon selection menu" defaultsKey:@"teen_app_icons" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Disable App Haptics" subtitle:@"Disables haptics and vibrations within the app" defaultsKey:@"disable_haptics"]
        ], nil),
    ]);
}

@end
