#import "../InstagramHeaders.h"
#import "../Tweak.h"
#import "../Utils.h"
#import "SCICore.h"
#import "SCIFlexLoader.h"
#import "SCIStartupProfiler.h"

%hook IGInstagramAppDelegate
- (_Bool)application:(UIApplication *)application willFinishLaunchingWithOptions:(id)arg2 {
    SCIStartupMark(@"willFinishLaunching begin");
    SCICoreRegisterBootstrapDefaults();
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [SCIUtils sci_normalizeLiquidGlassPreferences];

    if ([SCIUtils getBoolPref:@"liquid_glass_buttons"]) {
        [defaults setValue:@(YES) forKey:@"instagram.override.project.lucent.navigation"];
    } else {
        [defaults setValue:@(NO) forKey:@"instagram.override.project.lucent.navigation"];
    }

    if ([SCIUtils getBoolPref:@"liquid_glass_surfaces"]) {
        [defaults setBool:YES forKey:@"liquid_glass_override_enabled"];
        [defaults setBool:YES forKey:@"IGLiquidGlassOverrideEnabled"];
    } else {
        [defaults setBool:NO forKey:@"liquid_glass_override_enabled"];
        [defaults setBool:NO forKey:@"IGLiquidGlassOverrideEnabled"];
    }
    [SCIUtils applyLiquidGlassNavigationExperimentOverride];
    SCICoreInstallLaunchCriticalHooks();
    SCIStartupMark(@"launch critical hooks installed");

    return %orig;
}

- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    SCIStartupMark(@"didFinishLaunching begin");
    %orig;
    SCIStartupMark(@"didFinishLaunching orig returned");

    double openDelay = [SCIUtils getBoolPref:@"tweak_settings_app_launch"] ? 0.0 : 5.0;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(openDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (
            ![[[NSUserDefaults standardUserDefaults] objectForKey:@"SCInstaFirstRun"] isEqualToString:SCIVersionString]
            || [SCIUtils getBoolPref:@"tweak_settings_app_launch"]
        ) {
            NSLog(@"[SCInsta] First run, initializing");
            NSLog(@"[SCInsta] Displaying SCInsta first-time settings modal");
            SCICoreShowSettingsIfNeeded([self window]);
        }
    });
    if ([SCIUtils getBoolPref:@"flex_app_launch"]) {
        SCIFlexShowExplorer(@"launch");
    }

    return true;
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        SCICoreRegisterDefaults();
        [SCIUtils evaluateAutomaticCacheClearIfNeeded];
    });

    if ([SCIUtils getBoolPref:@"flex_app_start"]) {
        SCIFlexShowExplorer(@"focus");
    }
}
%end
