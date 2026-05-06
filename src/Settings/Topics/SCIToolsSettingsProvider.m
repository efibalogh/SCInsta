#import "SCIToolsSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "SCIInterfaceSettingsProvider.h"
#import "../SCISettingsTransferManager.h"
#import "../../Utils.h"

static NSArray *SCIExportBackupSections(void) {
    return @[
        SCITopicSection(@"", @[
            [SCISetting buttonCellWithTitle:@"Export Settings Only" subtitle:@"Create a backup with SCInsta settings only" icon:nil action:^(void) {
                [[SCISettingsTransferManager sharedManager] exportFromController:topMostController() includeSettings:YES includeGallery:NO];
            }],
            [SCISetting buttonCellWithTitle:@"Export Gallery Only" subtitle:@"Create a backup with Gallery media only" icon:nil action:^(void) {
                [[SCISettingsTransferManager sharedManager] exportFromController:topMostController() includeSettings:NO includeGallery:YES];
            }],
            [SCISetting buttonCellWithTitle:@"Export Settings + Gallery" subtitle:@"Create a backup with both settings and Gallery media" icon:nil action:^(void) {
                [[SCISettingsTransferManager sharedManager] exportFromController:topMostController() includeSettings:YES includeGallery:YES];
            }]
        ], nil)
    ];
}

static NSArray *SCIImportBackupSections(void) {
    return @[
        SCITopicSection(@"", @[
            [SCISetting buttonCellWithTitle:@"Import Settings Only" subtitle:@"Restore SCInsta settings from a backup file" icon:nil action:^(void) {
                [[SCISettingsTransferManager sharedManager] importFromController:topMostController() includeSettings:YES includeGallery:NO];
            }],
            [SCISetting buttonCellWithTitle:@"Import Gallery Only" subtitle:@"Restore Gallery media from a backup file" icon:nil action:^(void) {
                [[SCISettingsTransferManager sharedManager] importFromController:topMostController() includeSettings:NO includeGallery:YES];
            }],
            [SCISetting buttonCellWithTitle:@"Import Settings + Gallery" subtitle:@"Restore both settings and Gallery media from a backup file" icon:nil action:^(void) {
                [[SCISettingsTransferManager sharedManager] importFromController:topMostController() includeSettings:YES includeGallery:YES];
            }]
        ], @"A restart prompt appears after a successful import.")
    ];
}

@implementation SCIToolsSettingsProvider

+ (SCISetting *)rootSetting {
    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        SCITopicSection(@"FLEX", @[
            [SCISetting switchCellWithTitle:@"Enable 3-Finger FLEX Gesture" subtitle:@"Hold three fingers anywhere for 1.5 seconds to open the FLEX explorer" defaultsKey:@"flex_instagram"],
            [SCISetting switchCellWithTitle:@"Open FLEX on App Launch" subtitle:@"Automatically opens the FLEX explorer when the app launches" defaultsKey:@"flex_app_launch"],
            [SCISetting switchCellWithTitle:@"Open FLEX on App Focus" subtitle:@"Automatically opens the FLEX explorer when the app is focused" defaultsKey:@"flex_app_start"]
        ], @"The first time FLEX is opened in a session it can take a moment to initialize (especially with \"Open on App Focus\", which fires immediately at launch). Subsequent opens are instant."),
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
            [SCISetting navigationCellWithTitle:@"Export Backup" subtitle:@"Choose whether to include settings, Gallery media, or both" icon:nil navSections:SCIExportBackupSections()],
            [SCISetting navigationCellWithTitle:@"Import Backup" subtitle:@"Choose whether to restore settings, Gallery media, or both" icon:nil navSections:SCIImportBackupSections()]
        ], nil),
        SCITopicSection(@"Liquid Glass", @[
            [SCIInterfaceSettingsProvider experimentalLiquidGlassSetting]
        ], nil)
    ]];

    [sections addObjectsFromArray:SCIDevExampleSections()];

    return SCITopicNavigationSetting(@"Tools", @"toolbox", 24.0, sections);
}

@end
