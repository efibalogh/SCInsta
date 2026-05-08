#import "SCIGalleryDeleteViewController.h"
#import "SCIGalleryCoreDataStack.h"
#import "SCIGalleryFile.h"
#import "../UI/SCIIGAlertPresenter.h"
#import "../../AssetUtils.h"
#import "../../Utils.h"

typedef NS_ENUM(NSInteger, SCIGalleryDeleteSection) {
    SCIGalleryDeleteSectionGlobal = 0,
    SCIGalleryDeleteSectionType,
    SCIGalleryDeleteSectionSource,
    SCIGalleryDeleteSectionUser,
    SCIGalleryDeleteSectionCount
};

@interface SCIGalleryDeleteAction : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, strong, nullable) NSPredicate *predicate;
@property (nonatomic, copy, nullable) NSString *successTitle;
@property (nonatomic, assign) BOOL navigatesToUsers;
@end

@implementation SCIGalleryDeleteAction
@end

@interface SCIGalleryDeleteUserItem : NSObject
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, assign) NSInteger count;
@end

@implementation SCIGalleryDeleteUserItem
@end

@interface SCIGalleryDeleteViewController ()
@property (nonatomic, assign) SCIGalleryDeletePageMode mode;
@property (nonatomic, strong) NSArray<NSArray<SCIGalleryDeleteAction *> *> *sections;
@property (nonatomic, strong) NSArray<SCIGalleryDeleteUserItem *> *users;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *countCache;
@end

@implementation SCIGalleryDeleteViewController

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SCIUtils SCIColor_InstagramPressedBackground];
    return view;
}

