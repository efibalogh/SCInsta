#import "SCIGallerySettingsViewController.h"
#import "SCIGalleryDeleteViewController.h"
#import "SCIGalleryManager.h"
#import "SCIGalleryLockViewController.h"
#import "SCIGalleryImportViewController.h"
#import "SCIGalleryFile.h"
#import "SCIGalleryCoreDataStack.h"
#import "../UI/SCIIGAlertPresenter.h"
#import "../UI/SCISwitch.h"
#import "../../Utils.h"

static NSString * const kFavoritesAtTopKey = @"show_favorites_at_top";
static NSString * const kGalleryLongPressTabKey = @"gallery_long_press_tab";
static NSString * const kNavigationIconOrderingKey = @"nav_icon_ordering";

static BOOL SCIGalleryUsesClassicTabOrdering(void) {
    return [[[NSUserDefaults standardUserDefaults] stringForKey:kNavigationIconOrderingKey] isEqualToString:@"classic"];
}

static NSString *SCIGalleryResolvedShortcutTabIdentifier(NSString *identifier) {
    NSString *resolved = identifier.length > 0 ? identifier : @"direct-inbox-tab";
    BOOL usesClassic = SCIGalleryUsesClassicTabOrdering();
    if (usesClassic && [resolved isEqualToString:@"direct-inbox-tab"]) return @"camera-tab";
    if (!usesClassic && [resolved isEqualToString:@"camera-tab"]) return @"direct-inbox-tab";
    return resolved;
}

static NSArray<NSDictionary *> *SCIGalleryShortcutTargetItems(void) {
    NSMutableArray<NSDictionary *> *items = [@[
        @{@"title": @"Home", @"value": @"mainfeed-tab"},
        @{@"title": @"Reels", @"value": @"reels-tab"}
    ] mutableCopy];

    if (SCIGalleryUsesClassicTabOrdering()) {
        [items addObject:@{@"title": @"Create", @"value": @"camera-tab"}];
    } else {
        [items addObject:@{@"title": @"Messages", @"value": @"direct-inbox-tab"}];
    }

    [items addObject:@{@"title": @"Profile", @"value": @"profile-tab"}];
    return items;
}

static NSString *SCIGalleryShortcutTargetTitle(NSString *identifier) {
    NSString *resolved = SCIGalleryResolvedShortcutTabIdentifier(identifier);
    for (NSDictionary *item in SCIGalleryShortcutTargetItems()) {
        if ([item[@"value"] isEqualToString:resolved]) {
            return item[@"title"];
        }
    }
    return SCIGalleryUsesClassicTabOrdering() ? @"Create" : @"Messages";
}

typedef NS_ENUM(NSInteger, SCIGalleryStatsRow) {
    SCIGalleryStatsRowTotal = 0,
    SCIGalleryStatsRowImages,
    SCIGalleryStatsRowVideos,
    SCIGalleryStatsRowSize,
    SCIGalleryStatsRowCount
};

typedef NS_ENUM(NSInteger, SCIGallerySettingsSection) {
    SCIGallerySettingsSectionStats = 0,
    SCIGallerySettingsSectionBrowsing,
    SCIGallerySettingsSectionLock,
    SCIGallerySettingsSectionShortcuts,
    SCIGallerySettingsSectionImport,
    SCIGallerySettingsSectionDelete,
    SCIGallerySettingsSectionCount
};

@interface SCIGalleryStorageStats : NSObject
@property (nonatomic, assign) NSInteger totalFiles;
@property (nonatomic, assign) NSInteger imageCount;
@property (nonatomic, assign) NSInteger videoCount;
@property (nonatomic, assign) long long totalSize;
@end

@implementation SCIGalleryStorageStats
@end

@interface SCIGallerySettingsViewController ()
@property (nonatomic, strong) SCIGalleryStorageStats *stats;
@end

@implementation SCIGallerySettingsViewController

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SCIUtils SCIColor_InstagramPressedBackground];
    return view;
}

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Gallery Settings";
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
    self.tableView.tintColor = [SCIUtils SCIColor_Primary];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self reloadStats];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadStats];
    [self.tableView reloadData];
}

