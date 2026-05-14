#import "SCIGallerySettingsProvider.h"
#import "../SCITopicSettingsSupport.h"
#import "../SCISetting.h"

#import "../../Utils.h"
#import "../../AssetUtils.h"

#import "../../Shared/Gallery/SCIGallerySettingsViewController.h"
#import "../../Shared/Gallery/SCIGalleryViewController.h"

static UICommand *SCIGalleryShortcutTargetCommand(NSString *title, NSString *value) {
    return [UICommand commandWithTitle:title
                                 image:nil
                                action:@selector(menuChanged:)
                          propertyList:@{
        @"defaultsKey": @"gallery_long_press_tab",
        @"value": value,
        @"requiresRestart": @YES
    }];
}

static UIMenu *SCIGalleryShortcutTargetMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIGalleryShortcutTargetCommand(@"Home", @"mainfeed-tab"),
        SCIGalleryShortcutTargetCommand(@"Reels", @"reels-tab"),
        SCIGalleryShortcutTargetCommand([SCIUtils tabOrderSetTo:@"classic"] ? @"Create" : @"Messages", @"direct-inbox-tab"),
        SCIGalleryShortcutTargetCommand(@"Profile", @"profile-tab")
    ]];
}

@implementation SCIGallerySettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Gallery", @"media", 24.0, @[
        SCITopicSection(@"Access", @[
            [SCISetting buttonCellWithTitle:@"Open Gallery"
                                   subtitle:@""
                                       icon:nil
                                     action:^(void) {
                [SCIGalleryViewController presentGallery];
            }],
            [SCISetting switchCellWithTitle:@"Quick Gallery Access" subtitle:@"Long press the selected tab" defaultsKey:@"header_long_press_gallery" requiresRestart:YES],
            [SCISetting menuCellWithTitle:@"Open from Tab" subtitle:@"Choose which tab opens Gallery" menu:SCIGalleryShortcutTargetMenu()]
        ], nil),
        SCITopicSection(@"Browsing", @[
            [SCISetting switchCellWithTitle:@"Show Favorites at Top"
                                   subtitle:@"Pin favorites above other files in the current sort and folder context"
                                       icon:[SCIAssetUtils instagramIconNamed:@"heart" pointSize:24.0]
                                defaultsKey:@"show_favorites_at_top"]
        ], nil),
        SCITopicSection(@"Lock & Maintenance", @[
            [SCISetting navigationCellWithTitle:@"Gallery Settings"
                                       subtitle:@"Manage passcode, import files, view storage, delete with options"
                                           icon:[SCIAssetUtils instagramIconNamed:@"settings" pointSize:24.0]
                                 viewController:[[SCIGallerySettingsViewController alloc] init]]
        ], nil)
    ]);
}

@end
