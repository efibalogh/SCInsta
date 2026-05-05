#import "SCISettingsViewController.h"
#import "../App/SCIStartupHooks.h"
#import "../Shared/UI/SCISwitch.h"

static char rowStaticRef[] = "row";
static NSInteger const kSCIUINavigationItemSearchBarPlacementIntegratedButton = 4;

@interface SCISettingsViewController () <UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate, UISearchResultsUpdating>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSArray *originalSections;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic) BOOL reduceMargin;

@end

///

static UIImage *SCISettingsReorderCompositeImage(UIImage *iconImage, UIColor *tintColor) {
    UIImageSymbolConfiguration *grabberConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightSemibold];
    UIImage *grabber = [[UIImage systemImageNamed:@"line.3.horizontal" withConfiguration:grabberConfig] imageWithTintColor:[SCIUtils SCIColor_InstagramTertiaryText] renderingMode:UIImageRenderingModeAlwaysOriginal];
    if (!grabber || !iconImage) return iconImage ?: grabber;

    CGFloat spacing = 8.0;
    CGSize size = CGSizeMake(grabber.size.width + spacing + iconImage.size.width,
                             MAX(grabber.size.height, iconImage.size.height));
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        CGFloat grabberY = floor((size.height - grabber.size.height) / 2.0);
        [grabber drawAtPoint:CGPointMake(0.0, grabberY)];

        UIImage *renderedIcon = [iconImage imageWithTintColor:tintColor ?: [SCIUtils SCIColor_InstagramPrimaryText] renderingMode:UIImageRenderingModeAlwaysOriginal];
        CGFloat iconY = floor((size.height - renderedIcon.size.height) / 2.0);
        [renderedIcon drawAtPoint:CGPointMake(grabber.size.width + spacing, iconY)];
    }];
}

static NSString *SCITitleCaseString(NSString *string) {
    if (string.length == 0) return string;

    NSSet<NSString *> *lowercaseWords = [NSSet setWithArray:@[@"a", @"an", @"and", @"as", @"at", @"by", @"for", @"from", @"in", @"of", @"on", @"or", @"the", @"to", @"vs."]];
    NSArray<NSString *> *parts = [string componentsSeparatedByString:@" "];
    NSMutableArray<NSString *> *formatted = [NSMutableArray arrayWithCapacity:parts.count];

    [parts enumerateObjectsUsingBlock:^(NSString *part, NSUInteger idx, BOOL *stop) {
        if (part.length == 0) {
            [formatted addObject:part];
            return;
        }

        if ([part isEqualToString:part.uppercaseString]) {
            [formatted addObject:part];
            return;
        }

        NSString *lower = part.lowercaseString;
        if (idx > 0 && [lowercaseWords containsObject:lower]) {
            [formatted addObject:lower];
            return;
        }

        [formatted addObject:part.capitalizedString];
    }];

    return [formatted componentsJoinedByString:@" "];
}

static NSMutableArray *SCIMutableSectionsCopy(NSArray *sections) {
    NSMutableArray *mutableSections = [NSMutableArray array];
    for (NSDictionary *section in sections) {
        NSMutableDictionary *mutableSection = [section mutableCopy];
        NSArray *rows = section[@"rows"];
        mutableSection[@"rows"] = rows ? [rows mutableCopy] : [NSMutableArray array];
        [mutableSections addObject:mutableSection];
    }
    return mutableSections;
}

