#import "SCIVaultSettingsViewController.h"
#import "SCIVaultDeleteViewController.h"
#import "SCIVaultManager.h"
#import "SCIVaultLockViewController.h"
#import "SCIVaultFile.h"
#import "SCIVaultCoreDataStack.h"
#import "../../Utils.h"

static NSString * const kFavoritesAtTopKey = @"show_favorites_at_top";

typedef NS_ENUM(NSInteger, SCIVaultStatsRow) {
    SCIVaultStatsRowTotal = 0,
    SCIVaultStatsRowImages,
    SCIVaultStatsRowVideos,
    SCIVaultStatsRowSize,
    SCIVaultStatsRowCount
};

typedef NS_ENUM(NSInteger, SCIVaultSettingsSection) {
    SCIVaultSettingsSectionStats = 0,
    SCIVaultSettingsSectionBrowsing,
    SCIVaultSettingsSectionLock,
    SCIVaultSettingsSectionShortcuts,
    SCIVaultSettingsSectionDelete,
    SCIVaultSettingsSectionCount
};

@interface SCIVaultStorageStats : NSObject
@property (nonatomic, assign) NSInteger totalFiles;
@property (nonatomic, assign) NSInteger imageCount;
@property (nonatomic, assign) NSInteger videoCount;
@property (nonatomic, assign) long long totalSize;
@end

@implementation SCIVaultStorageStats
@end

@interface SCIVaultSettingsViewController ()
@property (nonatomic, strong) SCIVaultStorageStats *stats;
@end

@implementation SCIVaultSettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Vault Settings";
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self reloadStats];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadStats];
    [self.tableView reloadData];
}

- (void)reloadStats {
    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    NSArray<SCIVaultFile *> *files = [ctx executeFetchRequest:req error:nil] ?: @[];

    SCIVaultStorageStats *stats = [SCIVaultStorageStats new];
    for (SCIVaultFile *file in files) {
        stats.totalFiles += 1;
        stats.totalSize += file.fileSize;
        if (file.mediaType == SCIVaultMediaTypeVideo) {
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
    return SCIVaultSettingsSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SCIVaultSettingsSectionStats: return @"Storage";
        case SCIVaultSettingsSectionBrowsing: return @"Browsing";
        case SCIVaultSettingsSectionLock: return @"Lock";
        case SCIVaultSettingsSectionShortcuts: return @"Shortcuts";
        case SCIVaultSettingsSectionDelete: return @"Delete";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case SCIVaultSettingsSectionBrowsing:
            return @"When enabled, favorites are pinned above other files inside the current sort and folder context.";
        case SCIVaultSettingsSectionLock:
            return @"When enabled, the Media Vault requires a passcode or biometrics to open.";
        case SCIVaultSettingsSectionShortcuts:
            return @"Long press Messages tab to open. Requires app restart to take effect.";
        default:
            return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SCIVaultSettingsSectionStats:
            return SCIVaultStatsRowCount;
        case SCIVaultSettingsSectionBrowsing:
            return 1;
        case SCIVaultSettingsSectionLock:
            return [SCIVaultManager sharedManager].isLockEnabled ? 2 : 1;
        case SCIVaultSettingsSectionShortcuts:
            return 1;
        case SCIVaultSettingsSectionDelete:
            return 1;
    }
    return 0;
}

- (UITableViewCell *)valueCellWithTitle:(NSString *)title value:(NSString *)value {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = title;
    cell.detailTextLabel.text = value;
    return cell;
}

- (UITableViewCell *)statsCellForRow:(NSInteger)row {
    switch (row) {
        case SCIVaultStatsRowTotal:
            return [self valueCellWithTitle:@"Total Files" value:[NSString stringWithFormat:@"%ld", (long)self.stats.totalFiles]];
        case SCIVaultStatsRowImages:
            return [self valueCellWithTitle:@"Images" value:[NSString stringWithFormat:@"%ld", (long)self.stats.imageCount]];
        case SCIVaultStatsRowVideos:
            return [self valueCellWithTitle:@"Videos" value:[NSString stringWithFormat:@"%ld", (long)self.stats.videoCount]];
        case SCIVaultStatsRowSize:
            return [self valueCellWithTitle:@"Total Size" value:[self formattedSize:self.stats.totalSize]];
    }
    return [self valueCellWithTitle:@"" value:@""];
}

- (void)configureBrowsingCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Show Favorites at Top";
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:kFavoritesAtTopKey];
    [sw addTarget:self action:@selector(favoritesAtTopSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
}

- (void)configureLockCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    SCIVaultManager *mgr = [SCIVaultManager sharedManager];
    if (row == 0) {
        cell.textLabel.text = @"Enable Passcode Lock";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = mgr.isLockEnabled;
        [sw addTarget:self action:@selector(lockSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        return;
    }

    cell.textLabel.text = @"Change Passcode";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)configureShortcutsCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Quick Media Vault Access";
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"header_long_press_vault"];
    [sw addTarget:self action:@selector(quickAccessSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
}

- (void)configureDeleteCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Delete Files";
    cell.textLabel.textColor = [UIColor systemRedColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SCIVaultSettingsSectionStats) {
        return [self statsCellForRow:indexPath.row];
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    switch (indexPath.section) {
        case SCIVaultSettingsSectionBrowsing:
            [self configureBrowsingCell:cell];
            break;
        case SCIVaultSettingsSectionLock:
            [self configureLockCell:cell atRow:indexPath.row];
            break;
        case SCIVaultSettingsSectionShortcuts:
            [self configureShortcutsCell:cell];
            break;
        case SCIVaultSettingsSectionDelete:
            [self configureDeleteCell:cell];
            break;
        default:
            break;
    }
    return cell;
}

- (void)favoritesAtTopSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kFavoritesAtTopKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SCIVaultFavoritesSortPreferenceChanged" object:nil];
}

- (void)lockSwitchChanged:(UISwitch *)sw {
    SCIVaultManager *mgr = [SCIVaultManager sharedManager];
    if (sw.on) {
        __weak typeof(self) weakSelf = self;
        [SCIVaultLockViewController presentMode:SCIVaultLockModeSetPasscode
                             fromViewController:self
                                     completion:^(BOOL success) {
            if (!success) {
                sw.on = NO;
            }
            [weakSelf.tableView reloadData];
        }];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Disable Passcode?"
                                                                  message:@"The vault will no longer require authentication to open."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        sw.on = YES;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Disable" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [mgr removePasscode];
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)quickAccessSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:@"header_long_press_vault"];
    [SCIUtils showRestartConfirmation];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == SCIVaultSettingsSectionLock && indexPath.row == 1) {
        [SCIVaultLockViewController presentMode:SCIVaultLockModeChangePasscode
                             fromViewController:self
                                     completion:^(BOOL success) {}];
        return;
    }

    if (indexPath.section == SCIVaultSettingsSectionDelete) {
        SCIVaultDeleteViewController *vc = [[SCIVaultDeleteViewController alloc] initWithMode:SCIVaultDeletePageModeRoot];
        __weak typeof(self) weakSelf = self;
        vc.onDidDelete = ^{
            [weakSelf reloadStats];
            [weakSelf.tableView reloadData];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SCIVaultFavoritesSortPreferenceChanged" object:nil];
        };
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end
