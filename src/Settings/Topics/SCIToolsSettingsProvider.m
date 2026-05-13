#import "SCIToolsSettingsProvider.h"
#include <UIKit/UIKit.h>

#import "../SCITopicSettingsSupport.h"
#import "SCIInterfaceSettingsProvider.h"
#import "../SCISettingsTransferManager.h"
#import "../../App/SCIFlexLoader.h"
#import "../../Utils.h"
#import "../../AssetUtils.h"

@interface SCISettingsTransferSelectionViewController : UITableViewController
@property (nonatomic, assign) BOOL importMode;
@property (nonatomic, assign) BOOL includeSettings;
@property (nonatomic, assign) BOOL includeGallery;
- (instancetype)initWithImportMode:(BOOL)importMode;
@end

@implementation SCISettingsTransferSelectionViewController

- (instancetype)initWithImportMode:(BOOL)importMode {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _importMode = importMode;
        _includeSettings = YES;
        _includeGallery = YES;
        self.title = importMode ? @"Import" : @"Export";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:(self.importMode ? @"Import" : @"Export")
                                                                              style:(UIBarButtonItemStyle)2 // done/prominent
                                                                             target:self
                                                                             action:@selector(runTransfer)];
    [self updateActionEnabled];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.importMode ? @"A restart prompt appears after a successful import." : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.selectedBackgroundView = [UIView new];
    cell.selectedBackgroundView.backgroundColor = [SCIUtils SCIColor_InstagramPressedBackground];
    UIListContentConfiguration *config = cell.defaultContentConfiguration;
    config.textProperties.color = [SCIUtils SCIColor_InstagramPrimaryText];
    config.secondaryTextProperties.color = [SCIUtils SCIColor_InstagramSecondaryText];
    BOOL selected = indexPath.row == 0 ? self.includeSettings : self.includeGallery;
    config.text = indexPath.row == 0 ? @"Settings" : @"Gallery";
    config.secondaryText = indexPath.row == 0 ? @"SCInsta preferences" : @"Gallery media and metadata";
    config.image = indexPath.row == 0 
        ? [SCIAssetUtils instagramIconNamed:@"settings" pointSize:22.0]
        : [SCIAssetUtils instagramIconNamed:@"media" pointSize:22.0];
    config.imageProperties.tintColor = [SCIUtils SCIColor_InstagramPrimaryText];
    cell.contentConfiguration = config;
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        self.includeSettings = !self.includeSettings;
    } else {
        self.includeGallery = !self.includeGallery;
    }
    [self updateActionEnabled];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)updateActionEnabled {
    self.navigationItem.rightBarButtonItem.enabled = self.includeSettings || self.includeGallery;
}

- (void)runTransfer {
    if (!(self.includeSettings || self.includeGallery)) return;
    UIViewController *presenter = self.navigationController ?: self;
    if (self.importMode) {
        [[SCISettingsTransferManager sharedManager] importFromController:presenter includeSettings:self.includeSettings includeGallery:self.includeGallery];
    } else {
        [[SCISettingsTransferManager sharedManager] exportFromController:presenter includeSettings:self.includeSettings includeGallery:self.includeGallery];
    }
}

@end

static NSArray *SCIManageSettingsDataSections(void) {
    return @[
        SCITopicSection(@"", @[
            SCISettingApplyIconTint([SCISetting navigationCellWithTitle:@"Export"
                                                                subtitle:@"Choose settings, Gallery, or both"
                                                                    icon:[SCIAssetUtils instagramIconNamed:@"arrow_up" pointSize:24.0]
                                                          viewController:[[SCISettingsTransferSelectionViewController alloc] initWithImportMode:NO]],
                                  [SCIUtils SCIColor_InstagramPrimaryText]),
            SCISettingApplyIconTint([SCISetting navigationCellWithTitle:@"Import"
                                                                subtitle:@"Choose settings, Gallery, or both"
                                                                    icon:[SCIAssetUtils instagramIconNamed:@"arrow_down" pointSize:24.0]
                                                          viewController:[[SCISettingsTransferSelectionViewController alloc] initWithImportMode:YES]],
                                  [SCIUtils SCIColor_InstagramPrimaryText])
        ], nil)
    ];
}

@implementation SCIToolsSettingsProvider

+ (SCISetting *)rootSetting {
    BOOL flexInstalled = SCIFlexIsBundled();
    NSString *flexFooter = flexInstalled
        ? @"The first time FLEX is opened in a session it can take a moment to initialize."
        : @"FLEX not installed. Rebuild with \"--flex\" flag or install libFLEX.dylib to enable these options.";
    SCISetting *flexGesture = [SCISetting switchCellWithTitle:@"Enable 3-Finger FLEX Gesture" subtitle:@"Hold three fingers anywhere for 1.5 seconds to open the FLEX explorer" defaultsKey:@"flex_instagram"];
    SCISetting *flexLaunch = [SCISetting switchCellWithTitle:@"Open FLEX on App Launch" subtitle:@"Automatically opens the FLEX explorer when the app launches" defaultsKey:@"flex_app_launch"];
    SCISetting *flexFocus = [SCISetting switchCellWithTitle:@"Open FLEX on App Focus" subtitle:@"Automatically opens the FLEX explorer when the app is focused" defaultsKey:@"flex_app_start"];
    if (!flexInstalled) {
        flexGesture.userInfo = @{@"enabled": @NO};
        flexLaunch.userInfo = @{@"enabled": @NO};
        flexFocus.userInfo = @{@"enabled": @NO};
    }
    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        SCITopicSection(@"FLEX", @[flexGesture, flexLaunch, flexFocus], flexFooter),
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
            [SCISetting navigationCellWithTitle:@"Manage Settings & Data" subtitle:@"Export or import settings, Gallery media, or both" icon:nil navSections:SCIManageSettingsDataSections()]
        ], nil),
        SCITopicSection(@"Liquid Glass", @[
            [SCISetting switchCellWithTitle:@"Enable Liquid Glass Buttons" subtitle:@"Enables experimental liquid glass buttons within the app" defaultsKey:@"liquid_glass_buttons" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Enable Liquid Glass Surfaces" subtitle:@"Enables liquid glass for menus and other surfaces, and updates Instagram's related liquid glass override defaults." defaultsKey:@"liquid_glass_surfaces" requiresRestart:YES],
            [SCIInterfaceSettingsProvider experimentalLiquidGlassSetting]
        ], @"Experimental controls. Restart Instagram after changing Liquid Glass settings.")
    ]];

    [sections addObjectsFromArray:SCIDevExampleSections()];

    return SCITopicNavigationSetting(@"Tools", @"toolbox", 24.0, sections);
}

@end
