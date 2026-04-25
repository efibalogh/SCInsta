#import "SCIVaultSettingsViewController.h"
#import "SCIVaultManager.h"
#import "SCIVaultLockViewController.h"
#import "SCIVaultFile.h"
#import "SCIVaultCoreDataStack.h"
#import "../../Utils.h"

typedef NS_ENUM(NSInteger, SCIVaultStatsRow) {
    SCIVaultStatsRowTotal = 0,
    SCIVaultStatsRowImages,
    SCIVaultStatsRowVideos,
    SCIVaultStatsRowSize,
    SCIVaultStatsRowCount
};

typedef NS_ENUM(NSInteger, SCIVaultSettingsSection) {
    SCIVaultSettingsSectionStats = 0,
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
@property (nonatomic, strong) NSDictionary<NSNumber *, NSNumber *> *countsBySource;
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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(dismissSelf)];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self reloadStats];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadStats];
    [self.tableView reloadData];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Stats

- (void)reloadStats {
    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    NSArray<SCIVaultFile *> *files = [ctx executeFetchRequest:req error:nil];

    SCIVaultStorageStats *s = [SCIVaultStorageStats new];
    NSMutableDictionary *bySource = [NSMutableDictionary new];

    for (SCIVaultFile *f in files) {
        s.totalFiles++;
        s.totalSize += f.fileSize;
        if (f.mediaType == SCIVaultMediaTypeVideo) s.videoCount++;
        else s.imageCount++;

        NSNumber *key = @(f.source);
        NSNumber *prev = bySource[key] ?: @0;
        bySource[key] = @(prev.integerValue + 1);
    }
    s.countsBySource = bySource;
    self.stats = s;
}

- (NSString *)formattedSize:(long long)bytes {
    return [NSByteCountFormatter stringFromByteCount:bytes countStyle:NSByteCountFormatterCountStyleFile];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SCIVaultSettingsSectionCount;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SCIVaultSettingsSectionStats:  return @"Storage";
        case SCIVaultSettingsSectionLock:   return @"Lock";
        case SCIVaultSettingsSectionShortcuts: return @"Shortcuts";
        case SCIVaultSettingsSectionDelete: return @"Delete";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == SCIVaultSettingsSectionLock) {
        return @"When enabled, the Media Vault requires a passcode or biometrics to open.";
    }
    if (section == SCIVaultSettingsSectionShortcuts) {
        return @"Quick access requires an app restart to take effect.";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SCIVaultSettingsSectionStats: return SCIVaultStatsRowCount;
        case SCIVaultSettingsSectionLock: {
            SCIVaultManager *mgr = [SCIVaultManager sharedManager];
            return mgr.isLockEnabled ? 2 : 1; // toggle, change passcode (if enabled)
        }
        case SCIVaultSettingsSectionShortcuts: return 1;
        case SCIVaultSettingsSectionDelete: return 3; // clear all, delete by type, delete by source
    }
    return 0;
}

- (UITableViewCell *)statsCellForRow:(NSInteger)row {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    switch (row) {
        case SCIVaultStatsRowTotal:
            cell.textLabel.text = @"Total files";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)self.stats.totalFiles];
            break;
        case SCIVaultStatsRowImages:
            cell.textLabel.text = @"Images";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)self.stats.imageCount];
            break;
        case SCIVaultStatsRowVideos:
            cell.textLabel.text = @"Videos";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)self.stats.videoCount];
            break;
        case SCIVaultStatsRowSize:
            cell.textLabel.text = @"Total size";
            cell.detailTextLabel.text = [self formattedSize:self.stats.totalSize];
            break;
    }
    return cell;
}

