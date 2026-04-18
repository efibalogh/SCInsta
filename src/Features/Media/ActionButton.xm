// ActionButton.xm
//
// Aggregates modularized action-button implementation.

#import <objc/runtime.h>

#import "ActionButton/ActionButtonCore.h"
#import "ActionButton/ActionButtonLayout.h"

static const void *kSCIFeedExpandLongPressMarkerAssocKey = &kSCIFeedExpandLongPressMarkerAssocKey;

static void SCIAddFeedExpandLongPressIfNeeded(UIView *view, SEL action) {
	if (!view || !action) return;

	for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
		if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]]) continue;
		if (objc_getAssociatedObject(gesture, kSCIFeedExpandLongPressMarkerAssocKey)) {
			return;
		}
	}

	UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:view action:action];
	longPress.minimumPressDuration = 0.3;
	longPress.cancelsTouchesInView = NO;
	[view addGestureRecognizer:longPress];

	objc_setAssociatedObject(longPress, kSCIFeedExpandLongPressMarkerAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SCIExpandFeedLongPressAction(id self, SEL _cmd, UILongPressGestureRecognizer *sender) {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}

static void (*orig_swiftModernFeedVideo_didMove)(id, SEL);
static void (*orig_swiftModernFeedVideo_layout)(id, SEL);

static void SCIHookSwiftModernFeedVideoDidMove(id self, SEL _cmd) {
	if (orig_swiftModernFeedVideo_didMove) {
		orig_swiftModernFeedVideo_didMove(self, _cmd);
	}

	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

static void SCIHookSwiftModernFeedVideoLayout(id self, SEL _cmd) {
	if (orig_swiftModernFeedVideo_layout) {
		orig_swiftModernFeedVideo_layout(self, _cmd);
	}

	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%hook IGFeedPhotoView
- (void)didMoveToSuperview {
	%orig;

	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGFeedItemVideoView
- (void)didMoveToSuperview {
	%orig;

	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGFeedItemMediaCell
- (void)didMoveToSuperview {
	%orig;

	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_mediaCell_handleExpandLongPress:));
}

- (void)layoutSubviews {
	%orig;

	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_mediaCell_handleExpandLongPress:));
}

%new - (void)sci_mediaCell_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGModernFeedVideoCell
- (void)didMoveToSuperview {
	%orig;

	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

- (void)layoutSubviews {
	%orig;

	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGPageMediaView
- (void)didMoveToSuperview {
	%orig;

	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGUFIButtonBarView
- (void)layoutSubviews {
	%orig;

	SCIInstallFeedActionButton((UIView *)self);
}
%end

%hook IGUFIInteractionCountsView
- (void)layoutSubviews {
	%orig;

	SCIInstallFeedActionButton((UIView *)self);
}
%end

%hook IGSundialViewerVerticalUFI
- (void)layoutSubviews {
	%orig;

	SCIInstallReelsActionButton((UIView *)self);
}
%end

%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
	%orig;

	SCIInstallStoriesActionButton((UIView *)self);
}
%end

%hook IGDirectVisualMessageViewerController
- (void)viewDidLayoutSubviews {
	%orig;

	SCIInstallDirectActionButton((UIViewController *)self);
}
%end

%ctor {
	Class modernObjCName = objc_getClass("IGModernFeedVideoCell");
	Class modernSwiftRuntime = objc_getClass("IGModernFeedVideoCell.IGModernFeedVideoCell");
	if (modernSwiftRuntime && modernSwiftRuntime != modernObjCName) {
		class_addMethod(modernSwiftRuntime, @selector(sci_handleExpandLongPress:), (IMP)SCIExpandFeedLongPressAction, "v@:@");
		MSHookMessageEx(modernSwiftRuntime, @selector(didMoveToSuperview), (IMP)SCIHookSwiftModernFeedVideoDidMove, (IMP *)&orig_swiftModernFeedVideo_didMove);
		MSHookMessageEx(modernSwiftRuntime, @selector(layoutSubviews), (IMP)SCIHookSwiftModernFeedVideoLayout, (IMP *)&orig_swiftModernFeedVideo_layout);
	}
}
