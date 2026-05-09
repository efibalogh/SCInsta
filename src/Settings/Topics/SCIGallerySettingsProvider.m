#import "SCIGallerySettingsProvider.h"
#import "../../Utils.h"

#import "../SCISetting.h"
#import "../SCITopicSettingsSupport.h"
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
        SCIGalleryShortcutTargetCommand(@"Create / Messages", @"direct-inbox-tab"),
        SCIGalleryShortcutTargetCommand(@"Profile", @"profile-tab")
    ]];
}

@implementation SCIGallerySettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Gallery", @"media", 24.0, @[
        SCITopicSection(@"Access", @[
            [SCISetting buttonCellWithTitle:@"Open Gallery"
                                   subtitle:@"Browse saved SCInsta media"
                                       icon:nil
                                     action:^(void) {
                [SCIGalleryViewController presentGallery];
            }],
            [SCISetting switchCellWithTitle:@"Quick Gallery Access" subtitle:@"Long press the selected tab to open Gallery" defaultsKey:@"header_long_press_gallery" requiresRestart:YES],
            [SCISetting menuCellWithTitle:@"Open from Tab" subtitle:@"Choose which tab opens Gallery on long press" menu:SCIGalleryShortcutTargetMenu()]
        ], nil),
        SCITopicSection(@"Browsing", @[
            [SCISetting switchCellWithTitle:@"Show Favorites at Top" subtitle:@"Pin favorites above other files in the current sort and folder context" defaultsKey:@"show_favorites_at_top"]
        ], nil),
        SCITopicSection(@"Lock & Maintenance", @[
            [SCISetting navigationCellWithTitle:@"Gallery Settings"
                                       subtitle:@"Enable passcode lock, change passcode, import files, view storage, or delete saved media"
                                           icon:nil
                                 viewController:[[SCIGallerySettingsViewController alloc] init]]
        ], nil)
    ]);
}

@end
