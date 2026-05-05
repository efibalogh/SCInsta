#import <UIKit/UIKit.h>

#import "SCIStartupHooks.h"

static void SCIScheduleGeneralUIHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SCIInstallGeneralUIHooksIfNeeded();
        });
    });
}

static void SCIInstallLazyHooksForViewController(UIViewController *controller) {
    NSString *className = NSStringFromClass([controller class]);
    if (className.length == 0) {
        return;
    }

    if ([className isEqualToString:@"IGMainFeedViewController"]) {
        SCIInstallFeedSurfaceHooksIfNeeded();
        return;
    }

    if ([className isEqualToString:@"IGStoryViewerViewController"]) {
        SCIInstallStorySurfaceHooksIfNeeded();
        return;
    }

    if ([className isEqualToString:@"IGSundialFeedViewController"]) {
        SCIInstallReelsSurfaceHooksIfNeeded();
        return;
    }

    if ([className isEqualToString:@"IGDirectInboxViewController"] ||
        [className isEqualToString:@"IGDirectThreadViewController"] ||
        [className isEqualToString:@"IGDirectVisualMessageViewerController"]) {
        SCIInstallMessagesSurfaceHooksIfNeeded();
        return;
    }

    if ([className isEqualToString:@"IGProfileViewController"]) {
        SCIInstallProfileSurfaceHooksIfNeeded();
        return;
    }

}

static void SCIInstallPostAppearLazyHooksForViewController(UIViewController *controller) {
    NSString *className = NSStringFromClass([controller class]);
    if ([className isEqualToString:@"IGMainFeedViewController"]) {
        SCIScheduleGeneralUIHooks();
    }
}

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    SCIInstallLazyHooksForViewController(self);
    %orig(animated);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    SCIInstallPostAppearLazyHooksForViewController(self);
}

%end
