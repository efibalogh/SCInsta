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
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self sci_applyColors];
}

- (void)sci_commonInit {
    [self sci_applyColors];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sci_applyColors)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)sci_applyColors {
    self.onTintColor = [SCIUtils SCIColor_SettingsSwitchOnTintForTraitCollection:self.traitCollection];
    self.thumbTintColor = [SCIUtils SCIColor_SettingsSwitchThumbTintForTraitCollection:self.traitCollection];
}

@end
