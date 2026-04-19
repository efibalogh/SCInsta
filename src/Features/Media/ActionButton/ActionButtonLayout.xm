#import <objc/runtime.h>
#import <objc/message.h>

#import "ActionButtonCore.h"
#import "ActionButtonLayout.h"
#import "../../../Utils.h"

static NSString * const kSCIShowActionButtonPrefKey = @"show_action_button";

static NSInteger const kSCIFeedActionButtonTag = 921341;
static NSInteger const kSCIReelsActionButtonTag = 921342;
static NSInteger const kSCIStoriesActionButtonTag = 921343;
static NSInteger const kSCIDirectActionButtonTag = 921344;

static const void *kSCIReelsActionBottomConstraintAssocKey = &kSCIReelsActionBottomConstraintAssocKey;
static const void *kSCIReelsActionCenterXConstraintAssocKey = &kSCIReelsActionCenterXConstraintAssocKey;
static const void *kSCIReelsActionWidthConstraintAssocKey = &kSCIReelsActionWidthConstraintAssocKey;
static const void *kSCIReelsActionHeightConstraintAssocKey = &kSCIReelsActionHeightConstraintAssocKey;
static const void *kSCIDirectActionBottomConstraintAssocKey = &kSCIDirectActionBottomConstraintAssocKey;
static const void *kSCIDirectActionTrailingConstraintAssocKey = &kSCIDirectActionTrailingConstraintAssocKey;
static const void *kSCIDirectActionWidthConstraintAssocKey = &kSCIDirectActionWidthConstraintAssocKey;
static const void *kSCIDirectActionHeightConstraintAssocKey = &kSCIDirectActionHeightConstraintAssocKey;

void SCIInstallFeedActionButton(UIView *barView) {
	if (!barView) return;

	UIButton *button = (UIButton *)[barView viewWithTag:kSCIFeedActionButtonTag];

	if (![SCIUtils getBoolPref:kSCIShowActionButtonPrefKey]) {
		[button removeFromSuperview];
		return;
	}

	button = SCIActionButtonWithTag(barView, kSCIFeedActionButtonTag);

	SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
	context.source = SCIActionButtonSourceFeed;
	context.view = barView;

	SCIConfigureActionButton(button, context);
	if (button.hidden) return;

	CGRect anyFrame = SCIFeedAnyButtonFrameFromBarView(barView);
	UIView *firstRightButton = SCIFeedFirstRightButtonFromBarView(barView);
	if (!firstRightButton) {
		[button removeFromSuperview];
		return;
	}

	CGFloat width = CGRectGetWidth(anyFrame) > 0.0 ? CGRectGetWidth(anyFrame) : 40.0;
	CGFloat xAnchor = CGRectGetMinX(firstRightButton.frame);

	button.frame = CGRectMake(xAnchor - width, CGRectGetMinY(anyFrame) + 2.0, width, CGRectGetHeight(anyFrame));
	SCIApplyButtonStyle(button, SCIActionButtonSourceFeed);
}

