#import "../../Shared/ActionButton/ActionButtonLayout.h"

%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
	%orig;

	SCIInstallStoriesActionButton((UIView *)self);
}
%end
