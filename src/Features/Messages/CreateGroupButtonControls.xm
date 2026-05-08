#import "../../Utils.h"
#import <objc/runtime.h>

static NSString * const kSCIConfirmCreateGroupButtonPref = @"confirm_create_group_button";
static NSString * const kSCIHideCreateGroupButtonPref = @"hide_create_group_button";
static NSString * const kSCICreateGroupButtonRuntimeClassName = @"IGShareSheet.IGShareSheetCreateOrSendToGroupFacepileButton";
static NSString * const kSCIBottomButtonsViewRuntimeClassName = @"IGShareSheet.IGSharesheetBottomButtonsView";
static NSString * const kSCIBottomButtonsContainerRuntimeClassName = @"IGShareSheet.IGShareSheetBottomButtonsViewContainer";

static const void *kSCIGroupButtonBypassConfirmAssocKey = &kSCIGroupButtonBypassConfirmAssocKey;
static const void *kSCIGroupButtonPendingActionAssocKey = &kSCIGroupButtonPendingActionAssocKey;
static const void *kSCIGroupButtonPendingTargetAssocKey = &kSCIGroupButtonPendingTargetAssocKey;
static const void *kSCICreateGroupButtonRemovedAssocKey = &kSCICreateGroupButtonRemovedAssocKey;

@interface IGShareSheetCreateOrSendToGroupFacepileButton : UIControl
@end

static BOOL SCIShouldHideCreateGroupButton(void) {
    return [SCIUtils getBoolPref:kSCIHideCreateGroupButtonPref];
}

static BOOL SCIShouldConfirmCreateGroupButton(void) {
    return !SCIShouldHideCreateGroupButton() && [SCIUtils getBoolPref:kSCIConfirmCreateGroupButtonPref];
}

static BOOL SCIClassMatchesNamedClass(id object, NSString *className) {
    if (!object || className.length == 0) return NO;
    Class cls = NSClassFromString(className);
    return cls ? [object isKindOfClass:cls] : NO;
}

static void SCICollapseConstraintForViewInArray(UIView *view, NSArray<NSLayoutConstraint *> *constraints) {
    for (NSLayoutConstraint *constraint in constraints) {
        BOOL referencesView = (constraint.firstItem == view || constraint.secondItem == view);
        if (!referencesView) continue;

        NSLayoutAttribute firstAttribute = constraint.firstAttribute;
        NSLayoutAttribute secondAttribute = constraint.secondAttribute;
        BOOL sizeConstraint = (firstAttribute == NSLayoutAttributeWidth
                            || firstAttribute == NSLayoutAttributeHeight
                            || secondAttribute == NSLayoutAttributeWidth
                            || secondAttribute == NSLayoutAttributeHeight);
        if (!sizeConstraint) continue;

        constraint.constant = 0.0;
    }
}

static UIView *SCIFindCreateGroupButtonSubview(UIView *view) {
    if (!view) return nil;
    if (SCIClassMatchesNamedClass(view, kSCICreateGroupButtonRuntimeClassName)) {
        return view;
    }
    for (UIView *subview in view.subviews) {
        UIView *match = SCIFindCreateGroupButtonSubview(subview);
        if (match) return match;
    }
    return nil;
}

static CGFloat SCIVisibleSubviewMaxY(UIView *view) {
    CGFloat maxY = 0.0;
    for (UIView *subview in view.subviews) {
        if (subview.hidden || subview.alpha <= 0.0) continue;
        CGFloat candidate = CGRectGetMaxY(subview.frame);
        if (candidate > maxY) {
            maxY = candidate;
        }
    }
    return maxY;
}

static void SCIApplyCreateGroupButtonVisibility(UIView *view) {
    if (!view) return;

    if (!SCIShouldHideCreateGroupButton()) {
        view.hidden = NO;
        view.alpha = 1.0;
        view.userInteractionEnabled = YES;
        return;
    }

    view.hidden = YES;
    view.alpha = 0.0;
    view.userInteractionEnabled = NO;
    view.clipsToBounds = YES;
    [view invalidateIntrinsicContentSize];

    CGRect frame = view.frame;
    frame.size.width = 0.0;
    frame.size.height = 0.0;
    view.frame = frame;

    SCICollapseConstraintForViewInArray(view, view.constraints);
    if (view.superview) {
        SCICollapseConstraintForViewInArray(view, view.superview.constraints);
    }
}