void SCIInstallReelsActionButton(UIView *verticalUFIView) {
	if (!verticalUFIView) return;

	UIButton *button = (UIButton *)[verticalUFIView viewWithTag:kSCIReelsActionButtonTag];

	if (![SCIUtils getBoolPref:kSCIShowActionButtonPrefKey]) {
		[button removeFromSuperview];
		return;
	}

	button = SCIActionButtonWithTag(verticalUFIView, kSCIReelsActionButtonTag);

	SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
	context.source = SCIActionButtonSourceReels;
	context.view = verticalUFIView;

	SCIConfigureActionButton(button, context);
	if (button.hidden) return;

	CGFloat size = 52.0;
	button.translatesAutoresizingMaskIntoConstraints = NO;

	NSLayoutConstraint *bottomConstraint = objc_getAssociatedObject(button, kSCIReelsActionBottomConstraintAssocKey);
	NSLayoutConstraint *centerXConstraint = objc_getAssociatedObject(button, kSCIReelsActionCenterXConstraintAssocKey);
	NSLayoutConstraint *widthConstraint = objc_getAssociatedObject(button, kSCIReelsActionWidthConstraintAssocKey);
	NSLayoutConstraint *heightConstraint = objc_getAssociatedObject(button, kSCIReelsActionHeightConstraintAssocKey);

	if (!bottomConstraint || !centerXConstraint || !widthConstraint || !heightConstraint) {
		bottomConstraint = [button.bottomAnchor constraintEqualToAnchor:verticalUFIView.topAnchor constant:-5.0];
		centerXConstraint = [button.centerXAnchor constraintEqualToAnchor:verticalUFIView.centerXAnchor];
		widthConstraint = [button.widthAnchor constraintEqualToConstant:size];
		heightConstraint = [button.heightAnchor constraintEqualToConstant:size];

		[NSLayoutConstraint activateConstraints:@[
			bottomConstraint,
			centerXConstraint,
			widthConstraint,
			heightConstraint
		]];

		objc_setAssociatedObject(button, kSCIReelsActionBottomConstraintAssocKey, bottomConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(button, kSCIReelsActionCenterXConstraintAssocKey, centerXConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(button, kSCIReelsActionWidthConstraintAssocKey, widthConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(button, kSCIReelsActionHeightConstraintAssocKey, heightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	bottomConstraint.constant = -5.0;
	widthConstraint.constant = size;
	heightConstraint.constant = size;

	verticalUFIView.clipsToBounds = NO;
	verticalUFIView.layer.masksToBounds = NO;
	[verticalUFIView bringSubviewToFront:button];
	SCIApplyButtonStyle(button, SCIActionButtonSourceReels);
}

void SCIInstallStoriesActionButton(UIView *overlayView) {
	if (!overlayView) return;

	if (SCIIsDirectVisualViewerAncestor(overlayView)) {
		UIButton *existing = (UIButton *)[overlayView viewWithTag:kSCIStoriesActionButtonTag];
		[existing removeFromSuperview];
		return;
	}

	UIButton *button = (UIButton *)[overlayView viewWithTag:kSCIStoriesActionButtonTag];

	if (![SCIUtils getBoolPref:kSCIShowActionButtonPrefKey]) {
		[button removeFromSuperview];
		return;
	}

	button = SCIActionButtonWithTag(overlayView, kSCIStoriesActionButtonTag);

	SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
	context.source = SCIActionButtonSourceStories;
	context.view = overlayView;

	SCIConfigureActionButton(button, context);
	if (button.hidden) return;

	UIView *mediaView = [SCIUtils getIvarForObj:overlayView name:"_mediaView"];
	UIView *footerContainer = [SCIUtils getIvarForObj:overlayView name:"_footerContainerView"];
	if (![mediaView isKindOfClass:[UIView class]]) mediaView = nil;
	if (![footerContainer isKindOfClass:[UIView class]]) footerContainer = nil;

	if (!mediaView && !footerContainer) {
		[button removeFromSuperview];
		return;
	}

	CGFloat size = 38.0;
	CGFloat y = 0.0;

	if (mediaView) {
		CGRect mediaFrame = mediaView.frame;
		y = CGRectGetMaxY(mediaFrame) - size - 7.0;
		if (footerContainer && CGRectGetMinY(footerContainer.frame) < CGRectGetMaxY(mediaFrame)) {
			y -= 50.0;
		}
	} else {
		y = CGRectGetMinY(footerContainer.frame) - size - 12.0;
	}

	id showCommentsPreview = [SCIUtils getIvarForObj:overlayView name:"_showCommentsPreview"];
	BOOL hasCommentsPreview = [showCommentsPreview respondsToSelector:@selector(boolValue)] ? [showCommentsPreview boolValue] : NO;
	if (hasCommentsPreview) {
		UIView *hypeFaceswarmView = [SCIUtils getIvarForObj:overlayView name:"_hypeFaceswarmView"];
		if ([hypeFaceswarmView isKindOfClass:[UIView class]] && (y + size) > CGRectGetMinY(hypeFaceswarmView.frame)) {
			y = CGRectGetMinY(hypeFaceswarmView.frame) - size - 2.0;
		} else {
			y -= 35.0;
		}
	}

	CGFloat x = CGRectGetWidth(overlayView.frame) - size - 7.0;

	button.frame = CGRectMake(x, y, size, size);
	SCIApplyButtonStyle(button, SCIActionButtonSourceStories);
}

static UIView *SCIDirectOverlayView(UIViewController *controller) {
	if (!controller) return nil;

	id viewerContainer = [SCIUtils getIvarForObj:controller name:"_viewerContainerView"];
	if (!viewerContainer) viewerContainer = SCIKVCObject(controller, @"viewerContainerView");

	id overlay = SCIObjectForSelector(viewerContainer, @"overlayView");
	return [overlay isKindOfClass:[UIView class]] ? (UIView *)overlay : nil;
}

static CGFloat SCIHeightFromFrameLikeObject(id object) {
	if (!object) return 0.0;

	if ([object isKindOfClass:[UIView class]]) {
		return ((UIView *)object).frame.size.height;
	}

	@try {
		id frameValue = [object valueForKey:@"frame"];
		if ([frameValue isKindOfClass:[NSValue class]]) {
			return ((NSValue *)frameValue).CGRectValue.size.height;
		}
	} @catch (__unused NSException *exception) {
	}

	return 0.0;
}

static CGFloat SCIDirectBottomOffset(UIViewController *controller) {
	if (!controller) return 40.0;

	id inputView = [SCIUtils getIvarForObj:controller name:"_inputView"];
	NSInteger offset = (NSInteger)(controller.view.safeAreaInsets.bottom + 40.0);
	if (inputView) {
		offset = (NSInteger)(SCIHeightFromFrameLikeObject(inputView) + (CGFloat)offset);
	}

	return (CGFloat)offset;
}

void SCIInstallDirectActionButton(UIViewController *controller) {
	UIView *overlay = SCIDirectOverlayView(controller);
	if (!overlay) return;

	UIButton *button = (UIButton *)[overlay viewWithTag:kSCIDirectActionButtonTag];
	BOOL shouldShowActionButton = [SCIUtils getBoolPref:kSCIShowActionButtonPrefKey];

	if (!shouldShowActionButton) {
		[button removeFromSuperview];
		return;
	}

	if (shouldShowActionButton) {
		button = SCIActionButtonWithTag(overlay, kSCIDirectActionButtonTag);

		SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
		context.source = SCIActionButtonSourceDirect;
		context.controller = controller;

		SCIConfigureActionButton(button, context);
	} else {
		[button removeFromSuperview];
		button = nil;
	}

	CGFloat size = 44.0;
	CGFloat bottomOffset = SCIDirectBottomOffset(controller);

	if (button) {
		button.translatesAutoresizingMaskIntoConstraints = NO;

		NSLayoutConstraint *bottomConstraint = objc_getAssociatedObject(button, kSCIDirectActionBottomConstraintAssocKey);
		NSLayoutConstraint *trailingConstraint = objc_getAssociatedObject(button, kSCIDirectActionTrailingConstraintAssocKey);
		NSLayoutConstraint *widthConstraint = objc_getAssociatedObject(button, kSCIDirectActionWidthConstraintAssocKey);
		NSLayoutConstraint *heightConstraint = objc_getAssociatedObject(button, kSCIDirectActionHeightConstraintAssocKey);

		if (!bottomConstraint || !trailingConstraint || !widthConstraint || !heightConstraint) {
			trailingConstraint = [button.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-10.0];
			bottomConstraint = [button.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor constant:-bottomOffset];
			widthConstraint = [button.widthAnchor constraintEqualToConstant:size];
			heightConstraint = [button.heightAnchor constraintEqualToConstant:size];

			[NSLayoutConstraint activateConstraints:@[
				trailingConstraint,
				bottomConstraint,
				widthConstraint,
				heightConstraint
			]];

			objc_setAssociatedObject(button, kSCIDirectActionBottomConstraintAssocKey, bottomConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			objc_setAssociatedObject(button, kSCIDirectActionTrailingConstraintAssocKey, trailingConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			objc_setAssociatedObject(button, kSCIDirectActionWidthConstraintAssocKey, widthConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			objc_setAssociatedObject(button, kSCIDirectActionHeightConstraintAssocKey, heightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		trailingConstraint.constant = -10.0;
		bottomConstraint.constant = -bottomOffset;
		widthConstraint.constant = size;
		heightConstraint.constant = size;

		SCIApplyButtonStyle(button, SCIActionButtonSourceDirect);
		[overlay bringSubviewToFront:button];
	}
}
