#import "SCIVaultViewController.h"
#import "SCIVaultFile.h"
#import "SCIVaultGridCell.h"
#import "SCIVaultListCollectionCell.h"
#import "SCIVaultFolderCell.h"
#import "SCIVaultCoreDataStack.h"
#import "SCIVaultManager.h"
#import "SCIVaultLockViewController.h"
#import "SCIVaultSortViewController.h"
#import "SCIVaultFilterViewController.h"
#import "SCIVaultSettingsViewController.h"
#import "SCIVaultDeleteViewController.h"
#import "SCIVaultOriginController.h"
#import "../MediaPreview/SCIFullScreenMediaPlayer.h"
#import "../UI/SCIMediaChrome.h"
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import <CoreData/CoreData.h>

static NSString * const kGridCellID = @"SCIVaultGridCell";
static NSString * const kListCellID = @"SCIVaultListCell";
static NSString * const kFolderCellID = @"SCIVaultFolderCell";

static NSString * const kSortModeKey    = @"scinsta_vault_sort_mode";
static NSString * const kViewModeKey    = @"scinsta_vault_view_mode"; // 0 = grid, 1 = list
static NSString * const kFavoritesAtTopKey = @"show_favorites_at_top";

static CGFloat const kGridSpacing = 2.0;
static NSInteger const kGridColumns = 3;
static CGFloat const kVaultMenuIconPointSize = 22.0;

static UIImage *SCIVaultMenuActionIcon(NSString *resourceName, NSString *systemName) {
    UIImage *img = resourceName.length > 0
        ? [SCIUtils sci_resourceImageNamed:resourceName template:YES maxPointSize:kVaultMenuIconPointSize]
        : nil;
    if (!img) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:kVaultMenuIconPointSize weight:UIImageSymbolWeightRegular];
        img = [UIImage systemImageNamed:systemName withConfiguration:cfg];
    }
    return img;
}

typedef NS_ENUM(NSInteger, SCIVaultViewMode) {
    SCIVaultViewModeGrid = 0,
    SCIVaultViewModeList = 1,
};

@interface SCIVaultViewController () <UICollectionViewDataSource,
                                       UICollectionViewDelegate,
                                       UICollectionViewDelegateFlowLayout,
                                       NSFetchedResultsControllerDelegate,
                                       SCIVaultSortViewControllerDelegate,
                                       SCIVaultFilterViewControllerDelegate,
                                       UIAdaptivePresentationControllerDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UILabel *emptyStateLabel;
/// Same chrome as media preview: blurred bar + equal-width icon buttons (not `UIToolbar`).
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong, nullable) UIStackView *bottomBarStack;

// Folder navigation
@property (nonatomic, copy, nullable) NSString *currentFolderPath;
@property (nonatomic, strong) NSArray<NSString *> *subfolders;

// View mode
@property (nonatomic, assign) SCIVaultViewMode viewMode;

// Sort
@property (nonatomic, assign) SCIVaultSortMode sortMode;

// Filter
@property (nonatomic, strong) NSMutableSet<NSNumber *> *filterTypes;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *filterSources;
@property (nonatomic, assign) BOOL filterFavoritesOnly;
@property (nonatomic, assign) BOOL selectionMode;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedFileIDs;

@end

@implementation SCIVaultViewController

#pragma mark - Presentation

+ (void)presentVault {
    UIViewController *presenter = topMostController();
    SCIVaultManager *mgr = [SCIVaultManager sharedManager];

    void (^presentVaultNav)(void) = ^{
        SCIVaultViewController *vc = [[SCIVaultViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:nav animated:YES completion:nil];
    };

    // Authenticate on the presenter (Instagram / settings) before any vault UI is shown,
    // so Face ID / passcode runs first with no flash of vault content.
    if (mgr.isLockEnabled && !mgr.isUnlocked) {
        [SCIVaultLockViewController presentUnlockFromViewController:presenter
                                                           completion:^(BOOL success) {
            if (!success) return;
            presentVaultNav();
        }];
    } else {
        presentVaultNav();
    }
}

#pragma mark - Init

- (instancetype)init {
    return [self initWithFolderPath:nil];
}

- (instancetype)initWithFolderPath:(NSString *)folderPath {
    if ((self = [super init])) {
        _currentFolderPath = [folderPath copy];
        _filterTypes = [NSMutableSet set];
        _filterSources = [NSMutableSet set];
        _filterFavoritesOnly = NO;
        _selectedFileIDs = [NSMutableSet set];

        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        _sortMode = (SCIVaultSortMode)[d integerForKey:kSortModeKey];
        _viewMode = (SCIVaultViewMode)[d integerForKey:kViewModeKey];
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleVaultPreferencesChanged:)
                                                 name:@"SCIVaultFavoritesSortPreferenceChanged"
                                               object:nil];

    [self setupCenteredTitle];
    [self setupNavigationItems];
    [self setupBottomToolbar];
    [self setupCollectionView];
    [self setupEmptyState];
    [self setupFetchedResultsController];
    [self reloadSubfolders];
    [self updateEmptyState];

    if (self.navigationController.viewControllers.firstObject == self) {
        self.navigationController.presentationController.delegate = self;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyVaultNavigationChrome];
    [self refreshNavigationItems];
    [self refreshBottomToolbarItems];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.navigationController.viewControllers.firstObject != self) return;
    if (self.isMovingFromParentViewController) return;
    if (self.isBeingDismissed || self.navigationController.isBeingDismissed) {
        if ([SCIVaultManager sharedManager].isLockEnabled) {
            [[SCIVaultManager sharedManager] lockVault];
        }
    }
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    if ([SCIVaultManager sharedManager].isLockEnabled) {
        [[SCIVaultManager sharedManager] lockVault];
    }
}

