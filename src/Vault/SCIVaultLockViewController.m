#import "SCIVaultLockViewController.h"
#import "SCIVaultManager.h"

static NSInteger const kPasscodeLength = 4;

@interface SCIVaultLockViewController ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *dotsStackView;
@property (nonatomic, strong) NSMutableArray<UIView *> *dotViews;
@property (nonatomic, strong) UIStackView *keypadStackView;
@property (nonatomic, strong) UIButton *biometricButton;
@property (nonatomic, strong) UIButton *cancelButton;

@property (nonatomic, strong) NSMutableString *enteredPasscode;
@property (nonatomic, copy, nullable) NSString *firstPasscode; // for set/change confirm

/// For change mode: once we've verified the old passcode, we switch to "set new" sub-state.
@property (nonatomic, assign) BOOL hasVerifiedOldPasscode;

@end

@implementation SCIVaultLockViewController

#pragma mark - Presentation

+ (void)presentUnlockFromViewController:(UIViewController *)presenter
                             completion:(void (^)(BOOL))completion {
    SCIVaultManager *mgr = [SCIVaultManager sharedManager];
    if ([mgr isBiometricsAvailable]) {
        [mgr authenticateWithBiometricsWithCompletion:^(BOOL success, NSError *err) {
            if (success) {
                if (completion) completion(YES);
            } else {
                [self presentMode:SCIVaultLockModeUnlock fromViewController:presenter completion:completion];
            }
        }];
    } else {
        [self presentMode:SCIVaultLockModeUnlock fromViewController:presenter completion:completion];
    }
}

+ (void)presentMode:(SCIVaultLockMode)mode
   fromViewController:(UIViewController *)presenter
           completion:(void (^)(BOOL))completion {
    SCIVaultLockViewController *vc = [[SCIVaultLockViewController alloc] init];
    vc.mode = mode;
    vc.completion = completion;
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:vc animated:YES completion:nil];
}

#pragma mark - Lifecycle

- (instancetype)init {
    if ((self = [super init])) {
        _enteredPasscode = [NSMutableString new];
        _dotViews = [NSMutableArray new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupUI];
    [self updateUIForMode];

    if (self.mode == SCIVaultLockModeUnlock) {
        [self triggerBiometricsIfAvailable];
    }
}

#pragma mark - Setup

- (void)setupUI {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.font = [UIFont systemFontOfSize:14];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.subtitleLabel];

    self.dotsStackView = [[UIStackView alloc] init];
    self.dotsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.dotsStackView.spacing = 16;
    self.dotsStackView.alignment = UIStackViewAlignmentCenter;
    self.dotsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.dotsStackView];

    for (NSInteger i = 0; i < kPasscodeLength; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.layer.cornerRadius = 6;
        dot.layer.borderWidth = 1.5;
        dot.layer.borderColor = [UIColor labelColor].CGColor;
        dot.backgroundColor = [UIColor clearColor];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [dot.widthAnchor constraintEqualToConstant:12],
            [dot.heightAnchor constraintEqualToConstant:12],
        ]];
        [self.dotsStackView addArrangedSubview:dot];
        [self.dotViews addObject:dot];
    }

    [self setupKeypad];

    self.biometricButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.biometricButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.biometricButton addTarget:self
                             action:@selector(triggerBiometrics)
                   forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.biometricButton];

    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [self.cancelButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.cancelButton.titleLabel.font = [UIFont systemFontOfSize:17];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cancelButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.titleLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:50],

        [self.subtitleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],

        [self.dotsStackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dotsStackView.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:32],

        [self.keypadStackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.keypadStackView.topAnchor constraintEqualToAnchor:self.dotsStackView.bottomAnchor constant:48],

        [self.biometricButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.biometricButton.topAnchor constraintEqualToAnchor:self.keypadStackView.bottomAnchor constant:24],

        [self.cancelButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-20],
    ]];
}

