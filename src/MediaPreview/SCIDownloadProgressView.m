#import "SCIDownloadProgressView.h"

static CGFloat const kPillHeight     = 50.0;
static CGFloat const kPillMarginTop  = 8.0;
static CGFloat const kPillCorner     = 25.0;
static CGFloat const kProgressHeight = 3.0;
static CGFloat const kHorizontalPad  = 16.0;
static CGFloat const kPillWidth      = 230.0;

@interface SCIDownloadProgressView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UILabel            *titleLabel;
@property (nonatomic, strong) UIView             *progressTrack;
@property (nonatomic, strong) UIView             *progressFill;
@property (nonatomic, strong) UIImageView        *iconView;
@property (nonatomic, strong) UIButton           *closeButton;
@property (nonatomic, assign) float              currentProgress;
@property (nonatomic, assign) BOOL               isCompleted;
@property (nonatomic, strong) NSLayoutConstraint *titleCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *progressWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *progressHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, assign) BOOL isErrorState;
@end

@implementation SCIDownloadProgressView

#pragma mark - Factory

+ (instancetype)showInView:(UIView *)view {
    // Dismiss any existing pill
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[SCIDownloadProgressView class]]) {
            [(SCIDownloadProgressView *)sub dismiss];
        }
    }

    SCIDownloadProgressView *pill = [[SCIDownloadProgressView alloc] init];
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:pill];

    // Layout: centered horizontally, near top
    pill.topConstraint = [pill.topAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.topAnchor constant:-kPillHeight];
    [NSLayoutConstraint activateConstraints:@[
        pill.topConstraint,
        [pill.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [pill.widthAnchor constraintEqualToConstant:kPillWidth],
        [pill.heightAnchor constraintEqualToConstant:kPillHeight]
    ]];

    [view layoutIfNeeded];

    // Animate in
    pill.topConstraint.constant = kPillMarginTop;
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [view layoutIfNeeded];
    } completion:nil];

    return pill;
}

#pragma mark - Init

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.layer.cornerRadius = kPillCorner;
    self.clipsToBounds = YES;
    self.layer.cornerCurve = kCACornerCurveContinuous;

    // Blur background
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

    // Icon (download arrow)
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImage *arrowImage = [UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:config];
    _iconView = [[UIImageView alloc] initWithImage:arrowImage];
    _iconView.tintColor = [UIColor whiteColor];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_iconView];

    [NSLayoutConstraint activateConstraints:@[
        [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kHorizontalPad],
        [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:20],
        [_iconView.heightAnchor constraintEqualToConstant:20],
    ]];

    // Close / cancel button
    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self applyCancelButtonStyle];
    _closeButton.layer.cornerRadius = 11.0;
    _closeButton.layer.cornerCurve = kCACornerCurveContinuous;
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [_closeButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12.0],
        [_closeButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_closeButton.widthAnchor constraintEqualToConstant:22.0],
        [_closeButton.heightAnchor constraintEqualToConstant:22.0],
    ]];

    // Title label
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = @"Downloading...";
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    _titleLabel.numberOfLines = 1;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_titleLabel];

    _titleCenterYConstraint = [_titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-kProgressHeight];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:8],
        _titleCenterYConstraint,
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_closeButton.leadingAnchor constant:-8.0],
    ]];

    // Progress track (dark background bar at bottom of pill)
    _progressTrack = [[UIView alloc] init];
    _progressTrack.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    _progressTrack.translatesAutoresizingMaskIntoConstraints = NO;
    _progressTrack.layer.cornerRadius = kProgressHeight / 2.0;
    [self addSubview:_progressTrack];

    _progressHeightConstraint = [_progressTrack.heightAnchor constraintEqualToConstant:kProgressHeight];

    CGFloat trackInset = 8.0;
    [NSLayoutConstraint activateConstraints:@[
        [_progressTrack.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:8],
        [_progressTrack.trailingAnchor constraintEqualToAnchor:_closeButton.leadingAnchor constant:-trackInset],
        [_progressTrack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-9],
        _progressHeightConstraint,
    ]];

    // Progress fill
    _progressFill = [[UIView alloc] init];
    _progressFill.backgroundColor = [UIColor whiteColor];
    _progressFill.translatesAutoresizingMaskIntoConstraints = NO;
    _progressFill.layer.cornerRadius = kProgressHeight / 2.0;
    [_progressTrack addSubview:_progressFill];

    _progressWidthConstraint = [_progressFill.widthAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [_progressFill.leadingAnchor constraintEqualToAnchor:_progressTrack.leadingAnchor],
        [_progressFill.topAnchor constraintEqualToAnchor:_progressTrack.topAnchor],
        [_progressFill.bottomAnchor constraintEqualToAnchor:_progressTrack.bottomAnchor],
        _progressWidthConstraint,
    ]];

    // Tap pill to open after completion
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];

    return self;
}