- (void)dismissSelf {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Navigation & chrome

/// Blurred bar + semantic colors (`labelColor` / `separatorColor`) — materials and dynamic colors track appearance automatically.
- (void)applyVaultNavigationChrome {
    UINavigationController *nav = self.navigationController;
    if (!nav) {
        return;
    }
    SCIApplyMediaChromeNavigationBar(nav.navigationBar);

    if ([self.navigationItem.titleView isKindOfClass:[UILabel class]]) {
        ((UILabel *)self.navigationItem.titleView).textColor = [UIColor labelColor];
    }
}

- (void)setupCenteredTitle {
    NSString *text = self.currentFolderPath.length > 0 ? [self.currentFolderPath lastPathComponent] : @"Media Vault";
    self.navigationItem.titleView = SCIMediaChromeTitleLabel(text);
}

- (void)setupNavigationItems {
    [self refreshNavigationItems];
}

- (void)refreshNavigationItems {
    if (self.selectionMode) {
        NSArray<SCIVaultFile *> *files = [self visibleVaultFiles];
        BOOL allSelected = files.count > 0 && self.selectedFileIDs.count == files.count;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(exitSelectionMode)];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:(allSelected ? @"Deselect All" : @"Select All")
                                                                                   style:UIBarButtonItemStylePlain
                                                                                  target:self
                                                                                  action:@selector(selectAllVisibleFiles)];
        return;
    }

    if (self.navigationController.viewControllers.firstObject == self) {
        self.navigationItem.leftBarButtonItem = SCIMediaChromeTopBarButtonItem(@"xmark", @"xmark", self, @selector(dismissSelf));
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }

    self.navigationItem.rightBarButtonItem = SCIMediaChromeTopBarButtonItem(@"settings", @"gear", self, @selector(pushSettings));
}

- (void)setupBottomToolbar {
    self.bottomBar = SCIMediaChromeInstallBottomBar(self.view);
    [self refreshBottomToolbarItems];
}

- (UIButton *)vaultBottomBarButtonWithSymbol:(NSString *)symbolName resource:(NSString *)resourceName accessibility:(NSString *)label {
    return SCIMediaChromeBottomButton(symbolName, resourceName, label);
}

- (UIButton *)vaultBottomBarButtonWithSymbol:(NSString *)symbolName accessibility:(NSString *)label {
    return [self vaultBottomBarButtonWithSymbol:symbolName resource:nil accessibility:label];
}

- (void)refreshBottomToolbarItems {
    [self.bottomBarStack removeFromSuperview];
    self.bottomBarStack = nil;

    if (self.selectionMode) {
        UIButton *shareBtn = [self vaultBottomBarButtonWithSymbol:@"square.and.arrow.up" resource:@"share" accessibility:@"Share selected"];
        [shareBtn addTarget:self action:@selector(shareSelectedFiles) forControlEvents:UIControlEventTouchUpInside];

        UIButton *moveBtn = [self vaultBottomBarButtonWithSymbol:@"folder" resource:@"folder_move" accessibility:@"Move selected"];
        [moveBtn addTarget:self action:@selector(moveSelectedFiles) forControlEvents:UIControlEventTouchUpInside];

        UIButton *favoriteBtn = [self vaultBottomBarButtonWithSymbol:@"heart" resource:@"heart" accessibility:@"Favorite selected"];
        [favoriteBtn addTarget:self action:@selector(toggleFavoriteForSelectedFiles) forControlEvents:UIControlEventTouchUpInside];

        UIButton *deleteBtn = [self vaultBottomBarButtonWithSymbol:@"trash" resource:@"trash" accessibility:@"Delete selected"];
        [deleteBtn addTarget:self action:@selector(deleteSelectedFiles) forControlEvents:UIControlEventTouchUpInside];
        deleteBtn.tintColor = [UIColor systemRedColor];

        self.bottomBarStack = SCIMediaChromeInstallBottomRow(self.bottomBar, @[shareBtn, moveBtn, favoriteBtn, deleteBtn]);
        return;
    }

    UIButton *filterBtn = [self vaultBottomBarButtonWithSymbol:@"line.3.horizontal.decrease" resource:@"filter" accessibility:@"Filter"];
    [filterBtn addTarget:self action:@selector(presentFilter) forControlEvents:UIControlEventTouchUpInside];

    UIButton *sortBtn = [self vaultBottomBarButtonWithSymbol:@"arrow.up.arrow.down" resource:@"sort" accessibility:@"Sort"];
    [sortBtn addTarget:self action:@selector(presentSort) forControlEvents:UIControlEventTouchUpInside];

    NSString *toggleSymbol = self.viewMode == SCIVaultViewModeGrid ? @"list.bullet" : @"square.grid.2x2";
    NSString *toggleResource = self.viewMode == SCIVaultViewModeGrid ? @"list" : @"grid";
    NSString *toggleAX = self.viewMode == SCIVaultViewModeGrid ? @"List view" : @"Grid view";
    UIButton *toggleBtn = [self vaultBottomBarButtonWithSymbol:toggleSymbol resource:toggleResource accessibility:toggleAX];
    [toggleBtn addTarget:self action:@selector(toggleViewMode) forControlEvents:UIControlEventTouchUpInside];

    UIButton *folderBtn = [self vaultBottomBarButtonWithSymbol:@"folder.badge.plus" resource:@"folder" accessibility:@"New folder"];
    [folderBtn addTarget:self action:@selector(presentCreateFolder) forControlEvents:UIControlEventTouchUpInside];

    UIButton *selectBtn = [self vaultBottomBarButtonWithSymbol:@"checkmark.circle" resource:@"circle_check" accessibility:@"Select"];
    [selectBtn addTarget:self action:@selector(enterSelectionMode) forControlEvents:UIControlEventTouchUpInside];

    NSArray<UIView *> *row = @[toggleBtn, sortBtn, filterBtn, folderBtn, selectBtn];

    self.bottomBarStack = SCIMediaChromeInstallBottomRow(self.bottomBar, row);
}

#pragma mark - Collection View

