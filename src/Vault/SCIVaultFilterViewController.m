#import "SCIVaultFilterViewController.h"
#import "../Utils.h"

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
@property (nonatomic, strong) UIControl *favoritesRow;
@property (nonatomic, strong) UIImageView *favoritesStateIcon;

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
    UISheetPresentationController *sheet = self.sheetPresentationController;
    if (sheet) {
        if (@available(iOS 16.0, *)) {
            UISheetPresentationControllerDetent *compact = [UISheetPresentationControllerDetent
                customDetentWithIdentifier:@"scinsta.vault.filter.local.compact"
                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                CGFloat target = MIN(430.0, context.maximumDetentValue * 0.58);
                return MAX(330.0, target);
            }];
            sheet.detents = @[compact, UISheetPresentationControllerDetent.mediumDetent];
            sheet.selectedDetentIdentifier = compact.identifier;
        } else {
            sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent];
        }
        sheet.prefersGrabberVisible = YES;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        sheet.preferredCornerRadius = 20;
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
    self.contentStack.spacing = 18;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentStack];

    UILayoutGuide *content = self.scrollView.contentLayoutGuide;
    UILayoutGuide *frame = self.scrollView.frameLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:frame.leadingAnchor constant:16],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:frame.trailingAnchor constant:-16],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16],
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
    UIControl *row = [[UIControl alloc] init];
    row.backgroundColor = [UIColor secondarySystemBackgroundColor];
    row.layer.cornerRadius = 10;
    row.layer.borderWidth = 1.0;
    row.layer.borderColor = [UIColor separatorColor].CGColor;
    [row.heightAnchor constraintEqualToConstant:50].active = YES;
    [row addTarget:self action:@selector(favoritesRowTapped) forControlEvents:UIControlEventTouchUpInside];

    UIImage *favRowIcon = [SCIUtils sci_resourceImageNamed:@"heart_filled" template:YES maxPointSize:18] ?: [UIImage systemImageNamed:@"heart.fill"];
    UIImageView *icon = [[UIImageView alloc] initWithImage:favRowIcon];
    icon.tintColor = [UIColor systemPinkColor];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Favorites only";
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    label.textColor = [UIColor labelColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    UIImageView *stateIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
    stateIcon.translatesAutoresizingMaskIntoConstraints = NO;
    stateIcon.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:stateIcon];

    self.favoritesRow = row;
    self.favoritesStateIcon = stateIcon;
    [self updateFavoritesRowAppearance];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [icon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18],
        [icon.heightAnchor constraintEqualToConstant:18],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [stateIcon.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [stateIcon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [stateIcon.widthAnchor constraintEqualToConstant:20],
        [stateIcon.heightAnchor constraintEqualToConstant:20],
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

- (void)favoritesRowTapped {
    self.filterFavoritesOnly = !self.filterFavoritesOnly;
    [self updateFavoritesRowAppearance];
    [self updateClearButton];
}

- (void)updateFavoritesRowAppearance {
    if (!self.favoritesRow || !self.favoritesStateIcon) return;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
    if (self.filterFavoritesOnly) {
        UIColor *accent = [UIColor systemPinkColor];
        self.favoritesRow.backgroundColor = [accent colorWithAlphaComponent:0.12];
        self.favoritesRow.layer.borderColor = [accent colorWithAlphaComponent:0.45].CGColor;
        self.favoritesStateIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:cfg];
        self.favoritesStateIcon.tintColor = accent;
    } else {
        self.favoritesRow.backgroundColor = [UIColor secondarySystemBackgroundColor];
        self.favoritesRow.layer.borderColor = [UIColor separatorColor].CGColor;
        self.favoritesStateIcon.image = [UIImage systemImageNamed:@"circle" withConfiguration:cfg];
        self.favoritesStateIcon.tintColor = [UIColor tertiaryLabelColor];
    }
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
    [self updateFavoritesRowAppearance];
    for (SCIVaultFilterChip *c in self.typeChips) c.selectedChip = NO;
    for (SCIVaultFilterChip *c in self.sourceChips) c.selectedChip = NO;
    if ([self.delegate respondsToSelector:@selector(filterControllerDidClear:)]) {
        [self.delegate filterControllerDidClear:self];
    }
    [self updateClearButton];
}

@end