static void SCIRemoveCreateGroupButtonFromHierarchyIfNeeded(UIView *rootView) {
    if (!SCIShouldHideCreateGroupButton() || !rootView) return;

    UIView *button = SCIFindCreateGroupButtonSubview(rootView);
    if (!button) return;
    if ([objc_getAssociatedObject(button, kSCICreateGroupButtonRemovedAssocKey) boolValue]) return;

    objc_setAssociatedObject(button, kSCICreateGroupButtonRemovedAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [button removeFromSuperview];
}

static void SCIApplyBottomButtonsCollapse(UIView *view) {
    if (!SCIShouldHideCreateGroupButton() || !view) return;

    SCIRemoveCreateGroupButtonFromHierarchyIfNeeded(view);

    CGFloat maxY = SCIVisibleSubviewMaxY(view);
    if (maxY > 0.0) {
        CGRect frame = view.frame;
        frame.size.height = ceil(maxY);
        view.frame = frame;
        SCICollapseConstraintForViewInArray(view, view.constraints);
        if (view.superview) {
            for (NSLayoutConstraint *constraint in view.superview.constraints) {
                if ((constraint.firstItem == view || constraint.secondItem == view)
                    && (constraint.firstAttribute == NSLayoutAttributeHeight || constraint.secondAttribute == NSLayoutAttributeHeight)) {
                    constraint.constant = ceil(maxY);
                }
            }
        }
    }
}

%group SCICreateGroupButtonControls

%hook SCICreateGroupButtonClass

- (void)didMoveToSuperview {
    %orig;
    SCIApplyCreateGroupButtonVisibility(self);
}

- (void)layoutSubviews {
    %orig;
    if (SCIShouldHideCreateGroupButton()) {
        SCIApplyCreateGroupButtonVisibility(self);
    }
}

- (CGSize)intrinsicContentSize {
    if (SCIShouldHideCreateGroupButton()) {
        return CGSizeZero;
    }
    return %orig;
}

- (CGSize)sizeThatFits:(CGSize)size {
    if (SCIShouldHideCreateGroupButton()) {
        return CGSizeZero;
    }
    return %orig(size);
}

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (!SCIShouldConfirmCreateGroupButton() || !action || !target) {
        %orig(action, target, event);
        return;
    }

    NSNumber *bypassConfirm = objc_getAssociatedObject(self, kSCIGroupButtonBypassConfirmAssocKey);
    if (bypassConfirm.boolValue) {
        objc_setAssociatedObject(self, kSCIGroupButtonBypassConfirmAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, kSCIGroupButtonPendingActionAssocKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(self, kSCIGroupButtonPendingTargetAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig(action, target, event);
        return;
    }

    objc_setAssociatedObject(self, kSCIGroupButtonPendingActionAssocKey, NSStringFromSelector(action), OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, kSCIGroupButtonPendingTargetAssocKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    __weak __typeof__(self) weakSelf = self;
    [SCIUtils showConfirmation:^{
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *pendingActionName = objc_getAssociatedObject(strongSelf, kSCIGroupButtonPendingActionAssocKey);
        id pendingTarget = objc_getAssociatedObject(strongSelf, kSCIGroupButtonPendingTargetAssocKey);
        if (pendingActionName.length == 0 || !pendingTarget) {
            return;
        }

        objc_setAssociatedObject(strongSelf, kSCIGroupButtonBypassConfirmAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [strongSelf sendAction:NSSelectorFromString(pendingActionName) to:pendingTarget forEvent:nil];
    } cancelHandler:^{
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        objc_setAssociatedObject(strongSelf, kSCIGroupButtonPendingActionAssocKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(strongSelf, kSCIGroupButtonPendingTargetAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } title:@"Confirm Group Creation"
      message:@"Are you sure you want to create or send to a group with the selected recipients?"];
}

%end

%hook SCIBottomButtonsViewClass

- (void)layoutSubviews {
    %orig;
    SCIApplyBottomButtonsCollapse(self);
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize original = %orig(size);
    if (!SCIShouldHideCreateGroupButton()) {
        return original;
    }
    CGFloat collapsedHeight = SCIVisibleSubviewMaxY(self);
    if (collapsedHeight > 0.0 && SCIFindCreateGroupButtonSubview(self)) {
        original.height = ceil(collapsedHeight);
    }
    return original;
}

- (CGSize)intrinsicContentSize {
    CGSize original = %orig;
    if (!SCIShouldHideCreateGroupButton()) {
        return original;
    }
    CGFloat collapsedHeight = SCIVisibleSubviewMaxY(self);
    if (collapsedHeight > 0.0 && SCIFindCreateGroupButtonSubview(self)) {
        original.height = ceil(collapsedHeight);
    }
    return original;
}

%end

%hook SCIBottomButtonsContainerClass

- (void)layoutSubviews {
    %orig;
    if (!SCIShouldHideCreateGroupButton()) return;

    UIView *view = (UIView *)self;
    UIView *bottomButtonsView = SCIFindCreateGroupButtonSubview(self) ? self : nil;
    if (!bottomButtonsView) {
        for (UIView *subview in view.subviews) {
            if (SCIClassMatchesNamedClass(subview, kSCIBottomButtonsViewRuntimeClassName)) {
                bottomButtonsView = subview;
                break;
            }
        }
    }
    if (!bottomButtonsView) return;

    SCIApplyBottomButtonsCollapse(bottomButtonsView);
    CGFloat height = CGRectGetHeight(bottomButtonsView.frame);
    if (height > 0.0) {
        CGRect frame = view.frame;
        frame.size.height = height;
        view.frame = frame;
        SCICollapseConstraintForViewInArray(view, view.constraints);
        if (view.superview) {
            for (NSLayoutConstraint *constraint in view.superview.constraints) {
                if ((constraint.firstItem == view || constraint.secondItem == view)
                    && (constraint.firstAttribute == NSLayoutAttributeHeight || constraint.secondAttribute == NSLayoutAttributeHeight)) {
                    constraint.constant = height;
                }
            }
        }
    }
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize original = %orig(size);
    if (!SCIShouldHideCreateGroupButton()) {
        return original;
    }
    UIView *view = (UIView *)self;
    for (UIView *subview in view.subviews) {
        if (SCIClassMatchesNamedClass(subview, kSCIBottomButtonsViewRuntimeClassName)) {
            CGFloat height = SCIVisibleSubviewMaxY(subview);
            if (height > 0.0) {
                original.height = ceil(height);
            }
            break;
        }
    }
    return original;
}

- (CGSize)intrinsicContentSize {
    CGSize original = %orig;
    if (!SCIShouldHideCreateGroupButton()) {
        return original;
    }
    UIView *view = (UIView *)self;
    for (UIView *subview in view.subviews) {
        if (SCIClassMatchesNamedClass(subview, kSCIBottomButtonsViewRuntimeClassName)) {
            CGFloat height = SCIVisibleSubviewMaxY(subview);
            if (height > 0.0) {
                original.height = ceil(height);
            }
            break;
        }
    }
    return original;
}

%end

%end

extern "C" void SCIInstallCreateGroupButtonControlHooksIfEnabled(void) {
    if (!SCIShouldHideCreateGroupButton() && !SCIShouldConfirmCreateGroupButton()) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    Class createGroupButtonClass = objc_getClass(kSCICreateGroupButtonRuntimeClassName.UTF8String);
    Class bottomButtonsViewClass = objc_getClass(kSCIBottomButtonsViewRuntimeClassName.UTF8String);
    Class bottomButtonsContainerClass = objc_getClass(kSCIBottomButtonsContainerRuntimeClassName.UTF8String);

    if (createGroupButtonClass && bottomButtonsViewClass && bottomButtonsContainerClass) {
        %init(SCICreateGroupButtonControls,
              SCICreateGroupButtonClass=createGroupButtonClass,
              SCIBottomButtonsViewClass=bottomButtonsViewClass,
              SCIBottomButtonsContainerClass=bottomButtonsContainerClass);
    }
    });
}
