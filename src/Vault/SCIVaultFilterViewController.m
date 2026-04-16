#import "SCIVaultFilterViewController.h"

@interface SCIVaultFilterChip : UIButton
@property (nonatomic, assign) NSInteger itemTag;
@property (nonatomic, assign) BOOL selectedChip;
- (void)updateChipAppearance;
@end

@implementation SCIVaultFilterChip

- (instancetype)initWithTag:(NSInteger)tag {
    if ((self = [super initWithFrame:CGRectZero])) {
        _itemTag = tag;
        self.layer.cornerRadius = 10;
        self.layer.borderWidth = 1;
        self.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [self updateChipAppearance];
    }
    return self;
}

- (void)setSelectedChip:(BOOL)selectedChip {
    _selectedChip = selectedChip;
    [self updateChipAppearance];
}

- (void)updateChipAppearance {
    if (self.selectedChip) {
        self.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.18];
        self.tintColor = [UIColor systemBlueColor];
        [self setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        self.layer.borderColor = [UIColor systemBlueColor].CGColor;
    } else {
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        self.tintColor = [UIColor secondaryLabelColor];
        [self setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        self.layer.borderColor = [UIColor separatorColor].CGColor;
    }
}

@end

@interface SCIVaultFilterViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIBarButtonItem *clearButton;

@property (nonatomic, strong) NSMutableArray<SCIVaultFilterChip *> *typeChips;
@property (nonatomic, strong) NSMutableArray<SCIVaultFilterChip *> *sourceChips;
@property (nonatomic, strong) UISwitch *favoritesSwitch;

@end

@implementation SCIVaultFilterViewController

+ (NSPredicate *)predicateForTypes:(NSSet<NSNumber *> *)types
                           sources:(NSSet<NSNumber *> *)sources
                     favoritesOnly:(BOOL)favoritesOnly
                        folderPath:(NSString *)folderPath {
    NSMutableArray<NSPredicate *> *parts = [NSMutableArray new];
    if (types.count > 0) {
        NSArray *typeList = [types.allObjects sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
        [parts addObject:[NSPredicate predicateWithFormat:@"mediaType IN %@", typeList]];
    }
    if (sources.count > 0) {
        NSArray *sourceList = [sources.allObjects sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
        [parts addObject:[NSPredicate predicateWithFormat:@"source IN %@", sourceList]];
    }
    if (favoritesOnly) {
        [parts addObject:[NSPredicate predicateWithFormat:@"isFavorite == %@", @(YES)]];
    }
    if (folderPath.length > 0) {
        [parts addObject:[NSPredicate predicateWithFormat:@"folderPath == %@", folderPath]];
    } else {
        // Root: only items not stored inside a folder (nil or empty string).
        [parts addObject:[NSPredicate predicateWithFormat:@"(folderPath == nil) OR (folderPath == %@)", @""]];
    }
    if (parts.count == 0) return nil;
    return [NSCompoundPredicate andPredicateWithSubpredicates:parts];
}

- (instancetype)init {
    if ((self = [super init])) {
        _filterTypes = [NSMutableSet new];
        _filterSources = [NSMutableSet new];
        _typeChips = [NSMutableArray new];
        _sourceChips = [NSMutableArray new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"Filter";
    [self setupNavigationBar];
    [self configureSheetPresentation];
    [self setupScrollView];
    [self setupContent];
    [self updateClearButton];
}

- (void)setupNavigationBar {
    self.clearButton = [[UIBarButtonItem alloc] initWithTitle:@"Clear"
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(clearFilters)];
    self.navigationItem.leftBarButtonItem = self.clearButton;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(applyFilters)];
}

- (void)configureSheetPresentation {
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent,
                              UISheetPresentationControllerDetent.largeDetent];
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 20;
        }
    }
}

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)setupContent {
    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 24;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:20],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-20],
    ]];

    [self.contentStack addArrangedSubview:[self sectionTitle:@"Type"]];
    [self.contentStack addArrangedSubview:[self createTypeRow]];

    [self.contentStack addArrangedSubview:[self sectionTitle:@"Source"]];
    [self.contentStack addArrangedSubview:[self createSourceGrid]];

    [self.contentStack addArrangedSubview:[self sectionTitle:@"Options"]];
    [self.contentStack addArrangedSubview:[self createFavoritesRow]];
}

- (UILabel *)sectionTitle:(NSString *)title {
    UILabel *l = [[UILabel alloc] init];
    l.text = title;
    l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    l.textColor = [UIColor secondaryLabelColor];
    return l;
}

