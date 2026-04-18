#import "SCIVaultFolderCell.h"

@interface SCIVaultFolderCell ()

@property (nonatomic, strong) UIView *listSeparator;

@property (nonatomic, strong) UIStackView *gridStack;
@property (nonatomic, strong) UIStackView *listStack;

@property (nonatomic, strong) UIView *gridIconBubble;
@property (nonatomic, strong) UIImageView *gridIcon;
@property (nonatomic, strong) UILabel *gridTitle;

@property (nonatomic, strong) UIImageView *listIcon;
@property (nonatomic, strong) UILabel *listTitle;
@property (nonatomic, strong) UIImageView *listChevron;

@end

@implementation SCIVaultFolderCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.contentView.clipsToBounds = YES;
        self.contentView.layer.cornerRadius = 10.0;
        self.contentView.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];

        UIImageSymbolConfiguration *gridSym = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold];
        _gridIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"folder.fill" withConfiguration:gridSym]];
        _gridIcon.translatesAutoresizingMaskIntoConstraints = NO;
        _gridIcon.tintColor = [UIColor systemYellowColor];
        _gridIcon.contentMode = UIViewContentModeScaleAspectFit;

        _gridIconBubble = [[UIView alloc] initWithFrame:CGRectZero];
        _gridIconBubble.translatesAutoresizingMaskIntoConstraints = NO;
        _gridIconBubble.backgroundColor = [UIColor systemBackgroundColor];
        _gridIconBubble.layer.cornerRadius = 19.0;
        _gridIconBubble.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.35].CGColor;
        _gridIconBubble.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        [_gridIconBubble addSubview:_gridIcon];

        _gridTitle = [[UILabel alloc] init];
        _gridTitle.translatesAutoresizingMaskIntoConstraints = NO;
        _gridTitle.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        _gridTitle.textColor = [UIColor secondaryLabelColor];
        _gridTitle.textAlignment = NSTextAlignmentCenter;
        _gridTitle.numberOfLines = 2;
        _gridTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _gridTitle.adjustsFontSizeToFitWidth = YES;
        _gridTitle.minimumScaleFactor = 0.85;

        _gridStack = [[UIStackView alloc] initWithArrangedSubviews:@[_gridIconBubble, _gridTitle]];
        _gridStack.translatesAutoresizingMaskIntoConstraints = NO;
        _gridStack.axis = UILayoutConstraintAxisVertical;
        _gridStack.alignment = UIStackViewAlignmentCenter;
        _gridStack.spacing = 8;
        _gridStack.layoutMargins = UIEdgeInsetsMake(10, 8, 10, 8);
        _gridStack.layoutMarginsRelativeArrangement = YES;
        [self.contentView addSubview:_gridStack];

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
        sep.hidden = YES;
        [self.contentView addSubview:sep];
        _listSeparator = sep;

        [NSLayoutConstraint activateConstraints:@[
            [_gridStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_gridStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_gridStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_gridStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [_gridIconBubble.widthAnchor constraintEqualToConstant:38],
            [_gridIconBubble.heightAnchor constraintEqualToConstant:38],
            [_gridIcon.centerXAnchor constraintEqualToAnchor:_gridIconBubble.centerXAnchor],
            [_gridIcon.centerYAnchor constraintEqualToAnchor:_gridIconBubble.centerYAnchor],
            [_gridIcon.widthAnchor constraintEqualToConstant:24],
            [_gridIcon.heightAnchor constraintEqualToConstant:24],

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
    _gridTitle.text = nil;
    _listTitle.text = nil;
}

- (void)configureWithFolderName:(NSString *)name listStyle:(BOOL)listStyle {
    _gridStack.hidden = listStyle;
    _listStack.hidden = !listStyle;

    _gridTitle.text = name;
    _listTitle.text = name;

    if (listStyle) {
        self.contentView.layer.cornerRadius = 0;
        self.contentView.layer.borderWidth = 0;
        self.contentView.backgroundColor = [UIColor clearColor];
        self.listSeparator.hidden = NO;
    } else {
        self.contentView.layer.cornerRadius = 10.0;
        self.contentView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.contentView.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.35].CGColor;
        self.contentView.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        self.listSeparator.hidden = YES;
    }
}

@end
