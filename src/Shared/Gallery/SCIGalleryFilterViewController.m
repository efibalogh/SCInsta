#import "SCIGalleryFilterViewController.h"
#import "../../AssetUtils.h"
#import "../../Utils.h"

static CGFloat const kSCIGalleryFilterChipLabelPointSize = 16.0;
static CGFloat const kSCIGalleryFilterChipIconPointSize = 14.0;

@interface SCIGalleryFilterChip : UIButton
@property (nonatomic, assign) NSInteger itemTag;
@property (nonatomic, assign) BOOL selectedChip;
- (void)updateChipAppearance;
@end

@implementation SCIGalleryFilterChip

- (instancetype)initWithTag:(NSInteger)tag {
    if ((self = [super initWithFrame:CGRectZero])) {
        _itemTag = tag;
        self.layer.cornerRadius = 12;
        self.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        self.titleLabel.font = [UIFont systemFontOfSize:kSCIGalleryFilterChipLabelPointSize weight:UIFontWeightMedium];
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
        self.backgroundColor = [[SCIUtils SCIColor_Primary] colorWithAlphaComponent:0.18];
        self.tintColor = [SCIUtils SCIColor_Primary];
        [self setTitleColor:[SCIUtils SCIColor_InstagramPrimaryText] forState:UIControlStateNormal];
    } else {
        self.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
        self.tintColor = [SCIUtils SCIColor_InstagramSecondaryText];
        [self setTitleColor:[SCIUtils SCIColor_InstagramPrimaryText] forState:UIControlStateNormal];
    }
}

@end

@interface SCIGalleryFilterViewController ()

@property (nonatomic, strong) UIStackView *contentStack;

@property (nonatomic, strong) NSMutableArray<SCIGalleryFilterChip *> *typeChips;
@property (nonatomic, strong) NSMutableArray<SCIGalleryFilterChip *> *sourceChips;
@property (nonatomic, strong) NSMutableArray<SCIGalleryFilterChip *> *usernameChips;
@property (nonatomic, strong) UILabel *usernameSectionTitle;
@property (nonatomic, strong) UIControl *favoritesRow;
@property (nonatomic, strong) UIImageView *favoritesLeadingIcon;
@property (nonatomic, strong) UILabel *favoritesLabel;
@property (nonatomic, strong) UIControl *clearRow;
@property (nonatomic, strong) UIImageView *clearLeadingIcon;
@property (nonatomic, strong) UILabel *clearLabel;

@end

@implementation SCIGalleryFilterViewController

+ (NSPredicate *)predicateForTypes:(NSSet<NSNumber *> *)types
                           sources:(NSSet<NSNumber *> *)sources
                     favoritesOnly:(BOOL)favoritesOnly
                           usernames:(NSSet<NSString *> *)usernames
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
    if (usernames.count > 0) {
        NSMutableArray<NSPredicate *> *usernameParts = [NSMutableArray array];
        for (NSString *username in usernames) {
            if (username.length == 0) continue;
            [usernameParts addObject:[NSPredicate predicateWithFormat:@"sourceUsername ==[c] %@", username]];
        }
        if (usernameParts.count > 0) {
            [parts addObject:[NSCompoundPredicate orPredicateWithSubpredicates:usernameParts]];
        }
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
        _usernameChips = [NSMutableArray new];
        _filterUsernames = [NSMutableSet new];
        _availableUsernames = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramBackground];
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
    if (self.availableUsernames.count > 0) {
        self.usernameSectionTitle = [self sectionTitle:@"Username"];
        [self updateUsernameSectionTitle];
        [self.contentStack addArrangedSubview:self.usernameSectionTitle];
        [self.contentStack addArrangedSubview:[self createUsernameRow]];
    }
    [self.contentStack addArrangedSubview:[self sectionTitle:@"Options"]];
    [self.contentStack addArrangedSubview:[self createClearRow]];
}

- (UILabel *)sectionTitle:(NSString *)title {
    UILabel *l = [[UILabel alloc] init];
    l.text = title;
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    l.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
    return l;
}

