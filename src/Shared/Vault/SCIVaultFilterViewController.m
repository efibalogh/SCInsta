#import "SCIVaultFilterViewController.h"
#import "../../Utils.h"

static UIImage *SCIVaultFilterSymbol(NSString *resourceName, NSString *systemFallback, CGFloat pointSize) {
    UIImage *img = resourceName.length > 0
        ? [SCIUtils sci_resourceImageNamed:resourceName template:YES maxPointSize:pointSize]
        : nil;
    if (img) {
        return img;
    }
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                                                      weight:UIImageSymbolWeightMedium];
    return [UIImage systemImageNamed:systemFallback withConfiguration:cfg];
}

static CGFloat const kSCIVaultFilterChipLabelPointSize = 16.0;
static CGFloat const kSCIVaultFilterChipIconPointSize = 14.0;

static NSString *SCIVaultSourceFallbackSymbol(SCIVaultSource source) {
    switch (source) {
        case SCIVaultSourceFeed:      return @"rectangle.stack";
        case SCIVaultSourceStories:   return @"rectangle.portrait.on.rectangle.portrait.angled";
        case SCIVaultSourceReels:     return @"film.stack";
        case SCIVaultSourceProfile:   return @"person.crop.circle";
        case SCIVaultSourceDMs:       return @"bubble.left.and.bubble.right";
        case SCIVaultSourceThumbnail: return @"photo.on.rectangle";
        case SCIVaultSourceOther:
        default:                      return @"tray";
    }
}

@interface SCIVaultFilterChip : UIButton
@property (nonatomic, assign) NSInteger itemTag;
@property (nonatomic, assign) BOOL selectedChip;
- (void)updateChipAppearance;
@end

@implementation SCIVaultFilterChip

- (instancetype)initWithTag:(NSInteger)tag {
    if ((self = [super initWithFrame:CGRectZero])) {
        _itemTag = tag;
        self.layer.cornerRadius = 12;
        self.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        self.titleLabel.font = [UIFont systemFontOfSize:kSCIVaultFilterChipLabelPointSize weight:UIFontWeightMedium];
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
        self.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.2];
        self.tintColor = [UIColor systemBlueColor];
        [self setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    } else {
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        self.tintColor = [UIColor secondaryLabelColor];
        [self setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    }
}

@end

@interface SCIVaultFilterViewController ()

@property (nonatomic, strong) UIStackView *contentStack;

@property (nonatomic, strong) NSMutableArray<SCIVaultFilterChip *> *typeChips;
@property (nonatomic, strong) NSMutableArray<SCIVaultFilterChip *> *sourceChips;
@property (nonatomic, strong) UIControl *favoritesRow;
@property (nonatomic, strong) UIImageView *favoritesLeadingIcon;
@property (nonatomic, strong) UILabel *favoritesLabel;
@property (nonatomic, strong) UIControl *clearRow;
@property (nonatomic, strong) UIImageView *clearLeadingIcon;
@property (nonatomic, strong) UILabel *clearLabel;

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
    [self setupNavigationBar];
    [self setupContent];
    [self updateClearRowState];
}

- (void)setupNavigationBar {
    self.title = @"Filter";
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
}

- (void)setupContent {
    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 10;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.contentStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.contentStack.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-12],
    ]];

    [self.contentStack addArrangedSubview:[self createFavoritesRow]];
    [self.contentStack addArrangedSubview:[self sectionTitle:@"Type"]];
    [self.contentStack addArrangedSubview:[self createTypeRow]];
    [self.contentStack addArrangedSubview:[self sectionTitle:@"Source"]];
    [self.contentStack addArrangedSubview:[self createSourceGrid]];
    [self.contentStack addArrangedSubview:[self sectionTitle:@"Options"]];
    [self.contentStack addArrangedSubview:[self createClearRow]];
}

