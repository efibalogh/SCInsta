#import "SCIMediaChrome.h"
#import "../../AssetUtils.h"
#import "../../Utils.h"

CGFloat const SCIMediaChromeTopBarContentHeight = 44.0;
CGFloat const SCIMediaChromeBottomBarHeight = 44.0;

static CGFloat const kSCIMediaChromeTopIconPointSize = 24.0;
static CGFloat const kSCIMediaChromeBottomIconPointSize = 24.0;

UIBlurEffect *SCIMediaChromeBlurEffect(void) {
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
}

void SCIApplyMediaChromeNavigationBar(UINavigationBar *bar) {
    (void)bar;
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

UIImage *SCIMediaChromeTopIcon(NSString *resourceName) {
    return [SCIAssetUtils instagramIconNamed:(resourceName.length > 0 ? resourceName : @"more")
                                   pointSize:kSCIMediaChromeTopIconPointSize];
}

UIImage *SCIMediaChromeBottomIcon(NSString *resourceName) {
    return [SCIAssetUtils instagramIconNamed:(resourceName.length > 0 ? resourceName : @"more")
                                   pointSize:kSCIMediaChromeBottomIconPointSize];
}

UIBarButtonItem *SCIMediaChromeTopBarButtonItem(NSString *resourceName, id target, SEL action) {
    return [[UIBarButtonItem alloc] initWithImage:SCIMediaChromeTopIcon(resourceName)
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
    blurView.backgroundColor = [[SCIUtils SCIColor_InstagramBackground] colorWithAlphaComponent:0.82];
    [bar addSubview:blurView];
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:bar.topAnchor], [blurView.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
    ]];

    UIView *topBorder = [[UIView alloc] initWithFrame:CGRectZero];
    topBorder.translatesAutoresizingMaskIntoConstraints = NO;
    topBorder.backgroundColor = [SCIUtils SCIColor_InstagramSeparator];
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

UIButton *SCIMediaChromeBottomButton(NSString *resourceName, NSString *accessibilityLabel) {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setImage:SCIMediaChromeBottomIcon(resourceName) forState:UIControlStateNormal];
    btn.tintColor = [SCIUtils SCIColor_InstagramPrimaryText];
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