- (void)reloadStats {
    NSManagedObjectContext *ctx = [SCIGalleryCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIGalleryFile"];
    NSArray<SCIGalleryFile *> *files = [ctx executeFetchRequest:req error:nil] ?: @[];

    SCIGalleryStorageStats *stats = [SCIGalleryStorageStats new];
    for (SCIGalleryFile *file in files) {
        stats.totalFiles += 1;
        stats.totalSize += file.fileSize;
        if (file.mediaType == SCIGalleryMediaTypeVideo) {
            stats.videoCount += 1;
        } else {
            stats.imageCount += 1;
        }
    }
    self.stats = stats;
}

- (NSString *)formattedSize:(long long)bytes {
    return [NSByteCountFormatter stringFromByteCount:bytes countStyle:NSByteCountFormatterCountStyleFile];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SCIGallerySettingsSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SCIGallerySettingsSectionStats: return @"Storage";
        case SCIGallerySettingsSectionBrowsing: return @"Browsing";
        case SCIGallerySettingsSectionLock: return @"Lock";
        case SCIGallerySettingsSectionShortcuts: return @"Shortcuts";
        case SCIGallerySettingsSectionImport: return @"Import";
        case SCIGallerySettingsSectionDelete: return @"Delete";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case SCIGallerySettingsSectionBrowsing:
            return @"When enabled, favorites are pinned above other files inside the current sort and folder context.";
        case SCIGallerySettingsSectionLock:
            return @"When enabled, the Gallery requires a passcode or biometrics to open.";
        case SCIGallerySettingsSectionShortcuts:
            return @"Choose which tab opens Gallery on long press. Requires app restart to take effect.";
        case SCIGallerySettingsSectionImport:
            return @"Import from the Files app with full metadata (username, shortcode, URLs) so Open profile / Open original behave like saves from Instagram. Batch: set shared fields, Add files, then edit or merge per row.";
        default:
            return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SCIGallerySettingsSectionStats:
            return SCIGalleryStatsRowCount;
        case SCIGallerySettingsSectionBrowsing:
            return 1;
        case SCIGallerySettingsSectionLock:
            return [SCIGalleryManager sharedManager].isLockEnabled ? 2 : 1;
        case SCIGallerySettingsSectionShortcuts:
            return 2;
        case SCIGallerySettingsSectionImport:
            return 1;
        case SCIGallerySettingsSectionDelete:
            return 1;
    }
    return 0;
}

- (UITableViewCell *)valueCellWithTitle:(NSString *)title value:(NSString *)value {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    cell.textLabel.text = title;
    cell.textLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    cell.detailTextLabel.text = value;
    cell.detailTextLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
    return cell;
}

- (UITableViewCell *)statsCellForRow:(NSInteger)row {
    switch (row) {
        case SCIGalleryStatsRowTotal:
            return [self valueCellWithTitle:@"Total Files" value:[NSString stringWithFormat:@"%ld", (long)self.stats.totalFiles]];
        case SCIGalleryStatsRowImages:
            return [self valueCellWithTitle:@"Images" value:[NSString stringWithFormat:@"%ld", (long)self.stats.imageCount]];
        case SCIGalleryStatsRowVideos:
            return [self valueCellWithTitle:@"Videos" value:[NSString stringWithFormat:@"%ld", (long)self.stats.videoCount]];
        case SCIGalleryStatsRowSize:
            return [self valueCellWithTitle:@"Total Size" value:[self formattedSize:self.stats.totalSize]];
    }
    return [self valueCellWithTitle:@"" value:@""];
}

- (void)configureBrowsingCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Show Favorites at Top";
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    SCISwitch *sw = [[SCISwitch alloc] init];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:kFavoritesAtTopKey];
    [sw addTarget:self action:@selector(favoritesAtTopSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
}

- (void)configureLockCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    SCIGalleryManager *mgr = [SCIGalleryManager sharedManager];
    if (row == 0) {
        cell.textLabel.text = @"Enable Passcode Lock";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        SCISwitch *sw = [[SCISwitch alloc] init];
        sw.on = mgr.isLockEnabled;
        [sw addTarget:self action:@selector(lockSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        return;
    }

    cell.textLabel.text = @"Change Passcode";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)configureShortcutsCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Quick Gallery Access";
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    SCISwitch *sw = [[SCISwitch alloc] init];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"header_long_press_gallery"];
    [sw addTarget:self action:@selector(quickAccessSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
}

- (UIMenu *)galleryShortcutTargetMenuForButton:(UIButton *)button {
    NSString *saved = SCIGalleryResolvedShortcutTabIdentifier([[NSUserDefaults standardUserDefaults] stringForKey:kGalleryLongPressTabKey]);
    NSArray<NSDictionary *> *items = SCIGalleryShortcutTargetItems();
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    for (NSDictionary *item in items) {
        NSString *title = item[@"title"];
        NSString *value = item[@"value"];
        UIAction *action = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__unused UIAction *a) {
            [[NSUserDefaults standardUserDefaults] setObject:value forKey:kGalleryLongPressTabKey];
            [button setTitle:title forState:UIControlStateNormal];
            [SCIUtils showRestartConfirmation];
        }];
        action.state = [saved isEqualToString:value] ? UIMenuElementStateOn : UIMenuElementStateOff;
        [actions addObject:action];
    }
    return [UIMenu menuWithChildren:actions];
}

