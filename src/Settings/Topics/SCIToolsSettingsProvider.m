#import "SCIToolsSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "SCIInterfaceSettingsProvider.h"
#import "../SCISettingsTransferManager.h"
#import "../../Utils.h"

@implementation SCIToolsSettingsProvider

+ (SCISetting *)rootSetting {
    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        SCITopicSection(@"FLEX", @[
            [SCISetting switchCellWithTitle:@"Enable FLEX Gesture" subtitle:@"Allows you to hold five fingers on the screen to open the FLEX explorer" defaultsKey:@"flex_instagram"],
            [SCISetting switchCellWithTitle:@"Open FLEX on App Launch" subtitle:@"Automatically opens the FLEX explorer when the app launches" defaultsKey:@"flex_app_launch"],
            [SCISetting switchCellWithTitle:@"Open FLEX on App Focus" subtitle:@"Automatically opens the FLEX explorer when the app is focused" defaultsKey:@"flex_app_start"]
        ], nil),
        SCITopicSection(@"SCInsta", @[
            [SCISetting switchCellWithTitle:@"Enable Tweak Settings Quick Access" subtitle:@"Allows you to long-press the home tab to open SCInsta settings" defaultsKey:@"settings_shortcut" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Show Tweak Settings on App Launch" subtitle:@"Automatically opens the SCInsta settings when the app launches" defaultsKey:@"tweak_settings_app_launch"],
            [SCISetting buttonCellWithTitle:@"Reset Onboarding Completion State" subtitle:@"" icon:nil action:^(void) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SCInstaFirstRun"];
                [SCIUtils showRestartConfirmation];
            }]
        ], nil),
        SCITopicSection(@"Instagram", @[
            [SCISetting switchCellWithTitle:@"Disable Safe Mode" subtitle:@"Makes Instagram not reset settings after subsequent crashes, at your own risk" defaultsKey:@"disable_safe_mode"]
        ], nil),
        SCITopicSection(@"Backup & Transfer", @[
            [SCISetting buttonCellWithTitle:@"Export Settings + Vault" subtitle:@"Create a shareable archive that includes SCInsta settings and vault media" icon:nil action:^(void) {
                [[SCISettingsTransferManager sharedManager] exportSettingsAndVaultFromController:topMostController()];
            }],
            [SCISetting buttonCellWithTitle:@"Import Settings + Vault" subtitle:@"Restore settings and vault media from an exported archive. Vault lock is not restored." icon:nil action:^(void) {
                [[SCISettingsTransferManager sharedManager] importSettingsAndVaultFromController:topMostController()];
            }]
        ], nil),
        SCITopicSection(@"Liquid Glass", @[
            [SCIInterfaceSettingsProvider experimentalLiquidGlassSetting]
        ], nil)
    ]];

    [sections addObjectsFromArray:SCIDevExampleSections()];

    return SCITopicNavigationSetting(@"Tools", @"toolbox", 24.0, sections);
}

@end
