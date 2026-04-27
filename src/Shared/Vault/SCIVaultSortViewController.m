#import "SCIVaultSortViewController.h"
#import "../../AssetUtils.h"
#import "../../Utils.h"

static NSString *SCIVaultSortResourceSymbol(SCIVaultSortMode mode) {
    switch (mode) {
        case SCIVaultSortModeDateAddedDesc:
        case SCIVaultSortModeDateAddedAsc:
            return @"calendar";
        case SCIVaultSortModeNameAsc:
        case SCIVaultSortModeNameDesc:
            return @"text";
        case SCIVaultSortModeSizeDesc:
            return @"size_large";
        case SCIVaultSortModeSizeAsc:
            return @"size_small";
        case SCIVaultSortModeTypeAsc:
            return @"photo";
        case SCIVaultSortModeTypeDesc:
            return @"video";
    }
    return @"sort";
}

@interface SCIVaultSortChip : UIButton
@property (nonatomic, assign) SCIVaultSortMode mode;
@property (nonatomic, assign) BOOL selectedChip;
- (void)updateChipAppearance;
@end

@implementation SCIVaultSortChip

- (instancetype)initWithMode:(SCIVaultSortMode)mode {
    if ((self = [super initWithFrame:CGRectZero])) {
        _mode = mode;
        self.layer.cornerRadius = 12;
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
        self.backgroundColor = [[SCIUtils SCIColor_Primary] colorWithAlphaComponent:0.18];
        self.tintColor = [SCIUtils SCIColor_Primary];
        [self setTitleColor:[SCIUtils SCIColor_InstagramPrimaryText] forState:UIControlStateNormal];
        self.layer.borderColor = [SCIUtils SCIColor_Primary].CGColor;
    } else {
        self.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
        self.tintColor = [SCIUtils SCIColor_InstagramSecondaryText];
        [self setTitleColor:[SCIUtils SCIColor_InstagramPrimaryText] forState:UIControlStateNormal];
        self.layer.borderColor = [SCIUtils SCIColor_InstagramSeparator].CGColor;
    }
}

@end

@interface SCIVaultSortViewController ()
@property (nonatomic, strong) NSMutableArray<SCIVaultSortChip *> *chips;
@end

@implementation SCIVaultSortViewController

+ (NSArray<NSSortDescriptor *> *)sortDescriptorsForMode:(SCIVaultSortMode)mode {
    switch (mode) {
        case SCIVaultSortModeDateAddedDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
        case SCIVaultSortModeDateAddedAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:YES]];
        case SCIVaultSortModeNameAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"relativePath" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]];
        case SCIVaultSortModeNameDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"relativePath" ascending:NO selector:@selector(localizedCaseInsensitiveCompare:)]];
        case SCIVaultSortModeSizeDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"fileSize" ascending:NO]];
        case SCIVaultSortModeSizeAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"fileSize" ascending:YES]];
        case SCIVaultSortModeTypeAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"mediaType" ascending:YES],
                     [NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
        case SCIVaultSortModeTypeDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"mediaType" ascending:NO],
                     [NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
    }
    return @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
}

+ (NSString *)labelForMode:(SCIVaultSortMode)mode {
    switch (mode) {
        case SCIVaultSortModeDateAddedDesc: return @"Newest first";
        case SCIVaultSortModeDateAddedAsc:  return @"Oldest first";
        case SCIVaultSortModeNameAsc:       return @"Name A-Z";
        case SCIVaultSortModeNameDesc:      return @"Name Z-A";
        case SCIVaultSortModeSizeDesc:      return @"Largest first";
        case SCIVaultSortModeSizeAsc:       return @"Smallest first";
        case SCIVaultSortModeTypeAsc:       return @"Images first";
        case SCIVaultSortModeTypeDesc:      return @"Videos first";
    }
    return @"Newest first";
}

- (instancetype)init {
    if ((self = [super init])) {
        _chips = [NSMutableArray new];
        _currentSortMode = SCIVaultSortModeDateAddedDesc;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramBackground];
    [self setupNavigationBar];
    [self setupContent];
}

- (void)setupNavigationBar {
    self.title = @"Sort";
}

- (void)setupContent {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-20],
    ]];

    NSArray<NSArray<NSNumber *> *> *rows = @[
        @[@(SCIVaultSortModeDateAddedDesc), @(SCIVaultSortModeDateAddedAsc)],
        @[@(SCIVaultSortModeNameAsc),       @(SCIVaultSortModeNameDesc)],
        @[@(SCIVaultSortModeSizeDesc),      @(SCIVaultSortModeSizeAsc)],
        @[@(SCIVaultSortModeTypeAsc),       @(SCIVaultSortModeTypeDesc)],
    ];

    for (NSInteger i = 0; i < rows.count; i++) {
        UIStackView *row = [[UIStackView alloc] init];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 10;
        row.distribution = UIStackViewDistributionFillEqually;

        for (NSNumber *modeNum in rows[i]) {
            SCIVaultSortMode mode = (SCIVaultSortMode)modeNum.integerValue;
            SCIVaultSortChip *chip = [[SCIVaultSortChip alloc] initWithMode:mode];
            [chip setTitle:[SCIVaultSortViewController labelForMode:mode] forState:UIControlStateNormal];
            UIImage *icon = [SCIAssetUtils instagramIconNamed:SCIVaultSortResourceSymbol(mode) pointSize:14.0];
            [chip setImage:icon forState:UIControlStateNormal];
            chip.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
            chip.selectedChip = (mode == self.currentSortMode);
            [chip addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
            [chip.heightAnchor constraintEqualToConstant:44].active = YES;
            [row addArrangedSubview:chip];
            [self.chips addObject:chip];
        }
        [stack addArrangedSubview:row];
    }
}

- (void)chipTapped:(SCIVaultSortChip *)chip {
    self.currentSortMode = chip.mode;
    for (SCIVaultSortChip *c in self.chips) c.selectedChip = (c.mode == chip.mode);
    if ([self.delegate respondsToSelector:@selector(sortController:didSelectSortMode:)]) {
        [self.delegate sortController:self didSelectSortMode:self.currentSortMode];
    }
    [self dismissController];
}

- (void)dismissController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