- (UILabel *)sectionTitle:(NSString *)title {
    UILabel *l = [[UILabel alloc] init];
    l.text = title;
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    l.textColor = [UIColor secondaryLabelColor];
    return l;
}

- (UIView *)createTypeRow {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.distribution = UIStackViewDistributionFillEqually;

    NSArray *defs = @[
        @{@"label": @"Images", @"resource": @"photo", @"fallback": @"photo.fill", @"tag": @(SCIVaultMediaTypeImage)},
        @{@"label": @"Videos", @"resource": @"video", @"fallback": @"video.fill", @"tag": @(SCIVaultMediaTypeVideo)},
    ];
    for (NSDictionary *d in defs) {
        NSInteger tag = [d[@"tag"] integerValue];
        SCIVaultFilterChip *chip = [[SCIVaultFilterChip alloc] initWithTag:tag];
        [chip setTitle:d[@"label"] forState:UIControlStateNormal];
        UIImage *icon = SCIVaultFilterSymbol(d[@"resource"], d[@"fallback"], kSCIVaultFilterChipIconPointSize);
        [chip setImage:icon forState:UIControlStateNormal];
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
    grid.spacing = 8;

    NSArray *sources = @[
        @(SCIVaultSourceFeed), @(SCIVaultSourceStories), @(SCIVaultSourceReels),
        @(SCIVaultSourceProfile), @(SCIVaultSourceDMs), @(SCIVaultSourceThumbnail),
    ];

    UIStackView *currentRow = nil;
    for (NSInteger i = 0; i < sources.count; i++) {
        if (i % 3 == 0) {
            currentRow = [[UIStackView alloc] init];
            currentRow.axis = UILayoutConstraintAxisHorizontal;
            currentRow.spacing = 8;
            currentRow.distribution = UIStackViewDistributionFillEqually;
            [grid addArrangedSubview:currentRow];
        }

        SCIVaultSource src = (SCIVaultSource)[sources[i] integerValue];
        SCIVaultFilterChip *chip = [[SCIVaultFilterChip alloc] initWithTag:src];
        [chip setTitle:[SCIVaultFile labelForSource:src] forState:UIControlStateNormal];
        UIImage *icon = SCIVaultFilterSymbol([SCIVaultFile symbolNameForSource:src], SCIVaultSourceFallbackSymbol(src), kSCIVaultFilterChipIconPointSize);
        [chip setImage:icon forState:UIControlStateNormal];
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
    row.layer.cornerRadius = 12;
    [row.heightAnchor constraintEqualToConstant:50].active = YES;
    [row addTarget:self action:@selector(favoritesRowTapped) forControlEvents:UIControlEventTouchUpInside];

    UIImage *favRowIcon = [SCIUtils sci_resourceImageNamed:@"heart" template:YES maxPointSize:18] ?: [UIImage systemImageNamed:@"heart"];
    UIImageView *icon = [[UIImageView alloc] initWithImage:favRowIcon];
    icon.tintColor = [UIColor labelColor];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Favorites only";
    label.font = [UIFont systemFontOfSize:kSCIVaultFilterChipLabelPointSize weight:UIFontWeightMedium];
    label.textColor = [UIColor secondaryLabelColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    self.favoritesRow = row;
    self.favoritesLeadingIcon = icon;
    self.favoritesLabel = label;
    [self updateFavoritesRowAppearance];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [icon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18],
        [icon.heightAnchor constraintEqualToConstant:18],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor constant:-12],
    ]];
    return row;
}