- (void)setupCollectionView {
    UICollectionViewLayout *layout = [self layoutForViewMode:self.viewMode];

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = [UIColor systemBackgroundColor];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.alwaysBounceVertical = YES;
    [_collectionView registerClass:[SCIVaultGridCell class] forCellWithReuseIdentifier:kGridCellID];
    [_collectionView registerClass:[SCIVaultListCollectionCell class] forCellWithReuseIdentifier:kListCellID];
    [_collectionView registerClass:[SCIVaultFolderCell class] forCellWithReuseIdentifier:kFolderCellID];
    [self.view addSubview:_collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [_collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.bottomBar.topAnchor],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (UICollectionViewLayout *)layoutForViewMode:(SCIVaultViewMode)mode {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    if (mode == SCIVaultViewModeGrid) {
        layout.minimumInteritemSpacing = kGridSpacing;
        layout.minimumLineSpacing = kGridSpacing;
    } else {
        layout.minimumInteritemSpacing = 0;
        layout.minimumLineSpacing = 0;
    }
    return layout;
}

- (void)toggleViewMode {
    if (self.selectionMode) {
        [self exitSelectionMode];
    }
    self.viewMode = self.viewMode == SCIVaultViewModeGrid ? SCIVaultViewModeList : SCIVaultViewModeGrid;
    [[NSUserDefaults standardUserDefaults] setInteger:self.viewMode forKey:kViewModeKey];

    UICollectionViewLayout *newLayout = [self layoutForViewMode:self.viewMode];
    [self.collectionView setCollectionViewLayout:newLayout animated:NO];
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self.collectionView reloadData];
    [self updateEmptyState];
    [self refreshBottomToolbarItems];
}

#pragma mark - Empty State

- (void)setupEmptyState {
    _emptyStateView = [[UIView alloc] initWithFrame:CGRectZero];
    _emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateView.hidden = YES;
    [self.view addSubview:_emptyStateView];

    UIImage *emptyIconImage = [SCIUtils sci_resourceImageNamed:@"photo_gallery" template:YES];
    if (!emptyIconImage) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:56 weight:UIImageSymbolWeightLight];
        emptyIconImage = [UIImage systemImageNamed:@"tray" withConfiguration:cfg];
    }
    UIImageView *icon = [[UIImageView alloc] initWithImage:emptyIconImage];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = [UIColor tertiaryLabelColor];
    [_emptyStateView addSubview:icon];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"No files in vault";
    label.textColor = [UIColor secondaryLabelColor];
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    [_emptyStateView addSubview:label];
    _emptyStateLabel = label;

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Save media from the preview screen\nto see it here.";
    subtitle.textColor = [UIColor tertiaryLabelColor];
    subtitle.font = [UIFont systemFontOfSize:14];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    [_emptyStateView addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [_emptyStateView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40],
        [_emptyStateView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-40],

        [icon.topAnchor constraintEqualToAnchor:_emptyStateView.topAnchor],
        [icon.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:64],
        [icon.heightAnchor constraintEqualToConstant:64],

        [label.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:20],
        [label.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],

        [subtitle.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:8],
        [subtitle.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],
        [subtitle.bottomAnchor constraintEqualToAnchor:_emptyStateView.bottomAnchor],
    ]];
}

- (void)updateEmptyState {
    NSInteger files = self.fetchedResultsController.fetchedObjects.count;
    NSInteger folders = self.subfolders.count;
    BOOL hasFilters = self.filterTypes.count > 0 || self.filterSources.count > 0 || self.filterFavoritesOnly;

    BOOL isEmpty = (files == 0 && folders == 0);
    self.emptyStateView.hidden = !isEmpty;
    self.collectionView.hidden = isEmpty;

    if (isEmpty && hasFilters) {
        self.emptyStateLabel.text = @"No matching files";
    } else {
        self.emptyStateLabel.text = @"No files in vault";
    }
}

#pragma mark - Fetched Results Controller

- (void)setupFetchedResultsController {
    NSFetchRequest *request = [self currentFetchRequest];

    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                    managedObjectContext:ctx
                                                                      sectionNameKeyPath:nil
                                                                               cacheName:nil];
    _fetchedResultsController.delegate = self;

    NSError *error;
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"[SCInsta Vault] Fetch failed: %@", error);
    }
}

- (NSFetchRequest *)currentFetchRequest {
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    NSMutableArray<NSSortDescriptor *> *sortDescriptors = [[SCIVaultSortViewController sortDescriptorsForMode:self.sortMode] mutableCopy];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kFavoritesAtTopKey] && !self.filterFavoritesOnly) {
        [sortDescriptors insertObject:[NSSortDescriptor sortDescriptorWithKey:@"isFavorite" ascending:NO] atIndex:0];
    }
    request.sortDescriptors = sortDescriptors;
    request.predicate = [SCIVaultFilterViewController predicateForTypes:self.filterTypes
                                                                sources:self.filterSources
                                                          favoritesOnly:self.filterFavoritesOnly
                                                             folderPath:self.currentFolderPath];
    return request;
}

- (void)refetch {
    if (self.selectionMode) {
        [self.selectedFileIDs removeAllObjects];
    }
    NSFetchRequest *request = [self currentFetchRequest];
    _fetchedResultsController.fetchRequest.sortDescriptors = request.sortDescriptors;
    _fetchedResultsController.fetchRequest.predicate = request.predicate;

    NSError *error;
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"[SCInsta Vault] Refetch failed: %@", error);
    }
    [self reloadSubfolders];
    [self.collectionView reloadData];
    [self updateEmptyState];
    [self refreshNavigationItems];
}

#pragma mark - Subfolders

