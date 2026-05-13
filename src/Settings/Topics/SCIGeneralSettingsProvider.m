#import "SCIGeneralSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/MediaDownload/SCIMediaFFmpeg.h"
#import "../../Shared/MediaDownload/SCIMediaQualityManager.h"
#import "../../Utils.h"

@implementation SCIGeneralSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"General", @"settings", 24.0, @[
        SCITopicSection(@"Privacy & Links", @[
            [SCISetting switchCellWithTitle:@"Copy Description" subtitle:@"Long press on text fields" defaultsKey:@"copy_description"],
            [SCISetting switchCellWithTitle:@"Do Not Save Recent Searches" subtitle:@"Search bars will no longer save recent searches" defaultsKey:@"no_recent_searches"],
            [SCISetting switchCellWithTitle:@"Remove User from Copied Link" subtitle:@"Copy links without the username path or tracking parameters" defaultsKey:@"remove_user_from_copied_share_link"],
            [SCISetting switchCellWithTitle:@"Long Press Send to Copy Link" subtitle:@"Long press supported paperplane/send buttons to copy the current Instagram link" defaultsKey:@"share_button_long_press_copy_link"]
        ], nil),
        SCITopicSection(@"Recommendations", @[
            [SCISetting switchCellWithTitle:@"Hide Ads" subtitle:@"Removes all ads from the app" defaultsKey:@"hide_ads"],
            [SCISetting switchCellWithTitle:@"Hide Meta AI" subtitle:@"Hides the Meta AI buttons and related functionality" defaultsKey:@"hide_meta_ai"],
            [SCISetting switchCellWithTitle:@"No Suggested Users" subtitle:@"Hides all suggested users for you to follow outside your feed" defaultsKey:@"no_suggested_users"]
        ], nil),
        SCITopicSection(@"Media Saving", @[
            [SCISetting switchCellWithTitle:@"Enhanced Media Resolution" subtitle:@"Allows higher-resolution media downloads" defaultsKey:@"enhanced_media_resolution"],
            [SCISetting menuCellWithTitle:@"Default Video Quality" subtitle:@"Choose the default save/share quality for videos" menu:SCIMediaVideoQualityMenu()],
            [SCISetting menuCellWithTitle:@"Default Photo Quality" subtitle:@"Choose the default save/share quality for photos" menu:SCIMediaPhotoQualityMenu()],
            [SCISetting navigationCellWithTitle:@"Encoding Settings" subtitle:@"Default-mode speed plus advanced codec, preset, bitrate, CRF, and fast-start controls" icon:nil viewController:[SCIMediaQualityManager encodingSettingsViewController]],
            [SCISetting navigationCellWithTitle:@"View Encoding Logs" subtitle:@"Inspect or share recent FFmpeg loader, merge, and validation logs inside the app" icon:nil viewController:[SCIMediaFFmpeg logsViewController]]
        ], @"\"High\" prefers merged DASH when available. \"High (Ignore Dash)\" forces the best ready-to-play progressive file instead. \"Always Ask\" opens a quality selection sheet for each photo or video."),
        SCITopicSection(@"Storage", @[
            [SCISetting buttonCellWithTitle:@"Clear Cache Now" subtitle:@"Remove temporary caches immediately" icon:nil action:^(void) {
                [SCIUtils cleanCache];
                SCINotify(kSCINotificationSettingsClearCache, @"Cache cleared", nil, @"circle_check_filled", SCINotificationToneForIconResource(@"circle_check_filled"));
            }],
            [SCISetting menuCellWithTitle:@"Auto Clear Cache" subtitle:@"Choose when cache should be cleared automatically while using Instagram" menu:SCICacheAutoClearMenu()]
        ], @"Automatic clearing is checked whenever Instagram becomes active. \"Always\" clears on every foreground; the other modes clear only after enough time has elapsed."),
        SCITopicSection(@"App", @[
            [SCISetting switchCellWithTitle:@"Enable Teen App Icons" subtitle:@"When enabled, hold down on the Instagram logo to change the app icon" defaultsKey:@"teen_app_icons" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Disable App Haptics" subtitle:@"Disables haptics and vibrations within the Instagram app" defaultsKey:@"disable_haptics"]
        ], nil),
    ]);
}

@end
