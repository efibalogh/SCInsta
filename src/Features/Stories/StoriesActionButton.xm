#import <objc/message.h>

#import "../../Utils.h"
#import "../../Shared/ActionButton/ActionButtonCore.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSInteger const kSCIStoriesActionButtonTag = 921343;

static id SCIStorySectionControllerFromOverlay(UIView *overlayView) {
	NSArray<NSString *> *delegateSelectors = @[@"mediaOverlayDelegate", @"retryDelegate", @"tappableOverlayDelegate", @"buttonDelegate"];
	Class sectionControllerClass = NSClassFromString(@"IGStoryFullscreenSectionController");

	for (NSString *selectorName in delegateSelectors) {
		id delegate = SCIObjectForSelector(overlayView, selectorName);
		if (!delegate) continue;
		if (!sectionControllerClass || [delegate isKindOfClass:sectionControllerClass]) return delegate;
	}

	return nil;
}

static id SCIStoryMediaFromOverlay(UIView *overlayView) {
	id sectionController = SCIStorySectionControllerFromOverlay(overlayView);
	id media = SCIObjectForSelector(sectionController, @"currentStoryItem");
	if (media) return media;

	UIViewController *ancestorController = [SCIUtils viewControllerForAncestralView:overlayView];
	media = SCIObjectForSelector(ancestorController, @"currentStoryItem");
	return media;
}

static UIViewController *SCIStoryControllerFromOverlay(UIView *overlayView) {
	if (!overlayView) return nil;

	id ancestorController = SCIObjectForSelector(overlayView, @"_viewControllerForAncestor");
	if ([ancestorController isKindOfClass:[UIViewController class]]) {
		return (UIViewController *)ancestorController;
	}

	return [SCIUtils nearestViewControllerForView:overlayView];
}

static SCIActionButtonContext *SCIStoriesActionContext(UIView *overlayView) {
	SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
	context.source = SCIActionButtonSourceStories;
	context.view = overlayView;
	context.controller = SCIStoryControllerFromOverlay(overlayView);
	context.settingsTitle = SCIActionButtonTopicTitleForSource(SCIActionButtonSourceStories);
	context.supportedActions = SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceStories);
	context.mediaResolver = ^id (SCIActionButtonContext *resolvedContext) {
		return SCIStoryMediaFromOverlay(resolvedContext.view);
	};
	return context;
}

static void SCIInstallStoriesActionButton(UIView *overlayView) {
	if (!overlayView) return;

	if (SCIIsDirectVisualViewerAncestor(overlayView)) {
		UIButton *existing = (UIButton *)[overlayView viewWithTag:kSCIStoriesActionButtonTag];
		[existing removeFromSuperview];
		return;
	}

	UIButton *button = (UIButton *)[overlayView viewWithTag:kSCIStoriesActionButtonTag];
	if (![SCIUtils getBoolPref:@"action_button_stories_enabled"]) {
		[button removeFromSuperview];
		return;
	}

	button = SCIActionButtonWithTag(overlayView, kSCIStoriesActionButtonTag);
	SCIConfigureActionButton(button, SCIStoriesActionContext(overlayView));
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

	NSNumber *showCommentsPreview = [SCIUtils numericValueForObj:overlayView selectorName:@"showCommentsPreview"];
	if (!showCommentsPreview) showCommentsPreview = [SCIUtils numericValueForObj:overlayView selectorName:@"isShowingCommentsPreview"];
	if (!showCommentsPreview) {
		id kvcShowComments = SCIKVCObject(overlayView, @"showCommentsPreview");
		if ([kvcShowComments respondsToSelector:@selector(boolValue)]) showCommentsPreview = @([kvcShowComments boolValue]);
	}
	if (showCommentsPreview.boolValue) {
		UIView *hypeFaceswarmView = [SCIUtils getIvarForObj:overlayView name:"_hypeFaceswarmView"];
		if ([hypeFaceswarmView isKindOfClass:[UIView class]] && (y + size) > CGRectGetMinY(hypeFaceswarmView.frame)) {
			y = CGRectGetMinY(hypeFaceswarmView.frame) - size - 2.0;
		} else {
			y -= 35.0;
		}
	}

	button.frame = CGRectMake(CGRectGetWidth(overlayView.frame) - size - 7.0, y, size, size);
	SCIApplyButtonStyle(button, SCIActionButtonSourceStories);
}

%group SCIStoriesActionButtonHooks

%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
	%orig;
	SCIInstallStoriesActionButton((UIView *)self);
}
%end

%end

extern "C" void SCIInstallStoriesActionButtonHooksIfEnabled(void) {
	if (![SCIUtils getBoolPref:@"action_button_stories_enabled"]) return;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	%init(SCIStoriesActionButtonHooks);
	});
}