- (void)reloadSubfolders {
    // Subfolders are derived from distinct `folderPath` values on files whose path
    // is a descendant of the current path.
    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    req.resultType = NSDictionaryResultType;
    req.propertiesToFetch = @[@"folderPath"];
    req.returnsDistinctResults = YES;

    NSString *base = self.currentFolderPath ?: @"";
    NSString *prefix = base.length == 0 ? @"/" : [base stringByAppendingString:@"/"];
    req.predicate = [NSPredicate predicateWithFormat:@"folderPath BEGINSWITH %@", prefix];

    NSArray<NSDictionary *> *results = [ctx executeFetchRequest:req error:nil];
    NSMutableSet<NSString *> *immediate = [NSMutableSet set];

    for (NSDictionary *row in results) {
        NSString *p = row[@"folderPath"];
        if (p.length <= prefix.length) continue;
        NSString *rest = [p substringFromIndex:prefix.length];
        NSRange slash = [rest rangeOfString:@"/"];
        NSString *folderName = slash.location == NSNotFound ? rest : [rest substringToIndex:slash.location];
        if (folderName.length == 0) continue;
        [immediate addObject:[prefix stringByAppendingString:folderName]];
    }

    self.subfolders = [[immediate allObjects] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    [self mergePlaceholderSubfolders];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self reloadSubfolders];
    [self.collectionView reloadData];
    [self updateEmptyState];
    [self refreshNavigationItems];
}

#pragma mark - UICollectionViewDataSource

- (BOOL)showsFolderSection {
    return self.viewMode == SCIVaultViewModeList;
}

- (BOOL)isFolderIndexPath:(NSIndexPath *)indexPath {
    return [self showsFolderSection] && indexPath.section == 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)cv {
    return [self showsFolderSection] ? 2 : 1;
}

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section {
    if ([self showsFolderSection] && section == 0) return self.subfolders.count;
    NSArray *sections = self.fetchedResultsController.sections;
    if (sections.count == 0) return 0;
    return ((id<NSFetchedResultsSectionInfo>)sections[0]).numberOfObjects;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)cv
                            cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isFolderIndexPath:indexPath]) {
        SCIVaultFolderCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kFolderCellID forIndexPath:indexPath];
        NSString *path = self.subfolders[indexPath.item];
        [cell configureWithFolderName:[path lastPathComponent]];
        return cell;
    }

    NSIndexPath *filePath = [NSIndexPath indexPathForItem:indexPath.item inSection:0];
    SCIVaultFile *file = [self.fetchedResultsController objectAtIndexPath:filePath];

    if (self.viewMode == SCIVaultViewModeGrid) {
        SCIVaultGridCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kGridCellID forIndexPath:indexPath];
        [cell configureWithVaultFile:file
                       selectionMode:self.selectionMode
                            selected:[self.selectedFileIDs containsObject:file.identifier]];
        return cell;
    }

    SCIVaultListCollectionCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kListCellID forIndexPath:indexPath];
    [cell configureWithVaultFile:file
                   selectionMode:self.selectionMode
                        selected:[self.selectedFileIDs containsObject:file.identifier]];
    [cell setMoreActionsMenu:self.selectionMode ? nil : [self fileActionsMenuForFile:file]];
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)cv
                  layout:(UICollectionViewLayout *)layout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = cv.bounds.size.width;
    if ([self isFolderIndexPath:indexPath]) {
        return CGSizeMake(width, 88);
    }
    if (self.viewMode == SCIVaultViewModeGrid) {
        CGFloat totalSpacing = kGridSpacing * (kGridColumns - 1);
        CGFloat side = (width - totalSpacing) / kGridColumns;
        return CGSizeMake(side, side);
    }
    return CGSizeMake(width, 88);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)cv
                        layout:(UICollectionViewLayout *)layout
        insetForSectionAtIndex:(NSInteger)section {
    if ([self showsFolderSection] && section == 0 && self.subfolders.count > 0) {
        return UIEdgeInsetsMake(10, 0, 6, 0);
    }
    return UIEdgeInsetsZero;
}

- (CGFloat)collectionView:(UICollectionView *)cv
                   layout:(UICollectionViewLayout *)layout
 minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    if ([self showsFolderSection] && section == 0) {
        return 0;
    }
    return self.viewMode == SCIVaultViewModeGrid ? kGridSpacing : 0;
}

- (CGFloat)collectionView:(UICollectionView *)cv
                   layout:(UICollectionViewLayout *)layout
 minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    if ([self showsFolderSection] && section == 0) {
        return 0;
    }
    return self.viewMode == SCIVaultViewModeGrid ? kGridSpacing : 0;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [cv deselectItemAtIndexPath:indexPath animated:YES];

    if ([self isFolderIndexPath:indexPath]) {
        if (self.selectionMode) {
            return;
        }
        NSString *subfolderPath = self.subfolders[indexPath.item];
        SCIVaultViewController *child = [[SCIVaultViewController alloc] initWithFolderPath:subfolderPath];
        [self.navigationController pushViewController:child animated:YES];
        return;
    }

    NSIndexPath *filePath = [NSIndexPath indexPathForItem:indexPath.item inSection:0];
    SCIVaultFile *selectedFile = [self.fetchedResultsController objectAtIndexPath:filePath];
    if (self.selectionMode) {
        [self toggleSelectionForFile:selectedFile];
        return;
    }

    NSArray *allFiles = self.fetchedResultsController.fetchedObjects;
    NSInteger idx = [allFiles indexOfObject:selectedFile];
    if (idx == NSNotFound) idx = 0;
    [SCIFullScreenMediaPlayer showVaultFiles:allFiles
                             startingAtIndex:idx
                          fromViewController:self];
}

- (void)showVaultOpenFailureMessage:(NSString *)title {
    [SCIUtils showToastForDuration:2.0
                             title:title
                          subtitle:@"The original content may no longer exist."
                      iconResource:@"error_filled"
           fallbackSystemImageName:@"exclamationmark.circle.fill"
                              tone:SCIFeedbackPillToneError];
}

- (void)openOriginalPostForFile:(SCIVaultFile *)file {
    if (![SCIVaultOriginController openOriginalPostForVaultFile:file]) {
        [self showVaultOpenFailureMessage:@"Unable to open original post"];
    }
}

