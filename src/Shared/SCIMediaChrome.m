#import "SCIMediaChrome.h"
#import "../Utils.h"

CGFloat const SCIMediaChromeTopBarContentHeight = 44.0;
CGFloat const SCIMediaChromeBottomBarHeight = 44.0;

static CGFloat const kSCIMediaChromeTopIconPointSize = 17.0;
static CGFloat const kSCIMediaChromeBottomIconPointSize = 16.0;

UIBlurEffect *SCIMediaChromeBlurEffect(void) {
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
}

void SCIApplyMediaChromeNavigationBar(UINavigationBar *bar) {
    if (!bar) return;

    UIColor *fg = [UIColor labelColor];
    UIColor *hairline = [UIColor separatorColor];

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundEffect = SCIMediaChromeBlurEffect();
    appearance.shadowColor = hairline;
    NSDictionary *titleAttrs = @{
        NSForegroundColorAttributeName: fg,
        NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold],
    };
    appearance.titleTextAttributes = titleAttrs;
    appearance.largeTitleTextAttributes = titleAttrs;

    UIBarButtonItemAppearance *itemAppearance = [[UIBarButtonItemAppearance alloc] init];
    itemAppearance.normal.titleTextAttributes = @{ NSForegroundColorAttributeName: fg };
    appearance.buttonAppearance = itemAppearance;
    appearance.doneButtonAppearance = itemAppearance;

    bar.standardAppearance = appearance;
    bar.scrollEdgeAppearance = appearance;
    bar.compactAppearance = appearance;
    bar.compactScrollEdgeAppearance = appearance;
    bar.translucent = YES;
    bar.tintColor = fg;
}

UILabel *SCIMediaChromeTitleLabel(NSString *text) {
    UILabel *label = [[UILabel alloc] init];
    label.text = text ?: @"";
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    label.textColor = [UIColor labelColor];
    label.textAlignment = NSTextAlignmentCenter;
    [label sizeToFit];
    return label;
}

UIImage *SCIMediaChromeTopIcon(NSString *resourceName, NSString *systemName) {
    UIImage *img = resourceName.length ? [SCIUtils sci_resourceImageNamed:resourceName template:YES] : nil;
    if (!img) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:kSCIMediaChromeTopIconPointSize
                                                                                          weight:UIImageSymbolWeightRegular];
        img = [UIImage systemImageNamed:systemName withConfiguration:cfg];
    }
    return img;
}

UIImage *SCIMediaChromeBottomIcon(NSString *resourceName, NSString *systemName) {
    UIImage *img = resourceName.length ? [SCIUtils sci_resourceImageNamed:resourceName template:YES] : nil;
    if (!img) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:kSCIMediaChromeBottomIconPointSize
                                                                                           weight:UIImageSymbolWeightRegular];
        img = [UIImage systemImageNamed:systemName withConfiguration:cfg];
    }
    return img;
}

UIBarButtonItem *SCIMediaChromeTopBarButtonItem(NSString *resourceName, NSString *systemName, id target, SEL action) {
    return [[UIBarButtonItem alloc] initWithImage:SCIMediaChromeTopIcon(resourceName, systemName)
                                            style:UIBarButtonItemStylePlain
                                           target:target
                                           action:action];
}

UIView *SCIMediaChromeInstallBottomBar(UIView *hostView) {
    UIView *bar = [[UIView alloc] initWithFrame:CGRectZero];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [hostView addSubview:bar];

    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:SCIMediaChromeBlurEffect()];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:blurView];
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:bar.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
    ]];

    UIView *topBorder = [[UIView alloc] initWithFrame:CGRectZero];
    topBorder.translatesAutoresizingMaskIntoConstraints = NO;
    topBorder.backgroundColor = [UIColor separatorColor];
    [bar addSubview:topBorder];
    [NSLayoutConstraint activateConstraints:@[
        [topBorder.topAnchor constraintEqualToAnchor:bar.topAnchor],
        [topBorder.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [topBorder.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [topBorder.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor],
        [bar.bottomAnchor constraintEqualToAnchor:hostView.bottomAnchor],
        [bar.topAnchor constraintEqualToAnchor:hostView.safeAreaLayoutGuide.bottomAnchor constant:-SCIMediaChromeBottomBarHeight],
    ]];

    return bar;
}

UIButton *SCIMediaChromeBottomButton(NSString *symbolName, NSString *resourceName, NSString *accessibilityLabel) {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setImage:SCIMediaChromeBottomIcon(resourceName, symbolName) forState:UIControlStateNormal];
    btn.tintColor = [UIColor labelColor];
    btn.accessibilityLabel = accessibilityLabel;
    return btn;
}

UIStackView *SCIMediaChromeInstallBottomRow(UIView *bottomBar, NSArray<UIView *> *row) {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:row];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.alignment = UIStackViewAlignmentCenter;
    [bottomBar addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:bottomBar.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:bottomBar.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:bottomBar.trailingAnchor],
        [stack.heightAnchor constraintEqualToConstant:SCIMediaChromeBottomBarHeight],
    ]];
    for (UIView *v in row) {
        [v.heightAnchor constraintEqualToConstant:SCIMediaChromeBottomBarHeight].active = YES;
    }

    return stack;
}