- (UIView *)createTypeRow {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    row.distribution = UIStackViewDistributionFillEqually;

    NSArray *defs = @[
        @{@"label": @"Images", @"icon": @"photo", @"tag": @(SCIVaultMediaTypeImage)},
        @{@"label": @"Videos", @"icon": @"video", @"tag": @(SCIVaultMediaTypeVideo)},
    ];
    for (NSDictionary *d in defs) {
        NSInteger tag = [d[@"tag"] integerValue];
        SCIVaultFilterChip *chip = [[SCIVaultFilterChip alloc] initWithTag:tag];
        [chip setTitle:d[@"label"] forState:UIControlStateNormal];
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
        [chip setImage:[UIImage systemImageNamed:d[@"icon"] withConfiguration:cfg] forState:UIControlStateNormal];
        chip.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
        chip.selectedChip = [self.filterTypes containsObject:@(tag)];
        [chip addTarget:self action:@selector(typeChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chip.heightAnchor constraintEqualToConstant:44].active = YES;
        [row addArrangedSubview:chip];
        [self.typeChips addObject:chip];
    }
    return row;
}

- (UIView *)createSourceGrid {
    UIStackView *grid = [[UIStackView alloc] init];
    grid.axis = UILayoutConstraintAxisVertical;
    grid.spacing = 10;

    NSArray *sources = @[
        @(SCIVaultSourceFeed), @(SCIVaultSourceStories), @(SCIVaultSourceReels),
        @(SCIVaultSourceProfile), @(SCIVaultSourceDMs), @(SCIVaultSourceOther),
    ];

    UIStackView *currentRow = nil;
    for (NSInteger i = 0; i < sources.count; i++) {
        if (i % 3 == 0) {
            currentRow = [[UIStackView alloc] init];
            currentRow.axis = UILayoutConstraintAxisHorizontal;
            currentRow.spacing = 10;
            currentRow.distribution = UIStackViewDistributionFillEqually;
            [grid addArrangedSubview:currentRow];
        }

        SCIVaultSource src = (SCIVaultSource)[sources[i] integerValue];
        SCIVaultFilterChip *chip = [[SCIVaultFilterChip alloc] initWithTag:src];
        [chip setTitle:[SCIVaultFile labelForSource:src] forState:UIControlStateNormal];
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium];
        [chip setImage:[UIImage systemImageNamed:[SCIVaultFile symbolNameForSource:src] withConfiguration:cfg] forState:UIControlStateNormal];
        chip.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
        chip.selectedChip = [self.filterSources containsObject:@(src)];
        [chip addTarget:self action:@selector(sourceChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chip.heightAnchor constraintEqualToConstant:44].active = YES;
        [currentRow addArrangedSubview:chip];
        [self.sourceChips addObject:chip];
    }

    // Pad last row so chips have equal width
    while (currentRow.arrangedSubviews.count % 3 != 0) {
        UIView *spacer = [[UIView alloc] init];
        [currentRow addArrangedSubview:spacer];
    }
    return grid;
}

- (UIView *)createFavoritesRow {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [UIColor secondarySystemBackgroundColor];
    row.layer.cornerRadius = 10;
    [row.heightAnchor constraintEqualToConstant:52].active = YES;

    UIImageView *icon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"heart.fill"]];
    icon.tintColor = [UIColor systemPinkColor];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Favorites only";
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    label.textColor = [UIColor labelColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    self.favoritesSwitch = [[UISwitch alloc] init];
    self.favoritesSwitch.on = self.filterFavoritesOnly;
    self.favoritesSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.favoritesSwitch addTarget:self action:@selector(favoritesSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:self.favoritesSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [icon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [self.favoritesSwitch.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [self.favoritesSwitch.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

#pragma mark - Actions

- (void)typeChipTapped:(SCIVaultFilterChip *)chip {
    NSNumber *tag = @(chip.itemTag);
    if ([self.filterTypes containsObject:tag]) {
        [self.filterTypes removeObject:tag];
        chip.selectedChip = NO;
    } else {
        [self.filterTypes addObject:tag];
        chip.selectedChip = YES;
    }
    [self updateClearButton];
}

- (void)sourceChipTapped:(SCIVaultFilterChip *)chip {
    NSNumber *tag = @(chip.itemTag);
    if ([self.filterSources containsObject:tag]) {
        [self.filterSources removeObject:tag];
        chip.selectedChip = NO;
    } else {
        [self.filterSources addObject:tag];
        chip.selectedChip = YES;
    }
    [self updateClearButton];
}

- (void)favoritesSwitchChanged:(UISwitch *)sw {
    self.filterFavoritesOnly = sw.on;
    [self updateClearButton];
}

- (void)updateClearButton {
    self.clearButton.enabled = [self hasActiveFilters];
}

- (BOOL)hasActiveFilters {
    return self.filterTypes.count > 0 || self.filterSources.count > 0 || self.filterFavoritesOnly;
}

- (void)applyFilters {
    if ([self.delegate respondsToSelector:@selector(filterController:didApplyTypes:sources:favoritesOnly:)]) {
        [self.delegate filterController:self
                          didApplyTypes:[self.filterTypes copy]
                                sources:[self.filterSources copy]
                          favoritesOnly:self.filterFavoritesOnly];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearFilters {
    [self.filterTypes removeAllObjects];
    [self.filterSources removeAllObjects];
    self.filterFavoritesOnly = NO;
    self.favoritesSwitch.on = NO;
    for (SCIVaultFilterChip *c in self.typeChips) c.selectedChip = NO;
    for (SCIVaultFilterChip *c in self.sourceChips) c.selectedChip = NO;
    if ([self.delegate respondsToSelector:@selector(filterControllerDidClear:)]) {
        [self.delegate filterControllerDidClear:self];
    }
    [self updateClearButton];
}

@end
