#import "SCIVaultDeleteViewController.h"
#import "SCIVaultCoreDataStack.h"
#import "SCIVaultFile.h"
#import "../../Utils.h"

typedef NS_ENUM(NSInteger, SCIVaultDeleteSection) {
    SCIVaultDeleteSectionGlobal = 0,
    SCIVaultDeleteSectionType,
    SCIVaultDeleteSectionSource,
    SCIVaultDeleteSectionUser,
    SCIVaultDeleteSectionCount
};

@interface SCIVaultDeleteAction : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, strong, nullable) NSPredicate *predicate;
@property (nonatomic, copy, nullable) NSString *successTitle;
@property (nonatomic, assign) BOOL navigatesToUsers;
@end

@implementation SCIVaultDeleteAction
@end

@interface SCIVaultDeleteUserItem : NSObject
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, assign) NSInteger count;
@end

@implementation SCIVaultDeleteUserItem
@end

@interface SCIVaultDeleteViewController ()
@property (nonatomic, assign) SCIVaultDeletePageMode mode;
@property (nonatomic, strong) NSArray<NSArray<SCIVaultDeleteAction *> *> *sections;
@property (nonatomic, strong) NSArray<SCIVaultDeleteUserItem *> *users;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *countCache;
@end

@implementation SCIVaultDeleteViewController

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SCIUtils SCIColor_InstagramPressedBackground];
    return view;
}

- (instancetype)initWithMode:(SCIVaultDeletePageMode)mode {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _mode = mode;
        _countCache = @{};
        _sections = @[];
        _users = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.mode == SCIVaultDeletePageModeRoot ? @"Delete Files" : @"Delete by User";
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
    self.tableView.tintColor = [SCIUtils SCIColor_Primary];
    [self reloadDataModel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadDataModel];
    [self.tableView reloadData];
}

- (UIImage *)iconNamed:(NSString *)resourceName fallback:(NSString *)fallback {
    UIImage *image = [SCIUtils sci_resourceImageNamed:resourceName template:YES maxPointSize:22.0];
    if (image) {
        return image;
    }
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightRegular];
    return [UIImage systemImageNamed:fallback withConfiguration:cfg];
}

- (SCIVaultDeleteAction *)actionWithTitle:(NSString *)title
                                 iconName:(NSString *)iconName
                                predicate:(nullable NSPredicate *)predicate
                             successTitle:(nullable NSString *)successTitle {
    SCIVaultDeleteAction *action = [SCIVaultDeleteAction new];
    action.title = title;
    action.iconName = iconName;
    action.predicate = predicate;
    action.successTitle = successTitle;
    return action;
}

- (void)reloadDataModel {
    if (self.mode == SCIVaultDeletePageModeUsers) {
        [self reloadUsers];
        return;
    }

    self.sections = @[
        @[[self actionWithTitle:@"Delete All Files" iconName:@"trash" predicate:nil successTitle:@"All files deleted"]],
        @[
            [self actionWithTitle:@"Delete All Images" iconName:@"photo" predicate:[NSPredicate predicateWithFormat:@"mediaType == %d", SCIVaultMediaTypeImage] successTitle:@"Images deleted"],
            [self actionWithTitle:@"Delete All Videos" iconName:@"video" predicate:[NSPredicate predicateWithFormat:@"mediaType == %d", SCIVaultMediaTypeVideo] successTitle:@"Videos deleted"]
        ],
        @[
            [self actionWithTitle:@"Delete Feed Posts" iconName:@"feed" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIVaultSourceFeed] successTitle:@"Feed posts deleted"],
            [self actionWithTitle:@"Delete Stories" iconName:@"story" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIVaultSourceStories] successTitle:@"Stories deleted"],
            [self actionWithTitle:@"Delete Reels" iconName:@"reels_prism" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIVaultSourceReels] successTitle:@"Reels deleted"],
            [self actionWithTitle:@"Delete Thumbnails" iconName:@"photo_gallery" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIVaultSourceThumbnail] successTitle:@"Thumbnails deleted"],
            [self actionWithTitle:@"Delete DM Media" iconName:@"messages" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIVaultSourceDMs] successTitle:@"DM media deleted"],
            [self actionWithTitle:@"Delete Profile Pictures" iconName:@"profile" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIVaultSourceProfile] successTitle:@"Profile pictures deleted"]
        ],
        @[]
    ];

    SCIVaultDeleteAction *usersAction = [self actionWithTitle:@"Delete by User" iconName:@"users" predicate:nil successTitle:nil];
    usersAction.navigatesToUsers = YES;
    self.sections = @[
        self.sections[0],
        self.sections[1],
        self.sections[2],
        @[usersAction]
    ];

    [self rebuildCountCache];
}

- (void)rebuildCountCache {
    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (NSArray<SCIVaultDeleteAction *> *section in self.sections) {
        for (SCIVaultDeleteAction *action in section) {
            if (action.navigatesToUsers) {
                continue;
            }
            NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
            req.predicate = action.predicate;
            NSInteger count = [ctx countForFetchRequest:req error:nil];
            counts[action.title] = @(MAX(count, 0));
        }
    }

    NSFetchRequest *distinctReq = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    distinctReq.resultType = NSDictionaryResultType;
    distinctReq.propertiesToFetch = @[@"sourceUsername"];
    distinctReq.returnsDistinctResults = YES;
    NSArray<NSDictionary *> *rows = [ctx executeFetchRequest:distinctReq error:nil] ?: @[];
    NSInteger userCount = 0;
    for (__unused NSDictionary *row in rows) {
        userCount += 1;
    }
    counts[@"Delete by User"] = @(userCount);
    self.countCache = counts;
}