- (void)openProfileForFile:(SCIVaultFile *)file {
    if (![SCIVaultOriginController openProfileForVaultFile:file]) {
        [self showVaultOpenFailureMessage:@"Unable to open profile"];
    }
}

- (NSArray<SCIVaultFile *> *)visibleVaultFiles {
    return self.fetchedResultsController.fetchedObjects ?: @[];
}

- (SCIVaultFile *)vaultFileForCollectionIndexPath:(NSIndexPath *)indexPath {
    if ([self isFolderIndexPath:indexPath]) {
        return nil;
    }
    NSIndexPath *filePath = [NSIndexPath indexPathForItem:indexPath.item inSection:0];
    return [self.fetchedResultsController objectAtIndexPath:filePath];
}

- (void)animateSelectionModeTransition {
    for (NSIndexPath *indexPath in self.collectionView.indexPathsForVisibleItems) {
        SCIVaultFile *file = [self vaultFileForCollectionIndexPath:indexPath];
        if (!file) {
            continue;
        }

        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
        BOOL selected = [self.selectedFileIDs containsObject:file.identifier];
        if ([cell isKindOfClass:[SCIVaultListCollectionCell class]]) {
            [(SCIVaultListCollectionCell *)cell setSelectionMode:self.selectionMode selected:selected animated:YES];
            [(SCIVaultListCollectionCell *)cell setMoreActionsMenu:self.selectionMode ? nil : [self fileActionsMenuForFile:file]];
        } else if ([cell isKindOfClass:[SCIVaultGridCell class]]) {
            [(SCIVaultGridCell *)cell setSelectionMode:self.selectionMode selected:selected animated:YES];
        }
    }
}

- (NSArray<SCIVaultFile *> *)selectedVaultFiles {
    if (self.selectedFileIDs.count == 0) {
        return @[];
    }

    NSMutableArray<SCIVaultFile *> *files = [NSMutableArray array];
    for (SCIVaultFile *file in [self visibleVaultFiles]) {
        if ([self.selectedFileIDs containsObject:file.identifier]) {
            [files addObject:file];
        }
    }
    return files;
}

- (void)enterSelectionMode {
    self.selectionMode = YES;
    [self.selectedFileIDs removeAllObjects];
    [self refreshNavigationItems];
    [self refreshBottomToolbarItems];
    [self animateSelectionModeTransition];
}

- (void)exitSelectionMode {
    self.selectionMode = NO;
    [self.selectedFileIDs removeAllObjects];
    [self refreshNavigationItems];
    [self refreshBottomToolbarItems];
    [self animateSelectionModeTransition];
}

- (void)toggleSelectionForFile:(SCIVaultFile *)file {
    if (file.identifier.length == 0) {
        return;
    }
    if ([self.selectedFileIDs containsObject:file.identifier]) {
        [self.selectedFileIDs removeObject:file.identifier];
    } else {
        [self.selectedFileIDs addObject:file.identifier];
    }
    [self refreshNavigationItems];
    [self.collectionView reloadData];
}

- (void)selectAllVisibleFiles {
    NSArray<SCIVaultFile *> *files = [self visibleVaultFiles];
    if (files.count > 0 && self.selectedFileIDs.count == files.count) {
        [self.selectedFileIDs removeAllObjects];
    } else {
        [self.selectedFileIDs removeAllObjects];
        for (SCIVaultFile *file in files) {
            if (file.identifier.length > 0) {
                [self.selectedFileIDs addObject:file.identifier];
            }
        }
    }
    self.navigationItem.rightBarButtonItem.title = (self.selectedFileIDs.count == files.count && files.count > 0) ? @"Deselect All" : @"Select All";
    [self.collectionView reloadData];
}

- (void)shareSelectedFiles {
    NSArray<SCIVaultFile *> *files = [self selectedVaultFiles];
    if (files.count == 0) {
        return;
    }

    NSMutableArray<NSURL *> *urls = [NSMutableArray arrayWithCapacity:files.count];
    for (SCIVaultFile *file in files) {
        [urls addObject:file.fileURL];
    }

    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)moveSelectedFiles {
    NSArray<SCIVaultFile *> *files = [self selectedVaultFiles];
    if (files.count == 0) {
        return;
    }
    [self presentMoveSheetForFiles:files];
}

- (void)toggleFavoriteForSelectedFiles {
    NSArray<SCIVaultFile *> *files = [self selectedVaultFiles];
    if (files.count == 0) {
        return;
    }

    BOOL shouldFavorite = NO;
    for (SCIVaultFile *file in files) {
        if (!file.isFavorite) {
            shouldFavorite = YES;
            break;
        }
    }

    for (SCIVaultFile *file in files) {
        file.isFavorite = shouldFavorite;
    }
    [[SCIVaultCoreDataStack shared] saveContext];
    [self refetch];
}

