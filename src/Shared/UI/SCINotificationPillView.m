#import "SCINotificationPillView.h"
#import <math.h>
#import "../../AssetUtils.h"

@interface SCIUtils : NSObject
+ (UIColor *)SCIColor_Primary;
+ (BOOL)getBoolPref:(NSString *)key;
@end

static CGFloat const kPillCorner     = 28.0;
static CGFloat const kHorizontalPad  = 16.0;
static CGFloat const kDynamicMinWidth = 200.0;
static CGFloat const kDynamicMaxWidth = 320.0;
static CGFloat const kRingLineWidth   = 2.5;
static CGFloat const kDynamicPillHeight = 52.0;
static CGFloat const kDynamicTallHeight = 64.0;
static CGFloat const kIconBadgeSize  = 28.0;
static CGFloat const kEntranceTranslateY = -24.0;
static CGFloat const kEntranceScale = 0.88;

static CGAffineTransform SCIPillEntranceTransform(void) {
    CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, kEntranceTranslateY);
    CGAffineTransform scale = CGAffineTransformMakeScale(kEntranceScale, kEntranceScale);
    return CGAffineTransformConcat(translate, scale);
}

typedef NS_ENUM(NSUInteger, SCINotificationPillMode) {
    SCINotificationPillModeProgress = 0,
    SCINotificationPillModeToast = 1
};

typedef NS_ENUM(NSUInteger, SCIPillVisualTone) {
    SCIPillVisualToneSuccess = 0,
    SCIPillVisualToneError = 1,
    SCIPillVisualToneInfo = 2
};

@interface SCINotificationPillView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView             *chromeOverlayView;
@property (nonatomic, strong) CAGradientLayer    *chromeGradientLayer;
@property (nonatomic, strong) UILabel            *titleLabel;
@property (nonatomic, strong) UILabel            *subtitleLabel;
@property (nonatomic, strong) UIStackView        *textStack;
@property (nonatomic, strong) UIProgressView       *progressView;
@property (nonatomic, strong) UIView               *progressRowContainer;
@property (nonatomic, strong) UIImageView        *iconView;
@property (nonatomic, strong) UIView             *iconBadgeView;
@property (nonatomic, strong) CAGradientLayer    *iconBadgeGradientLayer;
@property (nonatomic, strong) UIButton           *closeButton;
@property (nonatomic, assign) float              currentProgress;
@property (nonatomic, assign) BOOL               isCompleted;
@property (nonatomic, assign) SCINotificationPillMode mode;
@property (nonatomic, assign) SCIPillVisualTone tone;
@property (nonatomic, strong) NSLayoutConstraint *textCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textTrailingWithButtonConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textTrailingWithoutButtonConstraint;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *progressHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *progressRowHeightConstraint;
@property (nonatomic, assign) BOOL isErrorState;

// --- Dynamic style properties ---
@property (nonatomic, strong) CAShapeLayer *progressRingTrackLayer;
@property (nonatomic, strong) CAShapeLayer *progressRingLayer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, assign) CGPoint panOriginCenter;

- (void)applyCurrentVisualStyleAnimated:(BOOL)animated;
- (void)sci_applyProgressModeInfoIcon;
- (CGFloat)sci_subtitleRowLayoutHeight;
- (CGFloat)sci_progressBarHeightMatchingSubtitle;
- (float)sanitizedProgressValue:(float)progress;
// Dynamic style helpers
- (void)sci_updateRingPath;
- (UIColor *)sci_glowColorForTone:(SCIPillVisualTone)tone;
- (void)sci_updateDynamicWidthForTitle:(NSString *)title subtitle:(NSString *)subtitle hasButton:(BOOL)hasButton;
- (void)handlePan:(UIPanGestureRecognizer *)pan;
@end

@implementation SCINotificationPillView

#pragma mark - Factory

+ (SCINotificationPillView *)detachedPill {
    SCINotificationPillView *pill = [[SCINotificationPillView alloc] init];
    [pill applyCurrentVisualStyleAnimated:NO];
    pill.translatesAutoresizingMaskIntoConstraints = NO;

    pill.heightConstraint = [pill.heightAnchor constraintEqualToConstant:kDynamicPillHeight];
    pill.widthConstraint = [pill.widthAnchor constraintEqualToConstant:kDynamicMinWidth];
    [NSLayoutConstraint activateConstraints:@[
        pill.widthConstraint,
        pill.heightConstraint
    ]];

    return pill;
}

+ (instancetype)progressPill {
    SCINotificationPillView *pill = [self detachedPill];
    [pill configureForProgressMode];
    return pill;
}

+ (instancetype)toastPillWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                               icon:(UIImage *)icon
                               tone:(SCINotificationTone)tone {
    SCINotificationPillView *pill = [self detachedPill];
    [pill configureForToastModeWithTitle:title subtitle:subtitle icon:icon tone:tone];
    return pill;
}

- (void)setPresentationTopConstraint:(NSLayoutConstraint *)constraint {
    self.topConstraint = constraint;
}

