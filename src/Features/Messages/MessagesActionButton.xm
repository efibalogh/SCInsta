#import "../../Shared/ActionButton/ActionButtonLayout.h"

%hook IGDirectVisualMessageViewerController
- (void)viewDidLayoutSubviews {
	%orig;

	SCIInstallDirectActionButton((UIViewController *)self);
	__weak UIViewController *weakController = (UIViewController *)self;
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *strongController = weakController;
		if (!strongController) return;
		SCIInstallDirectActionButton(strongController);
	});
}
%end
