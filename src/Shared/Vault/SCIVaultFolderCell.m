#import "SCIVaultFolderCell.h"

@interface SCIVaultFolderCell ()

@property (nonatomic, strong) UIView *listSeparator;
@property (nonatomic, strong) UIStackView *listStack;
@property (nonatomic, strong) UIImageView *listIcon;
@property (nonatomic, strong) UILabel *listTitle;
@property (nonatomic, strong) UIImageView *listChevron;

@end

@implementation SCIVaultFolderCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.contentView.clipsToBounds = YES;
        self.contentView.layer.cornerRadius = 0;
        self.contentView.layer.borderWidth = 0;
        self.contentView.backgroundColor = [UIColor clearColor];

        UIImageSymbolConfiguration *listSym = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        _listIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"folder.fill" withConfiguration:listSym]];
        _listIcon.translatesAutoresizingMaskIntoConstraints = NO;
        _listIcon.tintColor = [UIColor secondaryLabelColor];
        _listIcon.contentMode = UIViewContentModeScaleAspectFit;

        _listTitle = [[UILabel alloc] init];
        _listTitle.translatesAutoresizingMaskIntoConstraints = NO;
        _listTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _listTitle.textColor = [UIColor labelColor];
        _listTitle.numberOfLines = 1;
        _listTitle.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [_listTitle setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [_listTitle setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

        UIImageSymbolConfiguration *chevCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
        _listChevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:chevCfg]];
        _listChevron.translatesAutoresizingMaskIntoConstraints = NO;
        _listChevron.tintColor = [UIColor tertiaryLabelColor];

        _listStack = [[UIStackView alloc] initWithArrangedSubviews:@[_listIcon, _listTitle, _listChevron]];
        _listStack.translatesAutoresizingMaskIntoConstraints = NO;
        _listStack.axis = UILayoutConstraintAxisHorizontal;
        _listStack.alignment = UIStackViewAlignmentCenter;
        _listStack.spacing = 12;
        _listStack.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 12);
        _listStack.layoutMarginsRelativeArrangement = YES;
        [_listStack setCustomSpacing:4 afterView:_listTitle];
        [self.contentView addSubview:_listStack];

        UIView *sep = [[UIView alloc] init];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        sep.backgroundColor = [UIColor separatorColor];
        [self.contentView addSubview:sep];
        _listSeparator = sep;

        [NSLayoutConstraint activateConstraints:@[
            [_listStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_listStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_listStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_listStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [_listIcon.widthAnchor constraintEqualToConstant:32],
            [_listIcon.heightAnchor constraintEqualToConstant:32],

            [sep.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:60],
            [sep.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [sep.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [sep.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _listTitle.text = nil;
    _listSeparator.hidden = NO;
}

- (void)configureWithFolderName:(NSString *)name {
    _listTitle.text = name;
}

@end