static NSString *SCISettingsNormalizedQuery(NSString *query) {
    return [[query ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
}

static BOOL SCISettingsStringMatchesQuery(NSString *string, NSString *query) {
    if (query.length == 0) return YES;
    return [[string ?: @"" lowercaseString] containsString:query];
}

static BOOL SCISettingsRowMatchesQuery(SCISetting *row, NSString *query, NSString *path, NSString *sectionTitle) {
    if (![row isKindOfClass:[SCISetting class]]) return NO;
    return SCISettingsStringMatchesQuery(row.title, query) ||
           SCISettingsStringMatchesQuery(row.subtitle, query) ||
           SCISettingsStringMatchesQuery(path, query) ||
           SCISettingsStringMatchesQuery(sectionTitle, query);
}

@implementation SCISettingsViewController

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SCIUtils SCIColor_InstagramPressedBackground];
    return view;
}

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray *)sections reduceMargin:(BOOL)reduceMargin {
    self = [super init];
    
    if (self) {
        self.title = title;
        self.reduceMargin = reduceMargin;
        
        // Exclude development cells from release builds
        NSMutableArray *mutableSections = SCIMutableSectionsCopy(sections);
        
        [mutableSections enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *section, NSUInteger index, BOOL *stop) {
        
            if ([section[@"header"] hasPrefix:@"_"] && [section[@"footer"] hasPrefix:@"_"]) {
                if (![[SCIUtils IGVersionString] isEqualToString:@"0.0.0"]) {
                    [mutableSections removeObjectAtIndex:index];
                }
            }

            else if ([section[@"header"] isEqualToString:@"Experimental"]) {
                if (![[SCIUtils IGVersionString] hasSuffix:@"-dev"]) {
                    [mutableSections removeObjectAtIndex:index];
                }
            }
            
        }];
        
        self.originalSections = [mutableSections copy];
        self.sections = mutableSections;
    }
    
    
    return self;
}