- (void)deleteSelectedFiles {
    NSArray<SCIVaultFile *> *files = [self selectedVaultFiles];
    if (files.count == 0) {
        return;
    }

    NSString *message = [NSString stringWithFormat:@"This will permanently remove %ld file%@ from the vault.", (long)files.count, files.count == 1 ? @"" : @"s"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Selected Files?"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        NSError *firstError = nil;
        for (SCIVaultFile *file in files) {
            NSError *removeError = nil;
            [file removeWithError:&removeError];
            if (!firstError && removeError) {
                firstError = removeError;
            }
        }
        if (firstError) {
            [SCIUtils showToastForDuration:2.0
                                     title:@"Failed to delete"
                                  subtitle:firstError.localizedDescription
                              iconResource:@"error_filled"
                   fallbackSystemImageName:@"exclamationmark.circle.fill"
                                      tone:SCIFeedbackPillToneError];
            return;
        }
        [self exitSelectionMode];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UIContextMenuConfiguration *)collectionView:(UICollectionView *)cv
    contextMenuConfigurationForItemAtIndexPath:(NSIndexPath *)indexPath
                                         point:(CGPoint)point {
    if (self.selectionMode) {
        return nil;
    }
    if ([self isFolderIndexPath:indexPath]) {
        NSString *folder = self.subfolders[indexPath.item];
        return [self contextMenuForFolder:folder];
    }

    NSIndexPath *filePath = [NSIndexPath indexPathForItem:indexPath.item inSection:0];
    SCIVaultFile *file = [self.fetchedResultsController objectAtIndexPath:filePath];
    return [self contextMenuForFile:file];
}

- (UIMenu *)fileActionsMenuForFile:(SCIVaultFile *)file {
    __weak typeof(self) weakSelf = self;

    NSString *favTitle = file.isFavorite ? @"Unfavorite" : @"Favorite";
    UIImage *favImg = file.isFavorite
        ? SCIVaultMenuActionIcon(@"heart_filled", @"heart.fill")
        : SCIVaultMenuActionIcon(@"heart", @"heart");

    UIAction *favoriteAction = [UIAction actionWithTitle:favTitle
                                                   image:favImg
                                              identifier:nil
                                                 handler:^(UIAction *a) {
        file.isFavorite = !file.isFavorite;
        [[SCIVaultCoreDataStack shared] saveContext];
    }];

     UIImage *renameImg = SCIVaultMenuActionIcon(@"edit", @"pencil");
    UIAction *renameAction = [UIAction actionWithTitle:@"Rename"
                                                 image:renameImg
                                            identifier:nil
                                               handler:^(UIAction *a) { [weakSelf renameFile:file]; }];

     UIImage *moveImg = SCIVaultMenuActionIcon(@"folder_move", @"folder");
    UIAction *moveAction = [UIAction actionWithTitle:@"Move to folder"
                                               image:moveImg
                                          identifier:nil
                                             handler:^(UIAction *a) { [weakSelf moveFile:file]; }];

     UIImage *shareImg = SCIVaultMenuActionIcon(@"share", @"square.and.arrow.up");
    UIAction *shareAction = [UIAction actionWithTitle:@"Share"
                                                image:shareImg
                                           identifier:nil
                                              handler:^(UIAction *a) {
        NSURL *url = [file fileURL];
        UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        [weakSelf presentViewController:acVC animated:YES completion:nil];
    }];

    UIAction *openOriginalAction = nil;
    if (file.hasOpenableOriginalMedia) {
        openOriginalAction = [UIAction actionWithTitle:@"Open Original Post"
                                                 image:SCIVaultMenuActionIcon(@"external_link", @"arrow.up.right.square")
                                            identifier:nil
                                               handler:^(__unused UIAction *a) {
            [weakSelf openOriginalPostForFile:file];
        }];
    }

    UIAction *openProfileAction = nil;
    if (file.hasOpenableProfile) {
        openProfileAction = [UIAction actionWithTitle:@"Open Profile"
                                                image:SCIVaultMenuActionIcon(@"profile", @"person.crop.circle")
                                           identifier:nil
                                              handler:^(__unused UIAction *a) {
            [weakSelf openProfileForFile:file];
        }];
    }

    UIImage *deleteImg = SCIVaultMenuActionIcon(@"trash", @"trash");
    UIAction *deleteAction = [UIAction actionWithTitle:@"Delete"
                                                 image:deleteImg
                                            identifier:nil
                                               handler:^(UIAction *a) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete from Vault?"
                                                                      message:@"This will permanently remove this file from the vault."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
            NSError *err;
            [file removeWithError:&err];
            if (err) {
                [SCIUtils showToastForDuration:2.0
                                         title:@"Failed to delete"
                                      subtitle:err.localizedDescription
                                  iconResource:@"error_filled"
                       fallbackSystemImageName:@"exclamationmark.circle.fill"
                                          tone:SCIFeedbackPillToneError];
            }
        }]];
        [weakSelf presentViewController:alert animated:YES completion:nil];
    }];
    deleteAction.attributes = UIMenuElementAttributesDestructive;

    NSMutableArray<UIMenuElement *> *children = [NSMutableArray array];
    if (openOriginalAction) [children addObject:openOriginalAction];
    if (openProfileAction) [children addObject:openProfileAction];
    if (children.count > 0) {
        [children addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[]]];
    }
    [children addObjectsFromArray:@[favoriteAction, renameAction, moveAction, shareAction, deleteAction]];
    return [UIMenu menuWithTitle:@"" children:children];
}

- (UIContextMenuConfiguration *)contextMenuForFile:(SCIVaultFile *)file {
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        return strongSelf ? [strongSelf fileActionsMenuForFile:file] : nil;
    }];
}

- (UIContextMenuConfiguration *)contextMenuForFolder:(NSString *)folderPath {
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
    UIImage *folderRenameImg = SCIVaultMenuActionIcon(@"edit", @"pencil");
        UIAction *renameAction = [UIAction actionWithTitle:@"Rename folder"
                                                     image:folderRenameImg
                                                identifier:nil
                                                   handler:^(UIAction *a) { [weakSelf renameFolder:folderPath]; }];

    UIImage *folderDeleteImg = SCIVaultMenuActionIcon(@"trash", @"trash");
        UIAction *deleteAction = [UIAction actionWithTitle:@"Delete folder"
                                                     image:folderDeleteImg
                                                identifier:nil
                                                   handler:^(UIAction *a) { [weakSelf deleteFolder:folderPath]; }];
        deleteAction.attributes = UIMenuElementAttributesDestructive;

        return [UIMenu menuWithTitle:@"" children:@[renameAction, deleteAction]];
    }];
}

#pragma mark - Folder CRUD