#pragma mark - Init

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.layer.cornerRadius = kPillCorner;
    self.clipsToBounds = YES;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.borderWidth = 0.65;
    self.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.18] CGColor];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_blurView];

    [NSLayoutConstraint activateConstraints:@[
        [_blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];

    _chromeOverlayView = [[UIView alloc] init];
    _chromeOverlayView.userInteractionEnabled = NO;
    _chromeOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_chromeOverlayView];

    [NSLayoutConstraint activateConstraints:@[
        [_chromeOverlayView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_chromeOverlayView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_chromeOverlayView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_chromeOverlayView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];

    _chromeGradientLayer = [CAGradientLayer layer];
    _chromeGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _chromeGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    _chromeGradientLayer.opacity = 0.9;
    [_chromeOverlayView.layer addSublayer:_chromeGradientLayer];

    _iconBadgeView = [[UIView alloc] init];
    _iconBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconBadgeView.layer.cornerCurve = kCACornerCurveContinuous;
    _iconBadgeView.layer.cornerRadius = kIconBadgeSize / 2.0;
    _iconBadgeView.layer.borderWidth = 0.5;
    _iconBadgeView.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.24] CGColor];
    _iconBadgeView.clipsToBounds = YES;
    [self addSubview:_iconBadgeView];

    _iconBadgeGradientLayer = [CAGradientLayer layer];
    _iconBadgeGradientLayer.startPoint = CGPointMake(0.0, 0.2);
    _iconBadgeGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [_iconBadgeView.layer insertSublayer:_iconBadgeGradientLayer atIndex:0];

    UIImage *arrowImage = [SCIAssetUtils instagramIconNamed:@"download"
                                                  pointSize:16.0
                                             renderingMode:UIImageRenderingModeAlwaysTemplate];
    _iconView = [[UIImageView alloc] initWithImage:arrowImage];
    _iconView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconBadgeView addSubview:_iconView];

    [NSLayoutConstraint activateConstraints:@[
        [_iconBadgeView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kHorizontalPad],
        [_iconBadgeView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_iconBadgeView.widthAnchor constraintEqualToConstant:kIconBadgeSize],
        [_iconBadgeView.heightAnchor constraintEqualToConstant:kIconBadgeSize],
        [_iconView.centerXAnchor constraintEqualToAnchor:_iconBadgeView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconBadgeView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:16.0],
        [_iconView.heightAnchor constraintEqualToConstant:16.0],
    ]];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self applyCancelButtonStyle];
    _closeButton.layer.cornerRadius = 12.0;
    _closeButton.layer.cornerCurve = kCACornerCurveContinuous;
    _closeButton.layer.borderWidth = 0.5;
    _closeButton.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.22] CGColor];
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [_closeButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-13.0],
        [_closeButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_closeButton.widthAnchor constraintEqualToConstant:24.0],
        [_closeButton.heightAnchor constraintEqualToConstant:24.0],
    ]];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = @"Downloading...";
    _titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.98];
    _titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    _subtitleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    _subtitleLabel.numberOfLines = 1;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.hidden = YES;

    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    _progressView.translatesAutoresizingMaskIntoConstraints = NO;
    _progressView.hidden = YES;
    _progressView.progress = 0.0f;
    _progressView.clipsToBounds = YES;
    _progressView.layer.cornerCurve = kCACornerCurveContinuous;
    _progressView.layer.cornerRadius = 0.0;

    _progressRowContainer = [[UIView alloc] init];
    _progressRowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _progressRowContainer.backgroundColor = [UIColor clearColor];
    _progressRowContainer.hidden = YES;
    [_progressRowContainer addSubview:_progressView];

    _progressHeightConstraint = [_progressView.heightAnchor constraintEqualToConstant:0.0];
    _progressRowHeightConstraint = [_progressRowContainer.heightAnchor constraintEqualToConstant:0.0];
    [NSLayoutConstraint activateConstraints:@[
        [_progressView.leadingAnchor constraintEqualToAnchor:_progressRowContainer.leadingAnchor],
        [_progressView.trailingAnchor constraintEqualToAnchor:_progressRowContainer.trailingAnchor],
        [_progressView.centerYAnchor constraintEqualToAnchor:_progressRowContainer.centerYAnchor],
        _progressHeightConstraint,
        _progressRowHeightConstraint,
    ]];

    _textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _subtitleLabel, _progressRowContainer]];
    _textStack.axis = UILayoutConstraintAxisVertical;
    _textStack.spacing = 2.0;
    _textStack.alignment = UIStackViewAlignmentFill;
    _textStack.distribution = UIStackViewDistributionFill;
    _textStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_textStack];

    _textCenterYConstraint = [_textStack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor];
    _textTrailingWithButtonConstraint = [_textStack.trailingAnchor constraintEqualToAnchor:_closeButton.leadingAnchor constant:-10.0];
    _textTrailingWithoutButtonConstraint = [_textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-kHorizontalPad];

    [NSLayoutConstraint activateConstraints:@[
        [_textStack.leadingAnchor constraintEqualToAnchor:_iconBadgeView.trailingAnchor constant:10.0],
        _textCenterYConstraint,
        _textTrailingWithButtonConstraint
    ]];

    [_progressView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [_progressView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [_progressRowContainer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];

    self.tone = SCIPillVisualToneInfo;
    [self applyTone:self.tone animated:NO];

    // --- Dynamic style: progress ring on icon badge ---
    _progressRingTrackLayer = [CAShapeLayer layer];
    _progressRingTrackLayer.fillColor   = [UIColor clearColor].CGColor;
    _progressRingTrackLayer.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor;
    _progressRingTrackLayer.lineWidth   = kRingLineWidth;
    _progressRingTrackLayer.hidden = YES;
    [_iconBadgeView.layer addSublayer:_progressRingTrackLayer];

    _progressRingLayer = [CAShapeLayer layer];
    _progressRingLayer.fillColor     = [UIColor clearColor].CGColor;
    _progressRingLayer.strokeColor   = [UIColor whiteColor].CGColor;
    _progressRingLayer.lineWidth     = kRingLineWidth;
    _progressRingLayer.lineCap       = kCALineCapRound;
    _progressRingLayer.strokeStart   = 0.0;
    _progressRingLayer.strokeEnd     = 0.0;
    _progressRingLayer.hidden = YES;
    [_iconBadgeView.layer addSublayer:_progressRingLayer];

    // --- Dynamic style: pan gesture for swipe-to-dismiss ---
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    _panGesture.enabled = NO;
    [self addGestureRecognizer:_panGesture];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.chromeGradientLayer.frame = self.chromeOverlayView.bounds;
    self.iconBadgeGradientLayer.frame = self.iconBadgeView.bounds;
    if (!self.progressView.hidden) {
        CGFloat h = CGRectGetHeight(self.progressView.bounds);
        if (h > 0.5) {
            self.progressView.layer.cornerRadius = h * 0.5;
        }
    }
    // Update ring path when icon badge bounds change
    [self sci_updateRingPath];

    CGFloat effectiveCorner = CGRectGetHeight(self.bounds) / 2.0;
    self.layer.cornerRadius = effectiveCorner;
    self.blurView.layer.cornerRadius = effectiveCorner;
    self.chromeOverlayView.layer.cornerRadius = effectiveCorner;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                      cornerRadius:effectiveCorner].CGPath;
}