- (instancetype)init {
    self = [self initWithTitle:[SCITweakSettings title] sections:[SCITweakSettings sections] reduceMargin:YES];
    if (self) {
        self.searchesAllSettings = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.dragInteractionEnabled = [self pageAllowsReordering];
    self.tableView.dragDelegate = self;
    self.tableView.dropDelegate = self;
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
    self.tableView.tintColor = [SCIUtils SCIColor_Primary];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72.0;

    [self.view addSubview:self.tableView];
    [self setupNavigationItems];
    [self setupSearchController];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (![[[NSUserDefaults standardUserDefaults] objectForKey:@"SCInstaFirstRun"] isEqualToString:SCIVersionString]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SCInsta Settings Info"
                                                                       message:@"In the future: Hold down on the three lines at the top right of your profile page, to re-open SCInsta settings."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"I understand!"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        
        UIViewController *presenter = self.presentingViewController;
        [presenter presentViewController:alert animated:YES completion:nil];
        
        // Done with first-time setup for this version
        [[NSUserDefaults standardUserDefaults] setValue:SCIVersionString forKey:@"SCInstaFirstRun"];
    }
}

- (void)setupNavigationItems {
    BOOL isModalRoot = self.navigationController.presentingViewController &&
                       self.navigationController.viewControllers.firstObject == self;
    self.navigationItem.leftBarButtonItem = isModalRoot
        ? [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                        target:self
                                                        action:@selector(closeTapped)]
        : nil;
}

- (void)setupSearchController {
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = self.searchesAllSettings ? @"Search settings" : [NSString stringWithFormat:@"Search %@", self.title ?: @"settings"];
    self.navigationItem.searchController = self.searchController;
    if (@available(iOS 26.0, *)) {
        self.navigationItem.preferredSearchBarPlacement = (UINavigationItemSearchBarPlacement)kSCIUINavigationItemSearchBarPlacementIntegratedButton;
    } else {
        self.navigationItem.hidesSearchBarWhenScrolling = YES;
    }
    self.definesPresentationContext = YES;
}

- (void)closeTapped {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCISetting *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    if (!row) return nil;
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    UIListContentConfiguration *cellContentConfig = cell.defaultContentConfiguration;
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.tintColor = [SCIUtils SCIColor_Primary];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    cellContentConfig.textProperties.color = [SCIUtils SCIColor_InstagramPrimaryText];
    cellContentConfig.secondaryTextProperties.color = [SCIUtils SCIColor_InstagramSecondaryText];
    cellContentConfig.textProperties.numberOfLines = 0;
    cellContentConfig.secondaryTextProperties.numberOfLines = 0;
    cellContentConfig.secondaryTextProperties.lineBreakMode = NSLineBreakByWordWrapping;
    
    cellContentConfig.text = SCITitleCaseString(row.title);
    
    // Subtitle
    if (row.subtitle.length) {
        cellContentConfig.secondaryText = row.subtitle;
        cellContentConfig.textToSecondaryTextVerticalPadding = 4.5;
    }
    
    // Icon
    if (row.icon != nil) {
        cellContentConfig.image = row.icon;
        cellContentConfig.imageProperties.tintColor = row.iconTintColor ?: [SCIUtils SCIColor_InstagramPrimaryText];
    }

    if ([row.userInfo[@"showsReorderGrabber"] boolValue] && row.icon != nil) {
        UIColor *iconTintColor = row.iconTintColor ?: [SCIUtils SCIColor_InstagramPrimaryText];
        cellContentConfig.image = SCISettingsReorderCompositeImage(row.icon, iconTintColor);
        cellContentConfig.imageProperties.tintColor = nil;
        cellContentConfig.imageToTextPadding = 12.0;
    }
    
    // Image url
    if (row.imageUrl != nil) {
        [self loadImageFromURL:row.imageUrl atIndexPath:indexPath forTableView:tableView];
        
        cellContentConfig.imageToTextPadding = 14;
    }
    
    switch (row.type) {
        case SCITableCellStatic: {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellLink: {
            cellContentConfig.textProperties.color = [SCIUtils SCIColor_Primary];
            cellContentConfig.textProperties.font = [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize
                                                                      weight:UIFontWeightMedium];
            
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            
            UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"safari"]];
            imageView.tintColor = [SCIUtils SCIColor_InstagramTertiaryText];
            cell.accessoryView = imageView;
            
            break;
        }
            
        case SCITableCellSwitch: {
            SCISwitch *toggle = [SCISwitch new];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            id storedValue = [defaults objectForKey:row.defaultsKey];
            NSNumber *defaultValue = row.userInfo[@"defaultValue"];
            toggle.on = storedValue ? [defaults boolForKey:row.defaultsKey] : defaultValue.boolValue;
            if (row.mutuallyExclusiveDefaultsKey.length) {
                BOOL otherOn = [defaults boolForKey:row.mutuallyExclusiveDefaultsKey];
                toggle.enabled = toggle.isOn || !otherOn;
            }
            
            objc_setAssociatedObject(toggle, rowStaticRef, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            
            cell.accessoryView = toggle;
            cell.editingAccessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellStepper: {
            UIStepper *stepper = [UIStepper new];
            stepper.minimumValue = row.min;
            stepper.maximumValue = row.max;
            stepper.stepValue = row.step;
            stepper.value = [[NSUserDefaults standardUserDefaults] doubleForKey:row.defaultsKey];
            
            objc_setAssociatedObject(stepper, rowStaticRef, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            [stepper addTarget:self
                        action:@selector(stepperChanged:)
              forControlEvents:UIControlEventValueChanged];
            
            // Template subtitle
            if (row.subtitle.length) {
                cellContentConfig.secondaryText = [self formatString:row.subtitle withValue:stepper.value label:row.label singularLabel:row.singularLabel];
            }
            
            cell.accessoryView = stepper;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellButton: {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        }
            
        case SCITableCellMenu: {
            UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
            [menuButton setTitle:@"•••" forState:UIControlStateNormal];
            menuButton.menu = [row menuForButton:menuButton];
            menuButton.showsMenuAsPrimaryAction = YES;
            menuButton.titleLabel.font = [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize
                                                           weight:UIFontWeightMedium];
            menuButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            [menuButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [menuButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            
            UIButtonConfiguration *config = menuButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
            config.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
            menuButton.configuration = config;
            menuButton.tintColor = [SCIUtils SCIColor_InstagramPrimaryText];

            [menuButton sizeToFit];
            
            cell.accessoryView = menuButton;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
            
        case SCITableCellNavigation: {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        }
    }

    cell.contentConfiguration = cellContentConfig;
    cell.showsReorderControl = NO;
    cell.shouldIndentWhileEditing = NO;

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.sections[section][@"footer"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

// MARK: - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SCISetting *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    if (!row) return;

    if (row.type == SCITableCellLink) {
        [[UIApplication sharedApplication] openURL:row.url options:@{} completionHandler:nil];
    }
    else if (row.type == SCITableCellButton) {
        if (row.action != nil) {
            row.action();
        }
    }
    else if (row.type == SCITableCellNavigation) {
        if (row.navSections.count > 0) {
            UIViewController *vc = [[SCISettingsViewController alloc] initWithTitle:row.title sections:row.navSections reduceMargin:NO];
            vc.title = row.title;
            [self.navigationController pushViewController:vc animated:YES];
        }
        else if (row.navViewController) {
            [self.navigationController pushViewController:row.navViewController animated:YES];
        }
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isSearching]) return NO;
    return [self.sections[indexPath.section][@"allowsReordering"] boolValue];
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if (sourceIndexPath.section != proposedDestinationIndexPath.section) {
        NSInteger rowCount = [self.sections[sourceIndexPath.section][@"rows"] count];
        NSInteger targetRow = MIN(MAX(0, proposedDestinationIndexPath.row), MAX(0, rowCount - 1));
        return [NSIndexPath indexPathForRow:targetRow inSection:sourceIndexPath.section];
    }
    return proposedDestinationIndexPath;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    NSMutableArray *rows = self.sections[sourceIndexPath.section][@"rows"];
    if (![rows isKindOfClass:[NSMutableArray class]]) return;

    SCISetting *row = rows[sourceIndexPath.row];
    [rows removeObjectAtIndex:sourceIndexPath.row];
    [rows insertObject:row atIndex:destinationIndexPath.row];

    NSString *reorderDefaultsKey = self.sections[sourceIndexPath.section][@"reorderDefaultsKey"];
    if (reorderDefaultsKey.length > 0) {
        NSMutableArray<NSString *> *order = [NSMutableArray array];
        for (SCISetting *candidate in rows) {
            NSString *identifier = candidate.userInfo[@"actionIdentifier"];
            if (identifier.length > 0) [order addObject:identifier];
        }
        [[NSUserDefaults standardUserDefaults] setObject:[order copy] forKey:reorderDefaultsKey];
    }
    self.originalSections = [self.sections copy];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    if (![self tableView:tableView canMoveRowAtIndexPath:indexPath]) {
        return @[];
    }

    SCISetting *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    NSString *identifier = row.userInfo[@"actionIdentifier"] ?: row.title ?: @"action";
    NSItemProvider *provider = [[NSItemProvider alloc] initWithObject:identifier];
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:provider];
    item.localObject = row;
    return @[item];
}

- (BOOL)tableView:(UITableView *)tableView dragSessionAllowsMoveOperation:(id<UIDragSession>)session {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView dragSessionIsRestrictedToDraggingApplication:(id<UIDragSession>)session {
    return YES;
}

- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    if (session.localDragSession == nil || destinationIndexPath == nil) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    }
    if (![self.sections[destinationIndexPath.section][@"allowsReordering"] boolValue]) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    }
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    NSIndexPath *destinationIndexPath = coordinator.destinationIndexPath;
    if (destinationIndexPath == nil) return;

    id<UITableViewDropItem> dropItem = coordinator.items.firstObject;
    NSIndexPath *sourceIndexPath = dropItem.sourceIndexPath;
    if (sourceIndexPath == nil || sourceIndexPath.section != destinationIndexPath.section) return;
    if (![self tableView:tableView canMoveRowAtIndexPath:sourceIndexPath]) return;

    NSInteger rowCount = [self.sections[sourceIndexPath.section][@"rows"] count];
    NSInteger destinationRow = MIN(MAX(0, destinationIndexPath.row), MAX(0, rowCount - 1));
    NSIndexPath *clampedDestination = [NSIndexPath indexPathForRow:destinationRow inSection:destinationIndexPath.section];

    [tableView performBatchUpdates:^{
        [self tableView:tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:clampedDestination];
        [tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:clampedDestination];
    } completion:nil];

    [coordinator dropItem:dropItem.dragItem toRowAtIndexPath:clampedDestination];
}

// MARK: - Search

- (BOOL)isSearching {
    return self.searchController.isActive && self.searchController.searchBar.text.length > 0;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = SCISettingsNormalizedQuery(searchController.searchBar.text);
    if (query.length == 0) {
        self.sections = SCIMutableSectionsCopy(self.originalSections);
    } else if (self.searchesAllSettings) {
        self.sections = [self searchAllSettingsForQuery:query];
    } else {
        self.sections = [self filterCurrentSettingsForQuery:query];
    }
    self.tableView.dragInteractionEnabled = ![self isSearching] && [self pageAllowsReordering];
    [self.tableView reloadData];
}

- (NSMutableArray *)filterCurrentSettingsForQuery:(NSString *)query {
    NSMutableArray *filteredSections = [NSMutableArray array];
    for (NSDictionary *section in self.originalSections) {
        NSArray *rows = section[@"rows"];
        NSMutableArray *matchedRows = [NSMutableArray array];
        NSString *sectionTitle = section[@"header"];
        for (SCISetting *row in rows) {
            if (SCISettingsRowMatchesQuery(row, query, self.title, sectionTitle)) {
                [matchedRows addObject:row];
            }
        }
        if (matchedRows.count == 0) continue;

        NSMutableDictionary *filteredSection = [section mutableCopy];
        filteredSection[@"rows"] = matchedRows;
        filteredSection[@"allowsReordering"] = @NO;
        [filteredSections addObject:filteredSection];
    }
    return filteredSections;
}

- (NSMutableArray *)searchAllSettingsForQuery:(NSString *)query {
    NSMutableDictionary<NSString *, NSMutableArray<SCISetting *> *> *rowsByPath = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *orderedPaths = [NSMutableArray array];
    [self collectSearchRowsFromSections:self.originalSections
                                   path:self.title ?: @"Settings"
                                  query:query
                             rowsByPath:rowsByPath
                           orderedPaths:orderedPaths];

    NSMutableArray *sections = [NSMutableArray array];
    for (NSString *path in orderedPaths) {
        NSArray *rows = rowsByPath[path];
        if (rows.count == 0) continue;
        [sections addObject:[@{
            @"header": path,
            @"rows": [rows mutableCopy],
            @"allowsReordering": @NO
        } mutableCopy]];
    }
    return sections;
}

- (void)collectSearchRowsFromSections:(NSArray *)sections
                                  path:(NSString *)path
                                 query:(NSString *)query
                            rowsByPath:(NSMutableDictionary<NSString *, NSMutableArray<SCISetting *> *> *)rowsByPath
                          orderedPaths:(NSMutableArray<NSString *> *)orderedPaths {
    for (NSDictionary *section in sections) {
        NSString *sectionTitle = section[@"header"];
        NSString *sectionPath = sectionTitle.length > 0 ? [NSString stringWithFormat:@"%@ / %@", path, sectionTitle] : path;
        for (SCISetting *row in section[@"rows"]) {
            if (![row isKindOfClass:[SCISetting class]]) continue;

            if (SCISettingsRowMatchesQuery(row, query, sectionPath, sectionTitle)) {
                NSMutableArray *rows = rowsByPath[sectionPath];
                if (!rows) {
                    rows = [NSMutableArray array];
                    rowsByPath[sectionPath] = rows;
                    [orderedPaths addObject:sectionPath];
                }
                [rows addObject:row];
            }

            if (row.navSections.count > 0) {
                NSString *childPath = row.title.length > 0 ? [NSString stringWithFormat:@"%@ / %@", path, row.title] : path;
                [self collectSearchRowsFromSections:row.navSections
                                               path:childPath
                                              query:query
                                         rowsByPath:rowsByPath
                                       orderedPaths:orderedPaths];
            }
        }
    }
}

// MARK: - Actions

- (void)switchChanged:(UISwitch *)sender {
    SCISetting *row = objc_getAssociatedObject(sender, rowStaticRef);
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:row.defaultsKey];
    if (sender.isOn && row.mutuallyExclusiveDefaultsKey.length) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:row.mutuallyExclusiveDefaultsKey];
    }
    
    NSLog(@"Switch changed: %@", sender.isOn ? @"ON" : @"OFF");
    if (sender.isOn) {
        SCIInstallEnabledFeatureHooks();
    }
    
    if (row.mutuallyExclusiveDefaultsKey.length) {
        [self.tableView reloadData];
    }
    
    if (row.requiresRestart) {
        [SCIUtils showRestartConfirmation];
    }
}

- (void)stepperChanged:(UIStepper *)sender {
    SCISetting *row = objc_getAssociatedObject(sender, rowStaticRef);
    [[NSUserDefaults standardUserDefaults] setDouble:sender.value forKey:row.defaultsKey];
    
    NSLog(@"Stepper changed: %f", sender.value);
    
    [self reloadCellForView:sender];
}

- (void)menuChanged:(UICommand *)command {
    NSDictionary *properties = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setValue:properties[@"value"] forKey:properties[@"defaultsKey"]];
    
    NSLog(@"Menu changed: %@", command.propertyList[@"value"]);
    
    [self reloadCellForView:command.sender animated:YES];
    
    if (properties[@"requiresRestart"]) {
        [SCIUtils showRestartConfirmation];
    }
}