- (void)presentCreateFolder {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"New Folder"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Folder name";
        tf.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Create"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (name.length == 0) return;
        [self createFolderNamed:name];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)createFolderNamed:(NSString *)name {
    NSString *newPath = [self folderPathByAppendingComponent:name toBase:self.currentFolderPath];

    // Folders materialize when any file references them. To make empty folders
    // discoverable, we store a placeholder record in NSUserDefaults.
    NSString *key = @"scinsta_vault_folders";
    NSMutableArray<NSString *> *placeholders = [[[NSUserDefaults standardUserDefaults] arrayForKey:key] mutableCopy] ?: [NSMutableArray array];
    if (![placeholders containsObject:newPath]) {
        [placeholders addObject:newPath];
        [[NSUserDefaults standardUserDefaults] setObject:placeholders forKey:key];
    }
    [self reloadSubfolders];
    [self.collectionView reloadData];
    [self updateEmptyState];
}

- (NSString *)folderPathByAppendingComponent:(NSString *)component toBase:(NSString *)base {
    NSString *sanitized = [component stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    if (base.length == 0) return [@"/" stringByAppendingString:sanitized];
    return [base stringByAppendingFormat:@"/%@", sanitized];
}

- (void)mergePlaceholderSubfolders {
    NSArray<NSString *> *placeholders = [[NSUserDefaults standardUserDefaults] arrayForKey:@"scinsta_vault_folders"] ?: @[];
    NSString *base = self.currentFolderPath ?: @"";
    NSString *prefix = base.length == 0 ? @"/" : [base stringByAppendingString:@"/"];

    NSMutableSet<NSString *> *merged = [NSMutableSet setWithArray:self.subfolders];
    for (NSString *p in placeholders) {
        if (![p hasPrefix:prefix]) continue;
        NSString *rest = [p substringFromIndex:prefix.length];
        if (rest.length == 0) continue;
        NSRange slash = [rest rangeOfString:@"/"];
        NSString *folderName = slash.location == NSNotFound ? rest : [rest substringToIndex:slash.location];
        [merged addObject:[prefix stringByAppendingString:folderName]];
    }
    self.subfolders = [[merged allObjects] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
}

- (void)renameFolder:(NSString *)folderPath {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename Folder"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = [folderPath lastPathComponent];
        tf.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Rename"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *newName = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newName.length == 0) return;
        [self performRenameOfFolder:folderPath toName:newName];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performRenameOfFolder:(NSString *)oldPath toName:(NSString *)newName {
    NSString *parent = [oldPath stringByDeletingLastPathComponent];
    if (![parent hasPrefix:@"/"]) parent = [@"/" stringByAppendingString:parent];
    NSString *newPath = [parent isEqualToString:@"/"]
        ? [@"/" stringByAppendingString:newName]
        : [parent stringByAppendingFormat:@"/%@", newName];

    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    req.predicate = [NSPredicate predicateWithFormat:@"folderPath == %@ OR folderPath BEGINSWITH %@",
                     oldPath, [oldPath stringByAppendingString:@"/"]];
    NSArray<SCIVaultFile *> *files = [ctx executeFetchRequest:req error:nil];
    for (SCIVaultFile *f in files) {
        NSString *current = f.folderPath ?: @"";
        if ([current isEqualToString:oldPath]) {
            f.folderPath = newPath;
        } else if ([current hasPrefix:[oldPath stringByAppendingString:@"/"]]) {
            NSString *suffix = [current substringFromIndex:oldPath.length];
            f.folderPath = [newPath stringByAppendingString:suffix];
        }
    }
    [ctx save:nil];

    // Update placeholders.
    NSString *key = @"scinsta_vault_folders";
    NSMutableArray<NSString *> *placeholders = [[[NSUserDefaults standardUserDefaults] arrayForKey:key] mutableCopy] ?: [NSMutableArray array];
    NSMutableArray<NSString *> *updated = [NSMutableArray array];
    for (NSString *p in placeholders) {
        if ([p isEqualToString:oldPath]) {
            [updated addObject:newPath];
        } else if ([p hasPrefix:[oldPath stringByAppendingString:@"/"]]) {
            [updated addObject:[newPath stringByAppendingString:[p substringFromIndex:oldPath.length]]];
        } else {
            [updated addObject:p];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:updated forKey:key];

    [self reloadSubfolders];
    [self.collectionView reloadData];
}

- (void)deleteFolder:(NSString *)folderPath {
    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    req.predicate = [NSPredicate predicateWithFormat:@"folderPath == %@ OR folderPath BEGINSWITH %@",
                     folderPath, [folderPath stringByAppendingString:@"/"]];
    NSInteger count = [ctx countForFetchRequest:req error:nil];

    NSString *msg = count == 0
        ? @"This folder is empty."
        : [NSString stringWithFormat:@"This folder contains %ld file(s). They will be moved to the parent folder.", (long)count];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Folder?"
                                                                  message:msg
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [self performDeleteFolder:folderPath];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performDeleteFolder:(NSString *)folderPath {
    NSString *parent = [folderPath stringByDeletingLastPathComponent];
    if (parent.length == 0 || [parent isEqualToString:@"/"]) parent = nil; // move to root

    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    req.predicate = [NSPredicate predicateWithFormat:@"folderPath == %@ OR folderPath BEGINSWITH %@",
                     folderPath, [folderPath stringByAppendingString:@"/"]];
    NSArray<SCIVaultFile *> *files = [ctx executeFetchRequest:req error:nil];
    for (SCIVaultFile *f in files) {
        f.folderPath = parent;
    }
    [ctx save:nil];

    // Remove placeholders beneath the folder path.
    NSString *key = @"scinsta_vault_folders";
    NSMutableArray<NSString *> *placeholders = [[[NSUserDefaults standardUserDefaults] arrayForKey:key] mutableCopy] ?: [NSMutableArray array];
    NSString *prefix = [folderPath stringByAppendingString:@"/"];
    [placeholders filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *p, NSDictionary *b) {
        return ![p isEqualToString:folderPath] && ![p hasPrefix:prefix];
    }]];
    [[NSUserDefaults standardUserDefaults] setObject:placeholders forKey:key];

    [self reloadSubfolders];
    [self.collectionView reloadData];
    [self updateEmptyState];
}

#pragma mark - File rename / move

- (void)renameFile:(SCIVaultFile *)file {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = [file displayName];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *newName = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        file.customName = newName.length > 0 ? newName : nil;
        [[SCIVaultCoreDataStack shared] saveContext];
        [self.collectionView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)assignFolderPath:(nullable NSString *)folderPath toFiles:(NSArray<SCIVaultFile *> *)files {
    for (SCIVaultFile *file in files) {
        file.folderPath = folderPath;
    }
    [[SCIVaultCoreDataStack shared] saveContext];
    [self refetch];
}

- (void)presentMoveSheetForFiles:(NSArray<SCIVaultFile *> *)files {
    NSArray<NSString *> *allFolders = [self allFolderPaths];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Move to folder"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Root"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        [self assignFolderPath:nil toFiles:files];
    }]];

    for (NSString *folder in allFolders) {
        [sheet addAction:[UIAlertAction actionWithTitle:folder
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            [self assignFolderPath:folder toFiles:files];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"New folder…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        UIAlertController *createAlert = [UIAlertController alertControllerWithTitle:@"New Folder"
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
        [createAlert addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"Folder name"; }];
        [createAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [createAlert addAction:[UIAlertAction actionWithTitle:@"Create & Move"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *x) {
            NSString *name = [createAlert.textFields.firstObject.text stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (name.length == 0) return;
            NSString *newPath = [self folderPathByAppendingComponent:name toBase:self.currentFolderPath];
            [self assignFolderPath:newPath toFiles:files];
        }]];
        [self presentViewController:createAlert animated:YES completion:nil];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)moveFile:(SCIVaultFile *)file {
    [self presentMoveSheetForFiles:@[file]];
}

- (NSArray<NSString *> *)allFolderPaths {
    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    req.resultType = NSDictionaryResultType;
    req.propertiesToFetch = @[@"folderPath"];
    req.returnsDistinctResults = YES;
    req.predicate = [NSPredicate predicateWithFormat:@"folderPath != nil AND folderPath != ''"];
    NSArray<NSDictionary *> *results = [ctx executeFetchRequest:req error:nil];

    NSMutableSet<NSString *> *set = [NSMutableSet set];
    for (NSDictionary *d in results) {
        NSString *p = d[@"folderPath"];
        if (p.length > 0) [set addObject:p];
    }
    NSArray<NSString *> *placeholders = [[NSUserDefaults standardUserDefaults] arrayForKey:@"scinsta_vault_folders"] ?: @[];
    [set addObjectsFromArray:placeholders];

    return [[set allObjects] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
}

#pragma mark - Sort / Filter

- (void)configureVaultSheetForNavigation:(UINavigationController *)nav {
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = nav.sheetPresentationController;
    if (sheet) {
        sheet.detents = @[
            UISheetPresentationControllerDetent.mediumDetent,
            UISheetPresentationControllerDetent.largeDetent
        ];
        sheet.prefersGrabberVisible = YES;
    }
}

- (void)presentSort {
    SCIVaultSortViewController *vc = [[SCIVaultSortViewController alloc] init];
    vc.delegate = self;
    vc.currentSortMode = self.sortMode;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self configureVaultSheetForNavigation:nav];

    UISheetPresentationController *sheet = nav.sheetPresentationController;
    if (sheet) {
        if (@available(iOS 16.0, *)) {
            UISheetPresentationControllerDetent *compact = [UISheetPresentationControllerDetent
                customDetentWithIdentifier:@"scinsta.vault.sort.compact"
                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                CGFloat target = MIN(430.0, context.maximumDetentValue * 0.58);
                return MAX(330.0, target);
            }];
            sheet.detents = @[compact, UISheetPresentationControllerDetent.mediumDetent];
            sheet.selectedDetentIdentifier = compact.identifier;
        } else {
            sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent];
        }
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }

    [self presentViewController:nav animated:YES completion:nil];
}

- (void)presentFilter {
    SCIVaultFilterViewController *vc = [[SCIVaultFilterViewController alloc] init];
    vc.delegate = self;
    vc.filterTypes = self.filterTypes;
    vc.filterSources = self.filterSources;
    vc.filterFavoritesOnly = self.filterFavoritesOnly;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self configureVaultSheetForNavigation:nav];

    UISheetPresentationController *sheet = nav.sheetPresentationController;
    if (sheet) {
        if (@available(iOS 16.0, *)) {
            UISheetPresentationControllerDetent *compact = [UISheetPresentationControllerDetent
                customDetentWithIdentifier:@"scinsta.vault.filter.compact"
                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                CGFloat target = MIN(430.0, context.maximumDetentValue * 0.58);
                return MAX(330.0, target);
            }];
            sheet.detents = @[compact, UISheetPresentationControllerDetent.mediumDetent];
            sheet.selectedDetentIdentifier = compact.identifier;
        } else {
            sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent];
        }
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }

    [self presentViewController:nav animated:YES completion:nil];
}

- (void)sortController:(SCIVaultSortViewController *)controller didSelectSortMode:(SCIVaultSortMode)mode {
    self.sortMode = mode;
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kSortModeKey];
    [self refetch];
}

- (void)filterController:(SCIVaultFilterViewController *)controller
           didApplyTypes:(NSSet<NSNumber *> *)types
                 sources:(NSSet<NSNumber *> *)sources
           favoritesOnly:(BOOL)favoritesOnly {
    self.filterTypes = [types mutableCopy];
    self.filterSources = [sources mutableCopy];
    self.filterFavoritesOnly = favoritesOnly;
    [self refetch];
}

- (void)filterControllerDidClear:(SCIVaultFilterViewController *)controller {
    [self.filterTypes removeAllObjects];
    [self.filterSources removeAllObjects];
    self.filterFavoritesOnly = NO;
    [self refetch];
}

- (void)handleVaultPreferencesChanged:(NSNotification *)note {
    (void)note;
    [self refetch];
}

#pragma mark - Settings

- (void)pushSettings {
    SCIVaultSettingsViewController *vc = [[SCIVaultSettingsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
