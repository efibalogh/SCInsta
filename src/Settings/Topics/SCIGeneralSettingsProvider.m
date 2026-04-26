#import "SCIGeneralSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Utils.h"

@implementation SCIGeneralSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"General", @"settings", 24.0, @[
        SCITopicSection(@"Core", @[
            [SCISetting switchCellWithTitle:@"Hide Ads" subtitle:@"Removes all ads from the Instagram app" defaultsKey:@"hide_ads"],
            [SCISetting switchCellWithTitle:@"Hide Meta AI" subtitle:@"Hides the Meta AI buttons and related functionality within the app" defaultsKey:@"hide_meta_ai"],
            [SCISetting switchCellWithTitle:@"Copy Description" subtitle:@"Copy description text fields by long-pressing on them" defaultsKey:@"copy_description"],
            [SCISetting switchCellWithTitle:@"Do Not Save Recent Searches" subtitle:@"Search bars will no longer save your recent searches" defaultsKey:@"no_recent_searches"],
            [SCISetting switchCellWithTitle:@"Enhanced Media Resolution" subtitle:@"Increases the screen size reported to Instagram in outgoing requests, allowing higher-resolution media in feeds and downloads." defaultsKey:@"enhanced_media_resolution"]
        ], nil),
        SCITopicSection(@"Cache", @[
            [SCISetting buttonCellWithTitle:@"Clear Cache Now" subtitle:@"Remove temporary caches immediately" icon:nil action:^(void) {
                [SCIUtils cleanCache];
                [SCIUtils showToastForDuration:2.0 title:@"Cache cleared" subtitle:nil iconResource:@"circle_check_filled" fallbackSystemImageName:@"checkmark.circle.fill" tone:SCIFeedbackPillToneSuccess];
            }],
            [SCISetting menuCellWithTitle:@"Auto Clear Cache" subtitle:@"Choose when cache should be cleared automatically while using Instagram" menu:SCICacheAutoClearMenu()]
        ], @"Automatic clearing is checked whenever Instagram becomes active. \"Always\" clears on every foreground; the other modes clear only after enough time has elapsed."),
        SCITopicSection(@"Recommendations", @[
            [SCISetting switchCellWithTitle:@"No Suggested Users" subtitle:@"Hides all suggested users for you to follow outside your feed" defaultsKey:@"no_suggested_users"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Follow" subtitle:@"Shows an alert when you tap Follow to confirm the action" defaultsKey:@"follow_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Unfollow" subtitle:@"Shows an alert when you unfollow to confirm the action" defaultsKey:@"unfollow_confirm"]
        ], nil),
        SCITopicSection(@"Liquid Glass", @[
            [SCISetting switchCellWithTitle:@"Enable Liquid Glass Buttons" subtitle:@"Enables experimental liquid glass buttons within the app" defaultsKey:@"liquid_glass_buttons" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Enable Liquid Glass Surfaces" subtitle:@"Enables liquid glass for menus and other surfaces, and updates Instagram's related liquid glass override defaults." defaultsKey:@"liquid_glass_surfaces" requiresRestart:YES]
        ], nil)
    ]);
}

@end