- (NSArray<UIColor *> *)chromeColorsForTone:(SCIPillVisualTone)tone {
    (void)tone;
    return @[
        [UIColor colorWithWhite:0.0 alpha:0.0],
        [UIColor colorWithWhite:0.0 alpha:0.0]
    ];
}

- (NSArray<UIColor *> *)badgeColorsForTone:(SCIPillVisualTone)tone {
    switch (tone) {
        case SCIPillVisualToneSuccess:
            return @[
                [UIColor colorWithRed:0.22 green:0.80 blue:0.55 alpha:0.30],
                [UIColor colorWithRed:0.16 green:0.60 blue:0.42 alpha:0.25]
            ];
        case SCIPillVisualToneError:
            return @[
                [UIColor colorWithRed:0.90 green:0.30 blue:0.38 alpha:0.30],
                [UIColor colorWithRed:0.70 green:0.18 blue:0.25 alpha:0.25]
            ];
        case SCIPillVisualToneInfo:
        default:
            return @[
                [UIColor colorWithRed:0.30 green:0.65 blue:0.95 alpha:0.28],
                [UIColor colorWithRed:0.20 green:0.50 blue:0.80 alpha:0.22]
            ];
    }
}

- (NSArray<UIColor *> *)progressColorsForTone:(SCIPillVisualTone)tone {
    switch (tone) {
        case SCIPillVisualToneSuccess:
            return @[
                [UIColor colorWithRed:0.66 green:1.00 blue:0.84 alpha:1.0],
                [UIColor colorWithRed:0.29 green:0.83 blue:0.55 alpha:1.0]
            ];
        case SCIPillVisualToneError:
            return @[
                [UIColor colorWithRed:1.00 green:0.67 blue:0.71 alpha:1.0],
                [UIColor colorWithRed:0.95 green:0.34 blue:0.44 alpha:1.0]
            ];
        case SCIPillVisualToneInfo:
            return @[
                [UIColor colorWithRed:0.50 green:0.90 blue:1.00 alpha:1.0],
                [UIColor colorWithRed:0.15 green:0.70 blue:0.95 alpha:1.0]
            ];
        default:
            return @[
                [UIColor colorWithRed:0.66 green:1.00 blue:0.84 alpha:1.0],
                [UIColor colorWithRed:0.29 green:0.83 blue:0.55 alpha:1.0]
            ];
    }
}

- (UIColor *)titleColorForCurrentStyle {
    return [UIColor colorWithWhite:1.0 alpha:0.98];
}

- (UIColor *)subtitleColorForCurrentStyle {
    return [UIColor colorWithWhite:1.0 alpha:0.82];
}