- (void)configureShortcutTargetCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Open from Tab";
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSString *title = SCIGalleryShortcutTargetTitle([[NSUserDefaults standardUserDefaults] stringForKey:kGalleryLongPressTabKey]);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.contentEdgeInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
    button.showsMenuAsPrimaryAction = YES;
    button.menu = [self galleryShortcutTargetMenuForButton:button];
    [button sizeToFit];
    cell.accessoryView = button;
}

- (void)configureImportCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Import from Files…";
    cell.textLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)configureDeleteCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Delete Files";
    cell.textLabel.textColor = [SCIUtils SCIColor_InstagramDestructive];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SCIGallerySettingsSectionStats) {
        return [self statsCellForRow:indexPath.row];
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    cell.textLabel.text = nil;
    cell.textLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    cell.detailTextLabel.text = nil;
    cell.detailTextLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    switch (indexPath.section) {
        case SCIGallerySettingsSectionBrowsing:
            [self configureBrowsingCell:cell];
            break;
        case SCIGallerySettingsSectionLock:
            [self configureLockCell:cell atRow:indexPath.row];
            break;
        case SCIGallerySettingsSectionShortcuts:
            if (indexPath.row == 0) {
                [self configureShortcutsCell:cell];
            } else {
                [self configureShortcutTargetCell:cell];
            }
            break;
        case SCIGallerySettingsSectionImport:
            [self configureImportCell:cell];
            break;
        case SCIGallerySettingsSectionDelete:
            [self configureDeleteCell:cell];
            break;
        default:
            break;
    }
    return cell;
}

- (void)favoritesAtTopSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kFavoritesAtTopKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SCIGalleryFavoritesSortPreferenceChanged" object:nil];
}

- (void)lockSwitchChanged:(UISwitch *)sw {
    SCIGalleryManager *mgr = [SCIGalleryManager sharedManager];
    if (sw.on) {
        __weak typeof(self) weakSelf = self;
        [SCIGalleryLockViewController presentMode:SCIGalleryLockModeSetPasscode
                             fromViewController:self
                                     completion:^(BOOL success) {
            if (!success) {
                sw.on = NO;
            }
            [weakSelf.tableView reloadData];
        }];
        return;
    }

    [SCIIGAlertPresenter presentAlertFromViewController:self
                                                  title:@"Disable Passcode"
                                                message:@"The gallery will no longer require authentication to open."
                                                actions:@[
        [SCIIGAlertAction actionWithTitle:@"Cancel" style:SCIIGAlertActionStyleCancel handler:^{
        sw.on = YES;
    }],
        [SCIIGAlertAction actionWithTitle:@"Disable" style:SCIIGAlertActionStyleDestructive handler:^{
        [mgr removePasscode];
        [self.tableView reloadData];
    }],
    ]];
}

- (void)quickAccessSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:@"header_long_press_gallery"];
    [SCIUtils showRestartConfirmation];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == SCIGallerySettingsSectionLock && indexPath.row == 1) {
        [SCIGalleryLockViewController presentMode:SCIGalleryLockModeChangePasscode
                             fromViewController:self
                                     completion:^(BOOL success) {}];
        return;
    }

    if (indexPath.section == SCIGallerySettingsSectionImport) {
        SCIGalleryImportViewController *vc = [[SCIGalleryImportViewController alloc] initWithDestinationFolderPath:self.importDestinationFolderPath];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if (indexPath.section == SCIGallerySettingsSectionDelete) {
        SCIGalleryDeleteViewController *vc = [[SCIGalleryDeleteViewController alloc] initWithMode:SCIGalleryDeletePageModeRoot];
        __weak typeof(self) weakSelf = self;
        vc.onDidDelete = ^{
            [weakSelf reloadStats];
            [weakSelf.tableView reloadData];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SCIGalleryFavoritesSortPreferenceChanged" object:nil];
        };
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end
