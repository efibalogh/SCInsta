#import "SCIMediaChrome.h"
#import "../../AssetUtils.h"
#import "../../Utils.h"

CGFloat const SCIMediaChromeTopBarContentHeight = 44.0;
CGFloat const SCIMediaChromeBottomBarHeight = 44.0;
CGFloat const SCIMediaChromeFloatingBottomBarHeight = 60.0;
CGFloat const SCIMediaChromeFloatingBottomBarBottomMargin = -12.0;

static CGFloat const kSCIMediaChromeTopIconPointSize = 24.0;
static CGFloat const kSCIMediaChromeBottomIconPointSize = 24.0;
static CGFloat const kSCIMediaChromeFloatingBottomBarHorizontalMargin = 22.0;

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

static UIImage *SCIMediaChromeNormalizedTopIcon(NSString *resourceName) {
    UIImage *source = SCIMediaChromeTopIcon(resourceName);
    if (!source) {
        return nil;
    }

    CGSize canvasSize = CGSizeMake(kSCIMediaChromeTopIconPointSize, kSCIMediaChromeTopIconPointSize);
    CGSize sourceSize = source.size;
    if (sourceSize.width <= 0.0 || sourceSize.height <= 0.0) {
        return [source imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    CGFloat scale = MIN(canvasSize.width / sourceSize.width, canvasSize.height / sourceSize.height);
    CGSize drawSize = CGSizeMake(sourceSize.width * scale, sourceSize.height * scale);
    CGRect drawRect = CGRectMake((canvasSize.width - drawSize.width) / 2.0,
                                 (canvasSize.height - drawSize.height) / 2.0,
                                 drawSize.width,
                                 drawSize.height);

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:canvasSize];
    UIImage *normalized = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        (void)context;
        [source drawInRect:CGRectIntegral(drawRect)];
    }];
    return [normalized imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

UIImage *SCIMediaChromeTopBarIcon(NSString *resourceName) {
    return SCIMediaChromeNormalizedTopIcon(resourceName);
}

UIBarButtonItem *SCIMediaChromeTopBarButtonItem(NSString *resourceName, id target, SEL action) {
    return SCIMediaChromeTopBarButtonItemWithTint(resourceName,
                                                 target,
                                                 action,
                                                 [SCIUtils SCIColor_InstagramPrimaryText],
                                                 nil);
}

UIBarButtonItem *SCIMediaChromeTopBarButtonItemWithTint(NSString *resourceName, id target, SEL action, UIColor *tintColor, NSString *accessibilityLabel) {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:SCIMediaChromeTopBarIcon(resourceName)
                                                             style:UIBarButtonItemStylePlain
                                                            target:target
                                                            action:action];
    item.tintColor = tintColor ?: [SCIUtils SCIColor_InstagramPrimaryText];
    item.accessibilityLabel = accessibilityLabel;
    return item;
}

void SCIMediaChromeSetLeadingTopBarItems(UINavigationItem *navigationItem, NSArray<UIBarButtonItem *> *items) {
    if (!navigationItem) {
        return;
    }
    if (@available(iOS 16.0, *)) {
        navigationItem.leftBarButtonItems = nil;
        navigationItem.leftBarButtonItem = nil;
        navigationItem.leadingItemGroups = items.count > 0
            ? @[ [UIBarButtonItemGroup fixedGroupWithRepresentativeItem:nil items:items] ]
            : @[];
        return;
    }
    navigationItem.leftBarButtonItems = items.count > 0 ? items : nil;
    navigationItem.leftBarButtonItem = nil;
}

void SCIMediaChromeSetTrailingTopBarItems(UINavigationItem *navigationItem, NSArray<UIBarButtonItem *> *items) {
    if (!navigationItem) {
        return;
    }
    if (@available(iOS 16.0, *)) {
        navigationItem.rightBarButtonItems = nil;
        navigationItem.rightBarButtonItem = nil;
        navigationItem.trailingItemGroups = items.count > 0
            ? @[ [UIBarButtonItemGroup fixedGroupWithRepresentativeItem:nil items:items] ]
            : @[];
        return;
    }
    navigationItem.rightBarButtonItems = items.count > 0 ? items : nil;
    navigationItem.rightBarButtonItem = nil;
}

static UIVisualEffect *SCIMediaChromeLiquidGlassEffect(void) {
    Class glassClass = NSClassFromString(@"UIGlassEffect");
    SEL selector = NSSelectorFromString(@"effectWithStyle:");
    if (!glassClass || ![glassClass respondsToSelector:selector]) {
        return nil;
    }

    NSMethodSignature *signature = [glassClass methodSignatureForSelector:selector];
    if (!signature) {
        return nil;
    }

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    NSInteger style = 0;
    __unsafe_unretained UIVisualEffect *effect = nil;
    invocation.target = glassClass;
    invocation.selector = selector;
    [invocation setArgument:&style atIndex:2];
    [invocation invoke];
    [invocation getReturnValue:&effect];
    return effect;
}

static UIVisualEffect *SCIMediaChromeBottomBarEffect(void) {
    if (@available(iOS 26.0, *)) {
        UIVisualEffect *glassEffect = SCIMediaChromeLiquidGlassEffect();
        if (glassEffect) {
            return glassEffect;
        }
    }
    return SCIMediaChromeBlurEffect();
}

UIView *SCIMediaChromeInstallBottomBar(UIView *hostView) {
    UIView *bar = [[UIView alloc] initWithFrame:CGRectZero];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = [UIColor clearColor];
    [hostView addSubview:bar];

    UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:SCIMediaChromeBottomBarEffect()];
    effectView.translatesAutoresizingMaskIntoConstraints = NO;
    effectView.userInteractionEnabled = NO;
    effectView.clipsToBounds = YES;
    effectView.layer.cornerCurve = kCACornerCurveContinuous;
    effectView.layer.cornerRadius = SCIMediaChromeFloatingBottomBarHeight / 2.0;
    effectView.backgroundColor = [UIColor clearColor];
    effectView.contentView.backgroundColor = [UIColor clearColor];
    [bar addSubview:effectView];
    [NSLayoutConstraint activateConstraints:@[
        [effectView.topAnchor constraintEqualToAnchor:bar.topAnchor],
        [effectView.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
        [effectView.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [effectView.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor constant:kSCIMediaChromeFloatingBottomBarHorizontalMargin],
        [bar.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor constant:-kSCIMediaChromeFloatingBottomBarHorizontalMargin],
        [bar.bottomAnchor constraintEqualToAnchor:hostView.safeAreaLayoutGuide.bottomAnchor constant:-SCIMediaChromeFloatingBottomBarBottomMargin],
        [bar.heightAnchor constraintEqualToConstant:SCIMediaChromeFloatingBottomBarHeight],
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
        [stack.bottomAnchor constraintEqualToAnchor:bottomBar.bottomAnchor],
    ]];
    for (UIView *v in row) {
        [v.heightAnchor constraintEqualToConstant:SCIMediaChromeFloatingBottomBarHeight].active = YES;
    }

    return stack;
}