- (UIColor *)pillBorderColorForCurrentStyle {
    return [UIColor colorWithWhite:1.0 alpha:0.10];
}

- (UIColor *)iconBadgeBorderColorForCurrentStyle {
    return [UIColor colorWithWhite:1.0 alpha:0.12];
}

- (UIColor *)closeButtonBorderColorForCurrentStyle {
    return [UIColor colorWithWhite:1.0 alpha:0.22];
}

- (void)updateProgressViewColorsForTone:(SCIPillVisualTone)tone {
    NSArray<UIColor *> *progressColors = [self progressColorsForTone:tone];
    if (progressColors.count > 0) {
        self.progressView.progressTintColor = progressColors[0];
    }
    self.progressView.trackTintColor = [self progressTrackBackgroundColorForCurrentStyle];
}

- (UIColor *)progressTrackBackgroundColorForCurrentStyle {
    return [[UIColor whiteColor] colorWithAlphaComponent:0.18];
}

- (NSArray *)gradientColorsFrom:(NSArray<UIColor *> *)colors {
    NSMutableArray *cgColors = [NSMutableArray arrayWithCapacity:colors.count];
    for (UIColor *color in colors) {
        [cgColors addObject:(id)color.CGColor];
    }
    return cgColors;
}

- (UIImage *)defaultIconForTone:(SCIPillVisualTone)tone {
    switch (tone) {
        case SCIPillVisualToneSuccess:
            return [SCIAssetUtils instagramIconNamed:@"circle_check_filled"
                                           pointSize:16.0
                                      renderingMode:UIImageRenderingModeAlwaysTemplate];
        case SCIPillVisualToneError:
            return [SCIAssetUtils instagramIconNamed:@"error_filled"
                                           pointSize:16.0
                                      renderingMode:UIImageRenderingModeAlwaysTemplate];
        case SCIPillVisualToneInfo:
        default:
            return [SCIAssetUtils instagramIconNamed:@"info_filled"
                                           pointSize:16.0
                                      renderingMode:UIImageRenderingModeAlwaysTemplate];
    }
}

- (UIColor *)iconTintForTone:(SCIPillVisualTone)tone {
    (void)tone;
    return [UIColor colorWithWhite:1.0 alpha:0.95];
}

- (UIColor *)cancelButtonTintColor {
    return [UIColor colorWithWhite:1.0 alpha:0.83];
}

- (UIColor *)cancelButtonBackgroundColor {
    return [UIColor colorWithWhite:1.0 alpha:0.14];
}

- (UIColor *)retryButtonTintColor {
    return [UIColor colorWithWhite:1.0 alpha:0.95];
}

- (UIColor *)retryButtonBackgroundColor {
    return [UIColor colorWithRed:0.95 green:0.33 blue:0.44 alpha:0.24];
}

- (void)applyCurrentVisualStyleAnimated:(BOOL)animated {
    void (^applyColors)(void) = ^{
        self.layer.borderColor = [self pillBorderColorForCurrentStyle].CGColor;
        self.iconBadgeView.layer.borderColor = [self iconBadgeBorderColorForCurrentStyle].CGColor;
        self.closeButton.layer.borderColor = [self closeButtonBorderColorForCurrentStyle].CGColor;
        self.chromeGradientLayer.colors = [self gradientColorsFrom:[self chromeColorsForTone:self.tone]];
        self.iconBadgeGradientLayer.colors = [self gradientColorsFrom:[self badgeColorsForTone:self.tone]];
        [self updateProgressViewColorsForTone:self.tone];
        self.titleLabel.textColor = [self titleColorForCurrentStyle];
        self.subtitleLabel.textColor = [self subtitleColorForCurrentStyle];

        self.clipsToBounds = NO;

        CGFloat effectiveCorner = CGRectGetHeight(self.bounds) / 2.0;
        if (effectiveCorner < 1.0) effectiveCorner = kPillCorner;
        self.layer.cornerRadius = effectiveCorner;
        self.blurView.layer.cornerRadius = effectiveCorner;
        self.blurView.layer.cornerCurve = kCACornerCurveContinuous;
        self.blurView.clipsToBounds = YES;
        self.chromeOverlayView.layer.cornerRadius = effectiveCorner;
        self.chromeOverlayView.layer.cornerCurve = kCACornerCurveContinuous;
        self.chromeOverlayView.clipsToBounds = YES;

        self.chromeGradientLayer.opacity = 0.0;
        BOOL glowEnabled = [SCIUtils getBoolPref:@"notification_pill_glow_enabled"];
        UIColor *glowColor = [self sci_glowColorForTone:self.tone];
        self.layer.shadowColor = glowColor.CGColor;
        self.layer.shadowOpacity = glowEnabled ? 0.50 : 0.0;
        self.layer.shadowRadius = glowEnabled ? 20.0 : 0.0;
        self.layer.shadowOffset = CGSizeMake(0.0, glowEnabled ? 4.0 : 0.0);
        self.layer.shadowPath = glowEnabled
            ? [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:effectiveCorner].CGPath
            : nil;

        NSArray<UIColor *> *progressColors = [self progressColorsForTone:self.tone];
        self.progressRingLayer.strokeColor = (progressColors.count > 0)
            ? progressColors[0].CGColor
            : [UIColor whiteColor].CGColor;

        self.panGesture.enabled = YES;
    };

    if (!animated) {
        applyColors();
        return;
    }

    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        applyColors();
    } completion:nil];
}