- (void)configureLockCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    SCIVaultManager *mgr = [SCIVaultManager sharedManager];
    if (row == 0) {
        cell.textLabel.text = @"Enable passcode lock";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = mgr.isLockEnabled;
        [sw addTarget:self action:@selector(lockSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else {
        cell.textLabel.text = @"Change passcode";
        cell.textLabel.textColor = [UIColor labelColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
}

- (void)configureDeleteCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.textColor = [UIColor systemRedColor];
    switch (row) {
        case 0: cell.textLabel.text = @"Clear entire vault"; break;
        case 1: cell.textLabel.text = @"Delete by type"; break;
        case 2: cell.textLabel.text = @"Delete by source"; break;
    }
}

- (void)configureShortcutsCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Enable quick media vault access";
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"header_long_press_vault"];
    [sw addTarget:self action:@selector(quickAccessSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
}

#pragma mark - Render stats with Value1 style

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SCIVaultSettingsSectionStats) {
        return [self statsCellForRow:indexPath.row];
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.textColor = [UIColor labelColor];

    switch (indexPath.section) {
        case SCIVaultSettingsSectionLock:
            [self configureLockCell:cell atRow:indexPath.row];
            break;
        case SCIVaultSettingsSectionShortcuts:
            [self configureShortcutsCell:cell];
            break;
        case SCIVaultSettingsSectionDelete:
            [self configureDeleteCell:cell atRow:indexPath.row];
            break;
    }
    return cell;
}

#pragma mark - Actions

- (void)lockSwitchChanged:(UISwitch *)sw {
    SCIVaultManager *mgr = [SCIVaultManager sharedManager];
    if (sw.on) {
        // Enabling: prompt to set a passcode (in set mode, no existing passcode).
        __weak typeof(self) weakSelf = self;
        [SCIVaultLockViewController presentMode:SCIVaultLockModeSetPasscode
                             fromViewController:self
                                     completion:^(BOOL success) {
            if (!success) sw.on = NO;
            [weakSelf.tableView reloadData];
        }];
    } else {
        // Disabling: confirm and remove passcode.
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Disable Passcode?"
                                                                      message:@"The vault will no longer require authentication to open."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
            sw.on = YES;
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Disable" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [mgr removePasscode];
            [self.tableView reloadData];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)quickAccessSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:@"header_long_press_vault"];
    [SCIUtils showRestartConfirmation];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];

    if (ip.section == SCIVaultSettingsSectionLock) {
        if (ip.row == 1) {
            [SCIVaultLockViewController presentMode:SCIVaultLockModeChangePasscode
                                 fromViewController:self
                                         completion:^(BOOL success) { /* no-op */ }];
        }
        return;
    }

    if (ip.section == SCIVaultSettingsSectionDelete) {
        switch (ip.row) {
            case 0: [self confirmClearAll]; break;
            case 1: [self presentDeleteByType]; break;
            case 2: [self presentDeleteBySource]; break;
        }
    }
}

- (void)confirmClearAll {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear Entire Vault?"
                                                                  message:[NSString stringWithFormat:@"This will delete all %ld files (%@). This cannot be undone.",
                                                                           (long)self.stats.totalFiles,
                                                                           [self formattedSize:self.stats.totalSize]]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete All"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [self performDeleteWithPredicate:nil message:@"Vault cleared"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentDeleteByType {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Delete by Type"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Delete %ld Images", (long)self.stats.imageCount]
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [self performDeleteWithPredicate:[NSPredicate predicateWithFormat:@"mediaType == %d", SCIVaultMediaTypeImage]
                                 message:@"Images deleted"];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Delete %ld Videos", (long)self.stats.videoCount]
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [self performDeleteWithPredicate:[NSPredicate predicateWithFormat:@"mediaType == %d", SCIVaultMediaTypeVideo]
                                 message:@"Videos deleted"];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentDeleteBySource {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Delete by Source"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSNumber *> *sources = @[
        @(SCIVaultSourceFeed), @(SCIVaultSourceStories), @(SCIVaultSourceReels),
        @(SCIVaultSourceProfile), @(SCIVaultSourceDMs), @(SCIVaultSourceThumbnail), @(SCIVaultSourceOther),
    ];
    for (NSNumber *srcNum in sources) {
        SCIVaultSource src = (SCIVaultSource)srcNum.integerValue;
        NSInteger count = [self.stats.countsBySource[@(src)] integerValue];
        if (count == 0) continue;

        NSString *title = [NSString stringWithFormat:@"Delete %ld from %@", (long)count, [SCIVaultFile labelForSource:src]];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction *a) {
            [self performDeleteWithPredicate:[NSPredicate predicateWithFormat:@"source == %d", src]
                                     message:@"Files deleted"];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)performDeleteWithPredicate:(nullable NSPredicate *)predicate message:(NSString *)successMessage {
    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    req.predicate = predicate;

    NSError *err;
    NSArray<SCIVaultFile *> *files = [ctx executeFetchRequest:req error:&err];
    if (err) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    for (SCIVaultFile *f in files) {
        NSString *p = [f filePath];
        if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil];
        NSString *tp = [f thumbnailPath];
        if ([fm fileExistsAtPath:tp]) [fm removeItemAtPath:tp error:nil];
        [ctx deleteObject:f];
    }
    [ctx save:nil];

    [self reloadStats];
    [self.tableView reloadData];
}

@end
