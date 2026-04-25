#import "../../Shared/ActionButton/ActionButtonLayout.h"

%hook IGSundialViewerVerticalUFI
- (void)layoutSubviews {
	%orig;

	SCIInstallReelsActionButton((UIView *)self);
}
%end