- (void)applyTone:(SCIPillVisualTone)tone animated:(BOOL)animated {
    self.tone = tone;
    [self applyCurrentVisualStyleAnimated:animated];
}

- (CGFloat)sci_subtitleRowLayoutHeight {
    UIFont *font = self.subtitleLabel.font ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    return ceil(font.lineHeight);
}

- (CGFloat)sci_progressBarHeightMatchingSubtitle {
    CGFloat line = [self sci_subtitleRowLayoutHeight];
    CGFloat third = line / 3.0;
    return MAX(2.0, ceil(third));
}

- (void)sci_applyProgressModeInfoIcon {
    self.iconView.image = [SCIAssetUtils instagramIconNamed:@"info_filled"
                                                  pointSize:16.0
                                             renderingMode:UIImageRenderingModeAlwaysTemplate];
    self.iconView.tintColor = [self iconTintForTone:SCIPillVisualToneInfo];
}

- (void)setProgressVisible:(BOOL)visible {
    self.progressRowContainer.hidden = YES;
    self.progressView.hidden = YES;
    self.progressRowHeightConstraint.constant = 0.0;
    self.progressHeightConstraint.constant = 0.0;
    self.progressRingTrackLayer.hidden = !visible;
    self.progressRingLayer.hidden = !visible;
    if (!visible) {
        self.progressRingLayer.strokeEnd = 0.0;
    }
}

- (void)setCloseButtonVisible:(BOOL)visible {
    self.closeButton.hidden = !visible;
    self.textTrailingWithButtonConstraint.active = visible;
    self.textTrailingWithoutButtonConstraint.active = !visible;
}

- (void)animateIconPulse {
    [UIView animateKeyframesWithDuration:0.32 delay:0 options:UIViewKeyframeAnimationOptionCalculationModeCubic animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.55 animations:^{
            self.iconBadgeView.transform = CGAffineTransformMakeScale(1.08, 1.08);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.55 relativeDuration:0.45 animations:^{
            self.iconBadgeView.transform = CGAffineTransformIdentity;
        }];
    } completion:nil];
}

- (void)updateToastWidthForTitle:(NSString *)title subtitle:(NSString *)subtitle {
    if (!self.widthConstraint) {
        return;
    }

    [self sci_updateDynamicWidthForTitle:title subtitle:subtitle hasButton:!self.closeButton.hidden];
}

- (void)configureForProgressMode {
    self.mode = SCINotificationPillModeProgress;
    self.isCompleted = NO;
    self.isErrorState = NO;
    self.tone = SCIPillVisualToneInfo;
    self.currentProgress = 0.0f;
    self.subtitleLabel.text = nil;
    self.subtitleLabel.hidden = YES;
    self.titleLabel.text = @"Downloading...";
    self.progressView.progress = 0.0f;

    self.heightConstraint.constant = kDynamicPillHeight;
    [self sci_updateDynamicWidthForTitle:self.titleLabel.text subtitle:nil hasButton:YES];
    self.progressRingLayer.strokeEnd = 0.0;

    [self setProgressVisible:YES];
    [self setCloseButtonVisible:YES];

    [self sci_applyProgressModeInfoIcon];
    [self applyCancelButtonStyle];
    [self applyTone:SCIPillVisualToneInfo animated:YES];
    [self layoutIfNeeded];
}

- (SCIPillVisualTone)visualToneFromPublicTone:(SCINotificationTone)tone {
    switch (tone) {
        case SCINotificationToneError:
            return SCIPillVisualToneError;
        case SCINotificationToneSuccess:
            return SCIPillVisualToneSuccess;
        case SCINotificationToneInfo:
        default:
            return SCIPillVisualToneInfo;
    }
}

- (void)configureForToastModeWithTitle:(NSString *)title
                              subtitle:(NSString *)subtitle
                                  icon:(UIImage *)icon
                                  tone:(SCINotificationTone)tone {
    self.mode = SCINotificationPillModeToast;
    self.isCompleted = NO;
    self.isErrorState = NO;
    self.onCancel = nil;
    self.onRetry = nil;
    self.onTapWhenCompleted = nil;

    self.titleLabel.text = title.length ? title : @"Done";
    self.subtitleLabel.text = subtitle;
    self.subtitleLabel.hidden = (subtitle.length == 0);
    [self updateToastWidthForTitle:self.titleLabel.text subtitle:subtitle];

    self.heightConstraint.constant = self.subtitleLabel.hidden ? kDynamicPillHeight : kDynamicTallHeight;
    [self setProgressVisible:NO];
    [self setCloseButtonVisible:NO];

    SCIPillVisualTone visualTone = [self visualToneFromPublicTone:tone];
    UIImage *resolvedIcon = (visualTone == SCIPillVisualToneInfo)
        ? (icon ?: [self defaultIconForTone:visualTone])
        : [self defaultIconForTone:visualTone];
    self.iconView.image = resolvedIcon;
    self.iconView.tintColor = [self iconTintForTone:visualTone];
    [self applyTone:visualTone animated:YES];

    [UIView animateWithDuration:0.24 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [self layoutIfNeeded];
    } completion:nil];
    [self animateIconPulse];
}