- (void)reloadUsers {
    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    NSArray<SCIVaultFile *> *files = [ctx executeFetchRequest:req error:nil] ?: @[];

    NSMutableDictionary<NSString *, SCIVaultDeleteUserItem *> *items = [NSMutableDictionary dictionary];
    for (SCIVaultFile *file in files) {
        NSString *username = [file.sourceUsername stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *key = username.length > 0 ? username : @"__unknown__";
        SCIVaultDeleteUserItem *item = items[key];
        if (!item) {
            item = [SCIVaultDeleteUserItem new];
            item.username = username.length > 0 ? username : nil;
            item.displayName = username.length > 0 ? username : @"Unknown User";
            items[key] = item;
        }
        item.count += 1;
    }

    self.users = [[items allValues] sortedArrayUsingComparator:^NSComparisonResult(SCIVaultDeleteUserItem *lhs, SCIVaultDeleteUserItem *rhs) {
        return [lhs.displayName localizedCaseInsensitiveCompare:rhs.displayName];
    }];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.mode == SCIVaultDeletePageModeUsers) {
        return nil;
    }
    switch (section) {
        case SCIVaultDeleteSectionGlobal: return nil;
        case SCIVaultDeleteSectionType: return @"Delete by Type";
        case SCIVaultDeleteSectionSource: return @"Delete by Source";
        case SCIVaultDeleteSectionUser: return @"Delete by User";
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.mode == SCIVaultDeletePageModeUsers ? 1 : self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.mode == SCIVaultDeletePageModeUsers) {
        return self.users.count;
    }
    return self.sections[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    cell.textLabel.textColor = [SCIUtils SCIColor_InstagramDestructive];
    cell.detailTextLabel.text = nil;
    cell.detailTextLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.imageView.tintColor = [SCIUtils SCIColor_InstagramDestructive];

    if (self.mode == SCIVaultDeletePageModeUsers) {
        SCIVaultDeleteUserItem *item = self.users[indexPath.row];
        cell.textLabel.text = item.displayName;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)item.count];
        cell.imageView.image = [self iconNamed:@"profile" fallback:@"person.crop.circle"];
        return cell;
    }

    SCIVaultDeleteAction *action = self.sections[indexPath.section][indexPath.row];
    cell.textLabel.text = action.title;
    NSNumber *count = self.countCache[action.title];
    if (count) {
        cell.detailTextLabel.text = count.integerValue > 0 ? [NSString stringWithFormat:@"%ld", (long)count.integerValue] : nil;
    }
    cell.imageView.image = [self iconNamed:action.iconName fallback:@"trash"];
    cell.accessoryType = action.navigatesToUsers ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.mode == SCIVaultDeletePageModeUsers) {
        SCIVaultDeleteUserItem *item = self.users[indexPath.row];
        NSPredicate *predicate = item.username.length > 0
            ? [NSPredicate predicateWithFormat:@"sourceUsername == %@", item.username]
            : [NSPredicate predicateWithFormat:@"sourceUsername == nil OR sourceUsername == ''"];
        NSString *title = [NSString stringWithFormat:@"Delete %@?", item.displayName];
        [self confirmDeleteWithTitle:title predicate:predicate successTitle:@"User files deleted"];
        return;
    }

    SCIVaultDeleteAction *action = self.sections[indexPath.section][indexPath.row];
    if (action.navigatesToUsers) {
        SCIVaultDeleteViewController *vc = [[SCIVaultDeleteViewController alloc] initWithMode:SCIVaultDeletePageModeUsers];
        vc.onDidDelete = self.onDidDelete;
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    [self confirmDeleteWithTitle:action.title predicate:action.predicate successTitle:action.successTitle ?: @"Files deleted"];
}

- (void)confirmDeleteWithTitle:(NSString *)title predicate:(nullable NSPredicate *)predicate successTitle:(NSString *)successTitle {
    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    req.predicate = predicate;
    NSArray<SCIVaultFile *> *files = [ctx executeFetchRequest:req error:nil] ?: @[];
    if (files.count == 0) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionVaultBulkDelete duration:2.0
                                 title:@"No files to delete"
                              subtitle:nil
                          iconResource:@"info"
               fallbackSystemImageName:@"info.circle.fill"
                                  tone:SCIFeedbackPillToneInfo];
        return;
    }

    NSString *message = [NSString stringWithFormat:@"This will permanently remove %ld file%@.", (long)files.count, files.count == 1 ? @"" : @"s"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        NSFileManager *fm = [NSFileManager defaultManager];
        for (SCIVaultFile *file in files) {
            NSString *filePath = file.filePath;
            if ([fm fileExistsAtPath:filePath]) {
                [fm removeItemAtPath:filePath error:nil];
            }
            NSString *thumbPath = file.thumbnailPath;
            if ([fm fileExistsAtPath:thumbPath]) {
                [fm removeItemAtPath:thumbPath error:nil];
            }
            [ctx deleteObject:file];
        }
        [ctx save:nil];
        [self reloadDataModel];
        [self.tableView reloadData];
        if (self.onDidDelete) {
            self.onDidDelete();
        }
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionVaultBulkDelete duration:2.0
                                 title:successTitle
                              subtitle:nil
                          iconResource:@"circle_check_filled"
               fallbackSystemImageName:@"checkmark.circle.fill"
                                  tone:SCIFeedbackPillToneSuccess];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