- (void)applyCancelButtonStyle {
    UIImageSymbolConfiguration *closeConfig = [UIImageSymbolConfiguration configurationWithPointSize:9 weight:UIImageSymbolWeightSemibold];
    UIImage *closeImage = [UIImage systemImageNamed:@"xmark" withConfiguration:closeConfig];
    [self.closeButton setImage:closeImage forState:UIControlStateNormal];
    self.closeButton.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.78];
    self.closeButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12];
}

- (void)applyRetryButtonStyle {
    [self applyCancelButtonStyle];

    UIImageSymbolConfiguration *retryConfig = [UIImageSymbolConfiguration configurationWithPointSize:9 weight:UIImageSymbolWeightSemibold];
    UIImage *retryImage = [UIImage systemImageNamed:@"arrow.trianglehead.counterclockwise" withConfiguration:retryConfig];
    if (!retryImage) {
        retryImage = [UIImage systemImageNamed:@"arrow.clockwise" withConfiguration:retryConfig];
    }

    [self.closeButton setImage:retryImage forState:UIControlStateNormal];
}

#pragma mark - Public

- (void)setProgress:(float)progress animated:(BOOL)animated {
    _currentProgress = MIN(MAX(progress, 0.0), 1.0);

    if (self.isErrorState) {
        self.isErrorState = NO;
        [self applyCancelButtonStyle];
    }

    if (!self.isCompleted) {
        self.titleCenterYConstraint.constant = -kProgressHeight;
        self.progressHeightConstraint.constant = kProgressHeight;
        self.progressTrack.alpha = 1.0;
    }

    [self layoutIfNeeded];
    CGFloat trackWidth = CGRectGetWidth(_progressTrack.bounds);
    CGFloat fillWidth = trackWidth * _currentProgress;

    _progressWidthConstraint.constant = fillWidth;

    if (animated) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self layoutIfNeeded];
        } completion:nil];
    } else {
        [self layoutIfNeeded];
    }
}

- (void)showSuccess {
    self.isCompleted = YES;
    self.isErrorState = NO;
    self.onCancel = nil;
    self.onRetry = nil;
    [self applyCancelButtonStyle];

    // Success haptic
    UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
    [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];

    // Animate to success state
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImage *checkImage = [UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:config];

    [UIView transitionWithView:self duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.iconView.image = checkImage;
        self.iconView.tintColor = [UIColor systemGreenColor];
        self.titleLabel.text = @"Download complete";

        self.titleCenterYConstraint.constant = 0.0;
        self.progressHeightConstraint.constant = 0.0;
        self.progressTrack.alpha = 0;
        [self layoutIfNeeded];
    } completion:nil];
}

- (void)showError:(NSString *)message {
    self.isCompleted = NO;
    self.isErrorState = YES;
    self.onTapWhenCompleted = nil;
    self.onCancel = nil;
    [self applyRetryButtonStyle];

    // Error haptic
    UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
    [haptic notificationOccurred:UINotificationFeedbackTypeError];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImage *errorImage = [UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:config];

    [UIView transitionWithView:self duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.iconView.image = errorImage;
        self.iconView.tintColor = [UIColor systemRedColor];
        self.titleLabel.text = message ?: @"Download failed";
        self.titleCenterYConstraint.constant = 0.0;
        self.progressHeightConstraint.constant = 0.0;
        self.progressTrack.alpha = 0;
        [self layoutIfNeeded];
    } completion:nil];
}

- (void)dismiss {
    [self dismissWithCompletion:nil];
}

- (void)dismissWithCompletion:(void(^)(void))completion {
    self.isCompleted = NO;
    self.isErrorState = NO;
    self.onTapWhenCompleted = nil;
    self.onCancel = nil;
    self.onRetry = nil;

    self.topConstraint.constant = -kPillHeight - 10;
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:0 animations:^{
        [self.superview layoutIfNeeded];
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
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
    if (self.isCompleted) {
        if (self.onTapWhenCompleted) {
            self.onTapWhenCompleted();
        }

        [self dismissWithCompletion:nil];
    }

}

- (void)closeTapped {
    if (self.isErrorState) {
        if (self.onRetry) {
            self.onRetry();
            return;
        }

        [self dismissWithCompletion:nil];
        return;
    }

    if (!self.isCompleted && self.onCancel) {
        self.onCancel();
    }

    [self dismissWithCompletion:nil];
}

@end
