#import "SCISwitch.h"

#import "../../Utils.h"

@implementation SCISwitch

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self sci_commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self sci_commonInit];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self sci_applyColors];
    [self sci_scheduleColorRefresh];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self sci_applyColors];
    [self sci_scheduleColorRefresh];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self sci_applyColors];
}

- (void)setOn:(BOOL)on {
    [super setOn:on];
    [self sci_applyColors];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    [super setOn:on animated:animated];
    [self sci_applyColors];
    [self sci_scheduleColorRefresh];
}

- (void)sci_commonInit {
    [self sci_applyColors];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sci_applyColors)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (UITraitCollection *)sci_effectiveTraitCollection {
    UITraitCollection *windowTraits = self.window.traitCollection;
    if (windowTraits.userInterfaceStyle != UIUserInterfaceStyleUnspecified) {
        return windowTraits;
    }
    return self.traitCollection;
}

- (void)sci_applyColors {
    UITraitCollection *traits = [self sci_effectiveTraitCollection];
    self.onTintColor = [SCIUtils SCIColor_SettingsSwitchOnTintForTraitCollection:traits];
    self.thumbTintColor = [SCIUtils SCIColor_SettingsSwitchThumbTintForTraitCollection:traits];
}

- (void)sci_scheduleColorRefresh {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf sci_applyColors];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf sci_applyColors];
    });
}

@end