- (instancetype)initWithMode:(SCIGalleryDeletePageMode)mode {
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
    self.title = self.mode == SCIGalleryDeletePageModeRoot ? @"Delete Files" : @"Delete by User";
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

- (SCIGalleryDeleteAction *)actionWithTitle:(NSString *)title
                                 iconName:(NSString *)iconName
                                predicate:(nullable NSPredicate *)predicate
                             successTitle:(nullable NSString *)successTitle {
    SCIGalleryDeleteAction *action = [SCIGalleryDeleteAction new];
    action.title = title;
    action.iconName = iconName;
    action.predicate = predicate;
    action.successTitle = successTitle;
    return action;
}

- (void)reloadDataModel {
    if (self.mode == SCIGalleryDeletePageModeUsers) {
        [self reloadUsers];
        return;
    }

    self.sections = @[
        @[[self actionWithTitle:@"Delete All Files" iconName:@"trash" predicate:nil successTitle:@"All files deleted"]],
        @[
            [self actionWithTitle:@"Delete All Images" iconName:@"photo" predicate:[NSPredicate predicateWithFormat:@"mediaType == %d", SCIGalleryMediaTypeImage] successTitle:@"Images deleted"],
            [self actionWithTitle:@"Delete All Videos" iconName:@"video" predicate:[NSPredicate predicateWithFormat:@"mediaType == %d", SCIGalleryMediaTypeVideo] successTitle:@"Videos deleted"]
        ],
        @[
            [self actionWithTitle:@"Delete Feed Posts" iconName:@"feed" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIGallerySourceFeed] successTitle:@"Feed posts deleted"],
            [self actionWithTitle:@"Delete Stories" iconName:@"story" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIGallerySourceStories] successTitle:@"Stories deleted"],
            [self actionWithTitle:@"Delete Reels" iconName:@"reels" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIGallerySourceReels] successTitle:@"Reels deleted"],
            [self actionWithTitle:@"Delete Thumbnails" iconName:@"photo_gallery" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIGallerySourceThumbnail] successTitle:@"Thumbnails deleted"],
            [self actionWithTitle:@"Delete DM Media" iconName:@"messages" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIGallerySourceDMs] successTitle:@"DM media deleted"],
            [self actionWithTitle:@"Delete Profile Pictures" iconName:@"profile" predicate:[NSPredicate predicateWithFormat:@"source == %d", SCIGallerySourceProfile] successTitle:@"Profile pictures deleted"]
        ],
        @[]
    ];

    SCIGalleryDeleteAction *usersAction = [self actionWithTitle:@"Delete by User" iconName:@"users" predicate:nil successTitle:nil];
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
    NSManagedObjectContext *ctx = [SCIGalleryCoreDataStack shared].viewContext;
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (NSArray<SCIGalleryDeleteAction *> *section in self.sections) {
        for (SCIGalleryDeleteAction *action in section) {
            if (action.navigatesToUsers) {
                continue;
            }
            NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIGalleryFile"];
            req.predicate = action.predicate;
            NSInteger count = [ctx countForFetchRequest:req error:nil];
            counts[action.title] = @(MAX(count, 0));
        }
    }

    NSFetchRequest *distinctReq = [[NSFetchRequest alloc] initWithEntityName:@"SCIGalleryFile"];
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
    NSManagedObjectContext *ctx = [SCIGalleryCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIGalleryFile"];
    NSArray<SCIGalleryFile *> *files = [ctx executeFetchRequest:req error:nil] ?: @[];

    NSMutableDictionary<NSString *, SCIGalleryDeleteUserItem *> *items = [NSMutableDictionary dictionary];
    for (SCIGalleryFile *file in files) {
        NSString *username = [file.sourceUsername stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *key = username.length > 0 ? username : @"__unknown__";
        SCIGalleryDeleteUserItem *item = items[key];
        if (!item) {
            item = [SCIGalleryDeleteUserItem new];
            item.username = username.length > 0 ? username : nil;
            item.displayName = username.length > 0 ? username : @"Unknown User";
            items[key] = item;
        }
        item.count += 1;
    }

    self.users = [[items allValues] sortedArrayUsingComparator:^NSComparisonResult(SCIGalleryDeleteUserItem *lhs, SCIGalleryDeleteUserItem *rhs) {
        return [lhs.displayName localizedCaseInsensitiveCompare:rhs.displayName];
    }];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.mode == SCIGalleryDeletePageModeUsers) {
        return nil;
    }
    switch (section) {
        case SCIGalleryDeleteSectionGlobal: return nil;
        case SCIGalleryDeleteSectionType: return @"Delete by Type";
        case SCIGalleryDeleteSectionSource: return @"Delete by Source";
        case SCIGalleryDeleteSectionUser: return @"Delete by User";
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.mode == SCIGalleryDeletePageModeUsers ? 1 : self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.mode == SCIGalleryDeletePageModeUsers) {
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

    if (self.mode == SCIGalleryDeletePageModeUsers) {
        SCIGalleryDeleteUserItem *item = self.users[indexPath.row];
        cell.textLabel.text = item.displayName;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)item.count];
        cell.imageView.image = [SCIAssetUtils instagramIconNamed:@"profile" pointSize:22.0];
        return cell;
    }

    SCIGalleryDeleteAction *action = self.sections[indexPath.section][indexPath.row];
    cell.textLabel.text = action.title;
    NSNumber *count = self.countCache[action.title];
    if (count) {
        cell.detailTextLabel.text = count.integerValue > 0 ? [NSString stringWithFormat:@"%ld", (long)count.integerValue] : nil;
    }
    cell.imageView.image = [SCIAssetUtils instagramIconNamed:action.iconName pointSize:22.0];
    cell.accessoryType = action.navigatesToUsers ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.mode == SCIGalleryDeletePageModeUsers) {
        SCIGalleryDeleteUserItem *item = self.users[indexPath.row];
        NSPredicate *predicate = item.username.length > 0
            ? [NSPredicate predicateWithFormat:@"sourceUsername == %@", item.username]
            : [NSPredicate predicateWithFormat:@"sourceUsername == nil OR sourceUsername == ''"];
        NSString *title = [NSString stringWithFormat:@"Delete %@?", item.displayName];
        [self confirmDeleteWithTitle:title predicate:predicate successTitle:@"User files deleted"];
        return;
    }

    SCIGalleryDeleteAction *action = self.sections[indexPath.section][indexPath.row];
    if (action.navigatesToUsers) {
        SCIGalleryDeleteViewController *vc = [[SCIGalleryDeleteViewController alloc] initWithMode:SCIGalleryDeletePageModeUsers];
        vc.onDidDelete = self.onDidDelete;
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    [self confirmDeleteWithTitle:action.title predicate:action.predicate successTitle:action.successTitle ?: @"Files deleted"];
}

- (void)confirmDeleteWithTitle:(NSString *)title predicate:(nullable NSPredicate *)predicate successTitle:(NSString *)successTitle {
    NSManagedObjectContext *ctx = [SCIGalleryCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIGalleryFile"];
    req.predicate = predicate;
    NSArray<SCIGalleryFile *> *files = [ctx executeFetchRequest:req error:nil] ?: @[];
    if (files.count == 0) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionGalleryBulkDelete duration:2.0
                                 title:@"No files to delete"
                              subtitle:nil
                          iconResource:@"info_filled"
                                  tone:SCIFeedbackPillToneInfo];
        return;
    }

    NSString *message = [NSString stringWithFormat:@"This will permanently remove %ld file%@.", (long)files.count, files.count == 1 ? @"" : @"s"];
    [SCIIGAlertPresenter presentAlertFromViewController:self
                                                  title:title
                                                message:message
                                                actions:@[
        [SCIIGAlertAction actionWithTitle:@"Cancel" style:SCIIGAlertActionStyleCancel handler:nil],
        [SCIIGAlertAction actionWithTitle:@"Delete" style:SCIIGAlertActionStyleDestructive handler:^{
        NSFileManager *fm = [NSFileManager defaultManager];
        for (SCIGalleryFile *file in files) {
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
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionGalleryBulkDelete duration:2.0
                                 title:successTitle
                              subtitle:nil
                          iconResource:@"circle_check_filled"
                                  tone:SCIFeedbackPillToneSuccess];
    }],
    ]];
}

@end