- (void)applyCancelButtonStyle {
    UIImage *closeImage = [SCIAssetUtils instagramIconNamed:@"xmark"
                                                  pointSize:12.0
                                             renderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.closeButton setImage:closeImage forState:UIControlStateNormal];
    self.closeButton.tintColor = [self cancelButtonTintColor];
    self.closeButton.backgroundColor = [self cancelButtonBackgroundColor];
}

- (void)applyErrorDismissButtonStyle {
    [self applyCancelButtonStyle];
    self.closeButton.backgroundColor = [self retryButtonBackgroundColor];
    self.closeButton.tintColor = [self retryButtonTintColor];
}

#pragma mark - Public

- (float)sanitizedProgressValue:(float)progress {
    if (!isfinite(progress)) {
        return self.currentProgress;
    }

    return fminf(1.0f, fmaxf(0.0f, progress));
}

- (void)setProgress:(float)progress animated:(BOOL)animated {
    if (self.mode != SCINotificationPillModeProgress) {
        [self configureForProgressMode];
    }

    _currentProgress = [self sanitizedProgressValue:progress];

    if (self.isErrorState || self.isCompleted) {
        self.isErrorState = NO;
        self.isCompleted = NO;
        self.titleLabel.text = @"Downloading...";
        self.subtitleLabel.text = nil;
        self.subtitleLabel.hidden = YES;
        self.heightConstraint.constant = kDynamicPillHeight;
        [self setCloseButtonVisible:YES];
        [self setProgressVisible:YES];

        [self sci_applyProgressModeInfoIcon];
        [self applyTone:SCIPillVisualToneInfo animated:YES];
        [self applyCancelButtonStyle];
    }

    if (!self.isCompleted) {
        [self setProgressVisible:YES];
        [self sci_applyProgressModeInfoIcon];
    }

    if (animated) {
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.3];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
        self.progressRingLayer.strokeEnd = (CGFloat)self.currentProgress;
        [CATransaction commit];
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.progressRingLayer.strokeEnd = (CGFloat)self.currentProgress;
        [CATransaction commit];
    }
}

- (void)updateProgressTitle:(NSString *)title subtitle:(NSString *)subtitle {
    if (self.mode != SCINotificationPillModeProgress) {
        [self configureForProgressMode];
    }

    self.isCompleted = NO;
    self.isErrorState = NO;
    self.titleLabel.text = title.length > 0 ? title : @"Downloading...";
    self.subtitleLabel.text = subtitle;
    self.subtitleLabel.hidden = (subtitle.length == 0);

    self.heightConstraint.constant = self.subtitleLabel.hidden ? kDynamicPillHeight : kDynamicTallHeight;
    [self sci_updateDynamicWidthForTitle:self.titleLabel.text subtitle:subtitle hasButton:YES];

    [self setProgressVisible:YES];
    [self setCloseButtonVisible:YES];
    [self sci_applyProgressModeInfoIcon];
    [self applyTone:SCIPillVisualToneInfo animated:YES];
    [self applyCancelButtonStyle];

    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [self layoutIfNeeded];
    } completion:nil];
}

- (void)showSuccess {
    [self showSuccessWithTitle:@"Download complete" subtitle:nil icon:nil];
}

- (void)showSuccessWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon {
    if (self.mode != SCINotificationPillModeProgress) {
        [self configureForProgressMode];
    }

    self.isCompleted = YES;
    self.isErrorState = NO;
    self.onCancel = nil;
    self.onRetry = nil;
    [self applyCancelButtonStyle];

    if (self.onTonePresented) {
        self.onTonePresented(SCINotificationToneSuccess);
    }

    UIImage *checkImage = [self defaultIconForTone:SCIPillVisualToneSuccess];
    [self applyTone:SCIPillVisualToneSuccess animated:YES];
    [UIView transitionWithView:self duration:0.32 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent animations:^{
        self.iconView.image = checkImage;
        self.iconView.tintColor = [self iconTintForTone:SCIPillVisualToneSuccess];
        self.titleLabel.text = title.length ? title : @"Download complete";
        self.subtitleLabel.text = subtitle;
        self.subtitleLabel.hidden = (subtitle.length == 0);
        [self updateToastWidthForTitle:self.titleLabel.text subtitle:subtitle];
        [self setCloseButtonVisible:NO];
        [self setProgressVisible:NO];
        self.heightConstraint.constant = self.subtitleLabel.hidden
            ? kDynamicPillHeight
            : kDynamicTallHeight;
        [self layoutIfNeeded];
    } completion:nil];
    [self animateIconPulse];
}