- (UIView *)createClearRow {
    UIControl *row = [[UIControl alloc] init];
    row.backgroundColor = [UIColor secondarySystemBackgroundColor];
    row.layer.cornerRadius = 12;
    [row.heightAnchor constraintEqualToConstant:50].active = YES;
    [row addTarget:self action:@selector(clearFilters) forControlEvents:UIControlEventTouchUpInside];

    UIImage *clearIcon = [SCIUtils sci_resourceImageNamed:@"backspace" template:YES maxPointSize:18]
        ?: [UIImage systemImageNamed:@"delete.left"];
    UIImageView *icon = [[UIImageView alloc] initWithImage:clearIcon];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Clear filters";
    label.font = [UIFont systemFontOfSize:kSCIVaultFilterChipLabelPointSize weight:UIFontWeightMedium];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    self.clearRow = row;
    self.clearLeadingIcon = icon;
    self.clearLabel = label;

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [icon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18],
        [icon.heightAnchor constraintEqualToConstant:18],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor constant:-12],
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
    [self notifyFilterStateChanged];
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
    [self notifyFilterStateChanged];
}

- (void)favoritesRowTapped {
    self.filterFavoritesOnly = !self.filterFavoritesOnly;
    [self updateFavoritesRowAppearance];
    [self notifyFilterStateChanged];
}

- (void)updateFavoritesRowAppearance {
    if (!self.favoritesRow || !self.favoritesLeadingIcon || !self.favoritesLabel) return;

    if (self.filterFavoritesOnly) {
        UIColor *accent = [UIColor systemPinkColor];
        self.favoritesRow.backgroundColor = [accent colorWithAlphaComponent:0.2];
        self.favoritesLabel.textColor = [UIColor labelColor];
        self.favoritesLeadingIcon.image = [SCIUtils sci_resourceImageNamed:@"heart_filled" template:YES maxPointSize:14.0]
            ?: SCIVaultFilterSymbol(nil, @"heart.fill", 14.0);
        self.favoritesLeadingIcon.tintColor = accent;
    } else {
        self.favoritesRow.backgroundColor = [UIColor secondarySystemBackgroundColor];
        self.favoritesLabel.textColor = [UIColor secondaryLabelColor];
        self.favoritesLeadingIcon.image = [SCIUtils sci_resourceImageNamed:@"heart" template:YES maxPointSize:14.0]
            ?: SCIVaultFilterSymbol(nil, @"heart", 14.0);
        self.favoritesLeadingIcon.tintColor = [UIColor secondaryLabelColor];
    }
}

- (void)updateClearRowState {
    if (!self.clearRow || !self.clearLeadingIcon || !self.clearLabel) return;

    BOOL active = [self hasActiveFilters];
    self.clearRow.userInteractionEnabled = active;
    self.clearRow.backgroundColor = active
        ? [[UIColor systemRedColor] colorWithAlphaComponent:0.2]
        : [UIColor secondarySystemBackgroundColor];
    self.clearLeadingIcon.tintColor = active ? [UIColor systemRedColor] : [UIColor tertiaryLabelColor];
    self.clearLabel.textColor = active ? [UIColor systemRedColor] : [UIColor tertiaryLabelColor];
}

- (BOOL)hasActiveFilters {
    return self.filterTypes.count > 0 || self.filterSources.count > 0 || self.filterFavoritesOnly;
}

- (void)notifyFilterStateChanged {
    [self updateClearRowState];
    if ([self.delegate respondsToSelector:@selector(filterController:didApplyTypes:sources:favoritesOnly:)]) {
        [self.delegate filterController:self
                          didApplyTypes:[self.filterTypes copy]
                                sources:[self.filterSources copy]
                          favoritesOnly:self.filterFavoritesOnly];
    }
}

- (void)clearFilters {
    if (![self hasActiveFilters]) return;
    [self.filterTypes removeAllObjects];
    [self.filterSources removeAllObjects];
    self.filterFavoritesOnly = NO;
    [self updateFavoritesRowAppearance];
    for (SCIVaultFilterChip *c in self.typeChips) c.selectedChip = NO;
    for (SCIVaultFilterChip *c in self.sourceChips) c.selectedChip = NO;
    if ([self.delegate respondsToSelector:@selector(filterControllerDidClear:)]) {
        [self.delegate filterControllerDidClear:self];
    } else {
        [self notifyFilterStateChanged];
    }
    [self updateClearRowState];
}

@end