- (void)setupKeypad {
    self.keypadStackView = [[UIStackView alloc] init];
    self.keypadStackView.axis = UILayoutConstraintAxisVertical;
    self.keypadStackView.spacing = 16;
    self.keypadStackView.alignment = UIStackViewAlignmentCenter;
    self.keypadStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.keypadStackView];

    NSArray<NSArray<NSNumber *> *> *layout = @[
        @[@1, @2, @3],
        @[@4, @5, @6],
        @[@7, @8, @9],
        @[@(-1), @0, @(-2)], // -1 = empty, -2 = delete
    ];

    for (NSArray<NSNumber *> *row in layout) {
        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.spacing = 20;
        rowStack.alignment = UIStackViewAlignmentCenter;
        rowStack.distribution = UIStackViewDistributionFillEqually;

        for (NSNumber *num in row) {
            NSInteger n = num.integerValue;
            if (n == -1) {
                UIView *spacer = [[UIView alloc] init];
                [NSLayoutConstraint activateConstraints:@[
                    [spacer.widthAnchor constraintEqualToConstant:75],
                    [spacer.heightAnchor constraintEqualToConstant:75],
                ]];
                [rowStack addArrangedSubview:spacer];
            } else if (n == -2) {
                UIButton *del = [self createKeypadButton:nil subtitle:nil tag:-2];
                UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
                [del setImage:[UIImage systemImageNamed:@"delete.left" withConfiguration:cfg] forState:UIControlStateNormal];
                [del setTitle:@"" forState:UIControlStateNormal];
                del.tintColor = [UIColor labelColor];
                [del addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
                [rowStack addArrangedSubview:del];
            } else {
                NSString *letters = [self lettersForDigit:n];
                UIButton *btn = [self createKeypadButton:[NSString stringWithFormat:@"%ld", (long)n] subtitle:letters tag:n];
                [btn addTarget:self action:@selector(numberTapped:) forControlEvents:UIControlEventTouchUpInside];
                [rowStack addArrangedSubview:btn];
            }
        }

        [self.keypadStackView addArrangedSubview:rowStack];
    }
}

- (NSString *)lettersForDigit:(NSInteger)digit {
    switch (digit) {
        case 2: return @"ABC";
        case 3: return @"DEF";
        case 4: return @"GHI";
        case 5: return @"JKL";
        case 6: return @"MNO";
        case 7: return @"PQRS";
        case 8: return @"TUV";
        case 9: return @"WXYZ";
        default: return @"";
    }
}

- (UIButton *)createKeypadButton:(NSString *)title subtitle:(NSString *)subtitle tag:(NSInteger)tag {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = tag;
    btn.layer.cornerRadius = 37.5;
    btn.backgroundColor = [UIColor secondarySystemBackgroundColor];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:75],
        [btn.heightAnchor constraintEqualToConstant:75],
    ]];

    if (title) {
        UILabel *digitLabel = [[UILabel alloc] init];
        digitLabel.text = title;
        digitLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightLight];
        digitLabel.textColor = [UIColor labelColor];
        digitLabel.textAlignment = NSTextAlignmentCenter;
        digitLabel.translatesAutoresizingMaskIntoConstraints = NO;
        digitLabel.userInteractionEnabled = NO;
        [btn addSubview:digitLabel];

        UILabel *lettersLabel = [[UILabel alloc] init];
        lettersLabel.text = subtitle ?: @"";
        lettersLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        lettersLabel.textColor = [UIColor secondaryLabelColor];
        lettersLabel.textAlignment = NSTextAlignmentCenter;
        lettersLabel.translatesAutoresizingMaskIntoConstraints = NO;
        lettersLabel.userInteractionEnabled = NO;
        [btn addSubview:lettersLabel];

        [NSLayoutConstraint activateConstraints:@[
            [digitLabel.centerXAnchor constraintEqualToAnchor:btn.centerXAnchor],
            [digitLabel.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor constant:-6],
            [lettersLabel.centerXAnchor constraintEqualToAnchor:btn.centerXAnchor],
            [lettersLabel.topAnchor constraintEqualToAnchor:digitLabel.bottomAnchor constant:-2],
        ]];
    }

    return btn;
}

#pragma mark - Mode / UI updates

- (void)updateUIForMode {
    switch (self.mode) {
        case SCIVaultLockModeUnlock:
            self.titleLabel.text = @"Enter Passcode";
            self.subtitleLabel.text = @"Enter your passcode to unlock the vault";
            break;

        case SCIVaultLockModeSetPasscode:
            self.titleLabel.text = self.firstPasscode ? @"Confirm Passcode" : @"New Passcode";
            self.subtitleLabel.text = self.firstPasscode
                ? @"Re-enter your new passcode"
                : @"Create a passcode to protect your vault";
            break;

        case SCIVaultLockModeChangePasscode:
            if (!self.hasVerifiedOldPasscode) {
                self.titleLabel.text = @"Enter Current Passcode";
                self.subtitleLabel.text = @"Enter your current vault passcode";
            } else {
                self.titleLabel.text = self.firstPasscode ? @"Confirm Passcode" : @"New Passcode";
                self.subtitleLabel.text = self.firstPasscode
                    ? @"Re-enter your new passcode"
                    : @"Create a new passcode";
            }
            break;
    }

    // Biometrics button only shown during unlock, when available.
    SCIVaultManager *mgr = [SCIVaultManager sharedManager];
    BOOL showBiometrics = (self.mode == SCIVaultLockModeUnlock) && [mgr isBiometricsAvailable];
    self.biometricButton.hidden = !showBiometrics;
    if (showBiometrics) {
        NSString *icon = [mgr biometryType] == SCIVaultBiometryTypeFaceID ? @"faceid" : @"touchid";
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightRegular];
        [self.biometricButton setImage:[UIImage systemImageNamed:icon withConfiguration:cfg] forState:UIControlStateNormal];
        self.biometricButton.tintColor = [UIColor labelColor];
    }

    [self updateDots];
}