- (void)showError:(NSString *)message {
    [self showErrorWithTitle:message subtitle:nil icon:nil];
}

- (void)showErrorWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon {
    if (self.mode != SCINotificationPillModeProgress) {
        [self configureForProgressMode];
    }

    self.isCompleted = NO;
    self.isErrorState = YES;
    self.onTapWhenCompleted = nil;
    self.onCancel = nil;
    [self applyErrorDismissButtonStyle];

    NSString *resolvedSubtitle = subtitle;
    if (self.onRetry && resolvedSubtitle.length == 0) {
        resolvedSubtitle = @"Tap to retry";
    }

    if (self.onTonePresented) {
        self.onTonePresented(SCINotificationToneError);
    }

    UIImage *errorImage = [self defaultIconForTone:SCIPillVisualToneError];
    [self applyTone:SCIPillVisualToneError animated:YES];
    [UIView transitionWithView:self duration:0.32 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent animations:^{
        self.iconView.image = errorImage;
        self.iconView.tintColor = [self iconTintForTone:SCIPillVisualToneError];
        self.titleLabel.text = title.length ? title : @"Download failed";
        self.subtitleLabel.text = resolvedSubtitle;
        self.subtitleLabel.hidden = (resolvedSubtitle.length == 0);
        [self updateToastWidthForTitle:self.titleLabel.text subtitle:resolvedSubtitle];
        [self setCloseButtonVisible:YES];
        [self setProgressVisible:NO];
        self.heightConstraint.constant = self.subtitleLabel.hidden
            ? kDynamicPillHeight
            : kDynamicTallHeight;
        [self layoutIfNeeded];
    } completion:nil];
    [self animateIconPulse];
}

- (void)showInfoWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon {
    if (self.mode != SCINotificationPillModeProgress) {
        [self configureForProgressMode];
    }

    self.isCompleted = YES;
    self.isErrorState = NO;
    self.onCancel = nil;
    self.onRetry = nil;
    [self applyCancelButtonStyle];

    if (self.onTonePresented) {
        self.onTonePresented(SCINotificationToneInfo);
    }

    UIImage *infoImage = icon ?: [self defaultIconForTone:SCIPillVisualToneInfo];
    [self applyTone:SCIPillVisualToneInfo animated:YES];
    [UIView transitionWithView:self duration:0.32 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent animations:^{
        self.iconView.image = infoImage;
        self.iconView.tintColor = [self iconTintForTone:SCIPillVisualToneInfo];
        self.titleLabel.text = title.length ? title : @"Info";
        self.subtitleLabel.text = subtitle;
        self.subtitleLabel.hidden = (subtitle.length == 0);
        [self updateToastWidthForTitle:self.titleLabel.text subtitle:subtitle];
        [self setCloseButtonVisible:NO];
        [self setProgressVisible:NO];
        self.heightConstraint.constant = self.subtitleLabel.hidden
            ? kDynamicPillHeight
            : kDynamicTallHeight;
        [self layoutIfNeeded];
    } completion:nil];
    [self animateIconPulse];
}

- (void)dismiss {
    [self dismissWithCompletion:nil];
}

- (void)dismissWithCompletion:(void(^)(void))completion {
    if (!self.superview) {
        if (completion) completion();
        return;
    }

    self.isCompleted = NO;
    self.isErrorState = NO;
    self.onTapWhenCompleted = nil;
    self.onCancel = nil;
    self.onRetry = nil;

    self.iconBadgeView.transform = CGAffineTransformIdentity;
    self.closeButton.transform = CGAffineTransformIdentity;
    self.topConstraint.constant = -(self.heightConstraint.constant + 10.0);
    [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        [self.superview layoutIfNeeded];
        self.alpha = 0;
        self.transform = SCIPillEntranceTransform();
        self.iconBadgeView.transform = CGAffineTransformMakeScale(0.78, 0.78);
        self.closeButton.transform = CGAffineTransformMakeScale(0.84, 0.84);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (self.onDidDismiss) {
            self.onDidDismiss();
        }
        if (completion) completion();
    }];
}

#pragma mark - Private

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *touchedView = touch.view;
    if ([touchedView isDescendantOfView:self.closeButton]) {
        return NO;
    }

    return YES;
}

- (void)handleTap {
    if (self.mode == SCINotificationPillModeToast) {
        [self dismissWithCompletion:nil];
        return;
    }

    if (self.isErrorState && self.onRetry) {
        self.onRetry();
        return;
    }

    if (self.isCompleted) {
        void (^onCompletedTap)(void) = [self.onTapWhenCompleted copy];
        [self dismissWithCompletion:^{
            if (onCompletedTap) {
                onCompletedTap();
            }
        }];
    }

}

