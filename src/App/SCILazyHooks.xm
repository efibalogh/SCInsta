#import <UIKit/UIKit.h>

#import "SCICore.h"
#import "SCIStartupProfiler.h"

static void SCIScheduleGeneralUIHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SCICoreInstallSurfaceHooks(SCISurfaceGeneralUI);
        });
    });
}

static void SCIInstallLazyHooksForViewController(UIViewController *controller) {
    static dispatch_once_t firstSurfaceOnceToken;
    dispatch_once(&firstSurfaceOnceToken, ^{
        SCIStartupMark([NSString stringWithFormat:@"first viewWillAppear %@", NSStringFromClass([controller class]) ?: @""]);
    });

    NSString *className = NSStringFromClass([controller class]);
    if (className.length == 0) {
        return;
    }

    if ([className isEqualToString:@"IGMainFeedViewController"]) {
        SCICoreInstallSurfaceHooks(SCISurfaceFeed);
        return;
    }

    if ([className isEqualToString:@"IGStoryViewerViewController"]) {
        SCICoreInstallSurfaceHooks(SCISurfaceStories);
        return;
    }

    if ([className isEqualToString:@"IGSundialFeedViewController"]) {
        SCICoreInstallSurfaceHooks(SCISurfaceReels);
        return;
    }

    if ([className isEqualToString:@"IGDirectInboxViewController"] ||
        [className isEqualToString:@"IGDirectThreadViewController"] ||
        [className isEqualToString:@"IGDirectVisualMessageViewerController"]) {
        SCICoreInstallSurfaceHooks(SCISurfaceMessages);
        return;
    }

    if ([className isEqualToString:@"IGProfileViewController"]) {
        SCICoreInstallSurfaceHooks(SCISurfaceProfile);
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