- (void)updateDots {
    for (NSInteger i = 0; i < self.dotViews.count; i++) {
        UIView *dot = self.dotViews[i];
        BOOL filled = i < (NSInteger)self.enteredPasscode.length;
        dot.backgroundColor = filled ? [UIColor labelColor] : [UIColor clearColor];
    }
}

- (void)shakeDots {
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.duration = 0.4;
    shake.values = @[@(-12), @(12), @(-10), @(10), @(-6), @(6), @(-2), @(2), @(0)];
    [self.dotsStackView.layer addAnimation:shake forKey:@"shake"];

    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [gen impactOccurred];
}

#pragma mark - Keypad actions

- (void)numberTapped:(UIButton *)sender {
    if (self.enteredPasscode.length >= kPasscodeLength) return;
    [self.enteredPasscode appendFormat:@"%ld", (long)sender.tag];
    [self updateDots];

    if (self.enteredPasscode.length == kPasscodeLength) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self handlePasscodeComplete];
        });
    }
}

- (void)deleteTapped {
    if (self.enteredPasscode.length == 0) return;
    [self.enteredPasscode deleteCharactersInRange:NSMakeRange(self.enteredPasscode.length - 1, 1)];
    [self updateDots];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.completion) self.completion(NO);
    }];
}

- (void)triggerBiometricsIfAvailable {
    if (self.mode != SCIVaultLockModeUnlock) return;
    if (![[SCIVaultManager sharedManager] isBiometricsAvailable]) return;
    [self triggerBiometrics];
}

- (void)triggerBiometrics {
    __weak typeof(self) weakSelf = self;
    [[SCIVaultManager sharedManager] authenticateWithBiometricsWithCompletion:^(BOOL success, NSError *err) {
        if (!success) return;
        [weakSelf.presentingViewController dismissViewControllerAnimated:YES completion:^{
            if (weakSelf.completion) weakSelf.completion(YES);
        }];
    }];
}

#pragma mark - Passcode handling

- (void)handlePasscodeComplete {
    SCIVaultManager *mgr = [SCIVaultManager sharedManager];
    NSString *entered = [self.enteredPasscode copy];

    switch (self.mode) {
        case SCIVaultLockModeUnlock: {
            if ([mgr verifyPasscode:entered]) {
                [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
                    if (self.completion) self.completion(YES);
                }];
            } else {
                [self shakeDots];
                [self.enteredPasscode setString:@""];
                [self updateDots];
            }
            break;
        }

        case SCIVaultLockModeSetPasscode: {
            if (!self.firstPasscode) {
                self.firstPasscode = entered;
                [self.enteredPasscode setString:@""];
                [self updateUIForMode];
            } else if ([self.firstPasscode isEqualToString:entered]) {
                if ([mgr setPasscode:entered]) {
                    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
                        if (self.completion) self.completion(YES);
                    }];
                } else {
                    [self shakeDots];
                    [self resetSetFlow];
                }
            } else {
                [self shakeDots];
                [self resetSetFlow];
            }
            break;
        }

        case SCIVaultLockModeChangePasscode: {
            if (!self.hasVerifiedOldPasscode) {
                if ([mgr verifyPasscode:entered]) {
                    self.hasVerifiedOldPasscode = YES;
                    [self.enteredPasscode setString:@""];
                    [self updateUIForMode];
                } else {
                    [self shakeDots];
                    [self.enteredPasscode setString:@""];
                    [self updateDots];
                }
            } else if (!self.firstPasscode) {
                self.firstPasscode = entered;
                [self.enteredPasscode setString:@""];
                [self updateUIForMode];
            } else if ([self.firstPasscode isEqualToString:entered]) {
                if ([mgr setPasscode:entered]) {
                    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
                        if (self.completion) self.completion(YES);
                    }];
                } else {
                    [self shakeDots];
                    [self resetSetFlow];
                }
            } else {
                [self shakeDots];
                [self resetSetFlow];
            }
            break;
        }
    }
}

- (void)resetSetFlow {
    self.firstPasscode = nil;
    [self.enteredPasscode setString:@""];
    [self updateUIForMode];
}

@end