- (UIView *)createTypeRow {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.distribution = UIStackViewDistributionFillEqually;

    NSArray *defs = @[
        @{@"label": @"Images", @"resource": @"photo", @"tag": @(SCIGalleryMediaTypeImage)},
        @{@"label": @"Videos", @"resource": @"video", @"tag": @(SCIGalleryMediaTypeVideo)},
    ];
    for (NSDictionary *d in defs) {
        NSInteger tag = [d[@"tag"] integerValue];
        SCIGalleryFilterChip *chip = [[SCIGalleryFilterChip alloc] initWithTag:tag];
        [chip setTitle:d[@"label"] forState:UIControlStateNormal];
        UIImage *icon = [SCIAssetUtils instagramIconNamed:d[@"resource"] pointSize:kSCIGalleryFilterChipIconPointSize];
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
        @(SCIGallerySourceFeed), @(SCIGallerySourceStories), @(SCIGallerySourceReels),
        @(SCIGallerySourceProfile), @(SCIGallerySourceDMs), @(SCIGallerySourceThumbnail),
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

        SCIGallerySource src = (SCIGallerySource)[sources[i] integerValue];
        SCIGalleryFilterChip *chip = [[SCIGalleryFilterChip alloc] initWithTag:src];
        [chip setTitle:[SCIGalleryFile labelForSource:src] forState:UIControlStateNormal];
        UIImage *icon = [SCIAssetUtils instagramIconNamed:[SCIGalleryFile symbolNameForSource:src] pointSize:kSCIGalleryFilterChipIconPointSize];
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

- (UIView *)createUsernameRow {
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.delaysContentTouches = YES;
    scrollView.canCancelContentTouches = YES;
    scrollView.directionalLockEnabled = YES;
    scrollView.alwaysBounceHorizontal = YES;
    [scrollView.heightAnchor constraintEqualToConstant:44].active = YES;

    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [row.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [row.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [row.heightAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.heightAnchor],
    ]];

    for (NSString *username in self.availableUsernames) {
        SCIGalleryFilterChip *chip = [[SCIGalleryFilterChip alloc] initWithTag:self.usernameChips.count];
        [chip setTitle:username forState:UIControlStateNormal];
        UIImage *icon = [SCIAssetUtils instagramIconNamed:@"mention" pointSize:kSCIGalleryFilterChipIconPointSize];
        [chip setImage:icon forState:UIControlStateNormal];
        chip.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
        chip.selectedChip = [self usernameFilterContainsUsername:username];
        [chip addTarget:self action:@selector(usernameChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chip.heightAnchor constraintEqualToConstant:44].active = YES;
        [row addArrangedSubview:chip];
        [self.usernameChips addObject:chip];
    }
    return scrollView;
}

- (UIView *)createFavoritesRow {
    UIControl *row = [[UIControl alloc] init];
    row.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    row.layer.cornerRadius = 12;
    [row.heightAnchor constraintEqualToConstant:50].active = YES;
    [row addTarget:self action:@selector(favoritesRowTapped) forControlEvents:UIControlEventTouchUpInside];

    UIImage *favRowIcon = [SCIAssetUtils instagramIconNamed:@"heart" pointSize:18.0];
    UIImageView *icon = [[UIImageView alloc] initWithImage:favRowIcon];
    icon.tintColor = [SCIUtils SCIColor_InstagramPrimaryText];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Favorites only";
    label.font = [UIFont systemFontOfSize:kSCIGalleryFilterChipLabelPointSize weight:UIFontWeightMedium];
    label.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
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
    row.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    row.layer.cornerRadius = 12;
    [row.heightAnchor constraintEqualToConstant:50].active = YES;
    [row addTarget:self action:@selector(clearFilters) forControlEvents:UIControlEventTouchUpInside];

    UIImage *clearIcon = [SCIAssetUtils instagramIconNamed:@"backspace" pointSize:18.0];
    UIImageView *icon = [[UIImageView alloc] initWithImage:clearIcon];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Clear filters";
    label.font = [UIFont systemFontOfSize:kSCIGalleryFilterChipLabelPointSize weight:UIFontWeightMedium];
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

- (void)typeChipTapped:(SCIGalleryFilterChip *)chip {
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

- (void)sourceChipTapped:(SCIGalleryFilterChip *)chip {
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

- (void)usernameChipTapped:(SCIGalleryFilterChip *)chip {
    NSInteger index = chip.itemTag;
    if (index < 0 || index >= (NSInteger)self.availableUsernames.count) return;
    NSString *username = self.availableUsernames[index];
    NSString *existing = [self matchingSelectedUsernameForUsername:username];
    if (existing.length > 0) {
        [self.filterUsernames removeObject:existing];
    } else {
        [self.filterUsernames addObject:username];
    }
    for (SCIGalleryFilterChip *candidate in self.usernameChips) {
        NSInteger candidateIndex = candidate.itemTag;
        NSString *candidateUsername = candidateIndex >= 0 && candidateIndex < (NSInteger)self.availableUsernames.count ? self.availableUsernames[candidateIndex] : nil;
        candidate.selectedChip = [self usernameFilterContainsUsername:candidateUsername];
    }
    [self updateUsernameSectionTitle];
    [self notifyFilterStateChanged];
}

- (NSString *)matchingSelectedUsernameForUsername:(NSString *)username {
    if (username.length == 0) return nil;
    for (NSString *selectedUsername in self.filterUsernames) {
        if ([selectedUsername caseInsensitiveCompare:username] == NSOrderedSame) return selectedUsername;
    }
    return nil;
}

- (BOOL)usernameFilterContainsUsername:(NSString *)username {
    return [self matchingSelectedUsernameForUsername:username].length > 0;
}

- (void)updateUsernameSectionTitle {
    if (!self.usernameSectionTitle) return;
    NSUInteger count = self.filterUsernames.count;
    self.usernameSectionTitle.text = count > 0 ? [NSString stringWithFormat:@"Username (%lu selected)", (unsigned long)count] : @"Username";
}

- (void)favoritesRowTapped {
    self.filterFavoritesOnly = !self.filterFavoritesOnly;
    [self updateFavoritesRowAppearance];
    [self notifyFilterStateChanged];
}

- (void)updateFavoritesRowAppearance {
    if (!self.favoritesRow || !self.favoritesLeadingIcon || !self.favoritesLabel) return;

    if (self.filterFavoritesOnly) {
        UIColor *accent = [SCIUtils SCIColor_InstagramFavorite];
        self.favoritesRow.backgroundColor = [accent colorWithAlphaComponent:0.2];
        self.favoritesLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
        self.favoritesLeadingIcon.image = [SCIAssetUtils instagramIconNamed:@"heart_filled" pointSize:14.0];
        self.favoritesLeadingIcon.tintColor = accent;
    } else {
        self.favoritesRow.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
        self.favoritesLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
        self.favoritesLeadingIcon.image = [SCIAssetUtils instagramIconNamed:@"heart" pointSize:14.0];
        self.favoritesLeadingIcon.tintColor = [SCIUtils SCIColor_InstagramSecondaryText];
    }
}

- (void)updateClearRowState {
    if (!self.clearRow || !self.clearLeadingIcon || !self.clearLabel) return;

    BOOL active = [self hasActiveFilters];
    self.clearRow.userInteractionEnabled = active;
    self.clearRow.backgroundColor = active
        ? [[SCIUtils SCIColor_InstagramDestructive] colorWithAlphaComponent:0.16]
        : [SCIUtils SCIColor_InstagramSecondaryBackground];
    self.clearLeadingIcon.tintColor = active ? [SCIUtils SCIColor_InstagramDestructive] : [SCIUtils SCIColor_InstagramTertiaryText];
    self.clearLabel.textColor = active ? [SCIUtils SCIColor_InstagramDestructive] : [SCIUtils SCIColor_InstagramTertiaryText];
}

- (BOOL)hasActiveFilters {
    return self.filterTypes.count > 0 || self.filterSources.count > 0 || self.filterFavoritesOnly || self.filterUsernames.count > 0;
}

- (void)notifyFilterStateChanged {
    [self updateClearRowState];
    if ([self.delegate respondsToSelector:@selector(filterController:didApplyTypes:sources:favoritesOnly:usernames:)]) {
        [self.delegate filterController:self
                          didApplyTypes:[self.filterTypes copy]
                                sources:[self.filterSources copy]
                          favoritesOnly:self.filterFavoritesOnly
                              usernames:[self.filterUsernames copy]];
    }
}

- (void)clearFilters {
    if (![self hasActiveFilters]) return;
    [self.filterTypes removeAllObjects];
    [self.filterSources removeAllObjects];
    self.filterFavoritesOnly = NO;
    [self.filterUsernames removeAllObjects];
    [self updateFavoritesRowAppearance];
    for (SCIGalleryFilterChip *c in self.typeChips) c.selectedChip = NO;
    for (SCIGalleryFilterChip *c in self.sourceChips) c.selectedChip = NO;
    for (SCIGalleryFilterChip *c in self.usernameChips) c.selectedChip = NO;
    [self updateUsernameSectionTitle];
    if ([self.delegate respondsToSelector:@selector(filterControllerDidClear:)]) {
        [self.delegate filterControllerDidClear:self];
    } else {
        [self notifyFilterStateChanged];
    }
    [self updateClearRowState];
}

@end
