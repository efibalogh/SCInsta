#import "SCIGallerySortViewController.h"
#import "../../AssetUtils.h"
#import "../../Utils.h"

static NSString *SCIGallerySortResourceSymbol(SCIGallerySortMode mode) {
    switch (mode) {
        case SCIGallerySortModeDateAddedDesc:
        case SCIGallerySortModeDateAddedAsc:
            return @"calendar";
        case SCIGallerySortModeNameAsc:
        case SCIGallerySortModeNameDesc:
            return @"text";
        case SCIGallerySortModeSizeDesc:
            return @"size_large";
        case SCIGallerySortModeSizeAsc:
            return @"size_small";
        case SCIGallerySortModeTypeAsc:
            return @"photo";
        case SCIGallerySortModeTypeDesc:
            return @"video";
    }
    return @"sort";
}

@interface SCIGallerySortChip : UIButton
@property (nonatomic, assign) SCIGallerySortMode mode;
@property (nonatomic, assign) BOOL selectedChip;
- (void)updateChipAppearance;
@end

@implementation SCIGallerySortChip

- (instancetype)initWithMode:(SCIGallerySortMode)mode {
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

@interface SCIGallerySortViewController ()
@property (nonatomic, strong) NSMutableArray<SCIGallerySortChip *> *chips;
@end

@implementation SCIGallerySortViewController

+ (NSArray<NSSortDescriptor *> *)sortDescriptorsForMode:(SCIGallerySortMode)mode {
    switch (mode) {
        case SCIGallerySortModeDateAddedDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
        case SCIGallerySortModeDateAddedAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:YES]];
        case SCIGallerySortModeNameAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"relativePath" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]];
        case SCIGallerySortModeNameDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"relativePath" ascending:NO selector:@selector(localizedCaseInsensitiveCompare:)]];
        case SCIGallerySortModeSizeDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"fileSize" ascending:NO]];
        case SCIGallerySortModeSizeAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"fileSize" ascending:YES]];
        case SCIGallerySortModeTypeAsc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"mediaType" ascending:YES],
                     [NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
        case SCIGallerySortModeTypeDesc:
            return @[[NSSortDescriptor sortDescriptorWithKey:@"mediaType" ascending:NO],
                     [NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
    }
    return @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];
}

+ (NSString *)labelForMode:(SCIGallerySortMode)mode {
    switch (mode) {
        case SCIGallerySortModeDateAddedDesc: return @"Newest first";
        case SCIGallerySortModeDateAddedAsc:  return @"Oldest first";
        case SCIGallerySortModeNameAsc:       return @"Name A-Z";
        case SCIGallerySortModeNameDesc:      return @"Name Z-A";
        case SCIGallerySortModeSizeDesc:      return @"Largest first";
        case SCIGallerySortModeSizeAsc:       return @"Smallest first";
        case SCIGallerySortModeTypeAsc:       return @"Images first";
        case SCIGallerySortModeTypeDesc:      return @"Videos first";
    }
    return @"Newest first";
}

- (instancetype)init {
    if ((self = [super init])) {
        _chips = [NSMutableArray new];
        _currentSortMode = SCIGallerySortModeDateAddedDesc;
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
        @[@(SCIGallerySortModeDateAddedDesc), @(SCIGallerySortModeDateAddedAsc)],
        @[@(SCIGallerySortModeNameAsc),       @(SCIGallerySortModeNameDesc)],
        @[@(SCIGallerySortModeSizeDesc),      @(SCIGallerySortModeSizeAsc)],
        @[@(SCIGallerySortModeTypeAsc),       @(SCIGallerySortModeTypeDesc)],
    ];

    for (NSInteger i = 0; i < rows.count; i++) {
        UIStackView *row = [[UIStackView alloc] init];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 10;
        row.distribution = UIStackViewDistributionFillEqually;

        for (NSNumber *modeNum in rows[i]) {
            SCIGallerySortMode mode = (SCIGallerySortMode)modeNum.integerValue;
            SCIGallerySortChip *chip = [[SCIGallerySortChip alloc] initWithMode:mode];
            [chip setTitle:[SCIGallerySortViewController labelForMode:mode] forState:UIControlStateNormal];
            UIImage *icon = [SCIAssetUtils instagramIconNamed:SCIGallerySortResourceSymbol(mode) pointSize:14.0];
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

- (void)chipTapped:(SCIGallerySortChip *)chip {
    self.currentSortMode = chip.mode;
    for (SCIGallerySortChip *c in self.chips) c.selectedChip = (c.mode == chip.mode);
    if ([self.delegate respondsToSelector:@selector(sortController:didSelectSortMode:)]) {
        [self.delegate sortController:self didSelectSortMode:self.currentSortMode];
    }
    [self dismissController];
}

- (void)dismissController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