- (void)closeTapped {
    if (self.mode == SCINotificationPillModeToast) {
        [self dismissWithCompletion:nil];
        return;
    }

    if (self.isErrorState) {
        [self dismissWithCompletion:nil];
        return;
    }

    if (!self.isCompleted && self.onCancel) {
        self.onCancel();
    }

    [self dismissWithCompletion:nil];
}

#pragma mark - Dynamic Style Helpers

- (void)sci_updateRingPath {
    CGRect bounds = self.iconBadgeView.bounds;
    if (CGRectIsEmpty(bounds)) return;

    CGFloat inset = kRingLineWidth / 2.0 + 0.5;
    CGRect ringRect = CGRectInset(bounds, inset, inset);
    CGPoint center = CGPointMake(CGRectGetMidX(ringRect), CGRectGetMidY(ringRect));
    CGFloat radius = MIN(CGRectGetWidth(ringRect), CGRectGetHeight(ringRect)) / 2.0;

    // Start at 12 o'clock (-π/2), draw clockwise
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center
                                                        radius:radius
                                                    startAngle:-M_PI_2
                                                      endAngle:(-M_PI_2 + 2.0 * M_PI)
                                                     clockwise:YES];
    self.progressRingTrackLayer.path = path.CGPath;
    self.progressRingLayer.path = path.CGPath;
    self.progressRingTrackLayer.frame = bounds;
    self.progressRingLayer.frame = bounds;
}

- (UIColor *)sci_glowColorForTone:(SCIPillVisualTone)tone {
    switch (tone) {
        case SCIPillVisualToneSuccess:
            return [UIColor colorWithRed:0.20 green:0.85 blue:0.55 alpha:1.0];
        case SCIPillVisualToneError:
            return [UIColor colorWithRed:0.95 green:0.30 blue:0.40 alpha:1.0];
        case SCIPillVisualToneInfo:
        default:
            return [UIColor colorWithRed:0.30 green:0.65 blue:0.98 alpha:1.0];
    }
}

- (void)sci_updateDynamicWidthForTitle:(NSString *)title subtitle:(NSString *)subtitle hasButton:(BOOL)hasButton {
    if (!self.widthConstraint) return;

    UIFont *titleFont = self.titleLabel.font ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    UIFont *subtitleFont = self.subtitleLabel.font ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];

    CGFloat titleWidth = 0.0;
    if (title.length > 0) {
        titleWidth = ceil([title boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, titleFont.lineHeight)
                                             options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                          attributes:@{NSFontAttributeName: titleFont}
                                             context:nil].size.width);
    }

    CGFloat subtitleWidth = 0.0;
    if (subtitle.length > 0) {
        subtitleWidth = ceil([subtitle boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, subtitleFont.lineHeight)
                                                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                attributes:@{NSFontAttributeName: subtitleFont}
                                                   context:nil].size.width);
    }

    CGFloat textWidth = MAX(titleWidth, subtitleWidth);

    // icon padding + icon + gap + text + trailing padding
    CGFloat fixedWidth = kHorizontalPad + kIconBadgeSize + 10.0 + kHorizontalPad;
    if (hasButton) {
        fixedWidth += 24.0 + 13.0 + 10.0; // button width + trailing + gap
    }

    CGFloat targetWidth = ceil(textWidth) + fixedWidth;
    targetWidth = MIN(kDynamicMaxWidth, MAX(kDynamicMinWidth, targetWidth));

    CGFloat newWidth = targetWidth;
    CGFloat currentWidth = self.widthConstraint.constant;

    if (fabs(newWidth - currentWidth) < 1.0) return;

    self.widthConstraint.constant = newWidth;

    // Spring-animate the bounds change
    [UIView animateWithDuration:0.4
                          delay:0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        [self.superview layoutIfNeeded];
    } completion:nil];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];

    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            self.panOriginCenter = self.center;
            break;

        case UIGestureRecognizerStateChanged: {
            // Only allow upward movement, rubberband downward
            CGFloat yDelta = translation.y;
            if (yDelta > 0) {
                yDelta = yDelta * 0.25; // rubberband down
            }
            self.center = CGPointMake(self.panOriginCenter.x, self.panOriginCenter.y + yDelta);

            // Fade out as it moves up
            CGFloat progress = MIN(1.0, MAX(0.0, -yDelta / 60.0));
            self.alpha = 1.0 - (progress * 0.5);
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat velocity = [pan velocityInView:self.superview].y;
            CGFloat yOffset = self.center.y - self.panOriginCenter.y;

            if (yOffset < -20.0 || velocity < -300.0) {
                // Dismiss
                [self dismiss];
            } else {
                // Snap back with spring
                [UIView animateWithDuration:0.4
                                      delay:0
                     usingSpringWithDamping:0.7
                      initialSpringVelocity:0.5
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                    self.center = self.panOriginCenter;
                    self.alpha = 1.0;
                } completion:nil];
            }
            break;
        }

        default:
            break;
    }
}

#pragma mark - Dynamic Touch Feedback

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];

    [UIView animateWithDuration:0.15
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:nil];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.6
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];

    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.6
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