// MARK: - Helper

- (NSString *)formatString:(NSString *)template withValue:(double)value label:(NSString *)label singularLabel:(NSString *)singularLabel {
    // Singular or plural labels
    NSString *applicableLabel = fabs(value - 1.0) < 0.00001 ? singularLabel : label;
    
    // Force value to 0 to prevent it being -0
    if (fabs(value) < 0.00001) {
        value = 0.0;
    }

    // Get correct decimal value based on step value
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = [SCIUtils decimalPlacesInDouble:value];

    NSString *stringValue = [formatter stringFromNumber:@(value)];

    return [NSString stringWithFormat:template, stringValue, applicableLabel];
}

- (void)reloadCellForView:(UIView *)view animated:(BOOL)animated {
    UITableViewCell *cell = (UITableViewCell *)view.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = (UITableViewCell *)cell.superview;
    }
    if (!cell) return;

    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath) return;
    
    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                          withRowAnimation:animated ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationNone];
}
- (void)reloadCellForView:(UIView *)view {
    [self reloadCellForView:view animated:NO];
}

- (BOOL)pageAllowsReordering {
    if ([self isSearching]) return NO;
    for (NSDictionary *section in self.sections) {
        if ([section[@"allowsReordering"] boolValue]) {
            return YES;
        }
    }
    return NO;
}

- (void)loadImageFromURL:(NSURL *)url atIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView
{
    if (!url) return;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        if (!data || error) return;

        UIImage *image = [UIImage imageWithData:data];
        if (!image) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            if (!cell) return;

            UIListContentConfiguration *config = (UIListContentConfiguration *)cell.contentConfiguration;
            config.image = image;
            config.imageProperties.maximumSize = CGSizeMake(45, 45);
            cell.contentConfiguration = config;
        });
    }];

    [task resume];
}

@end
