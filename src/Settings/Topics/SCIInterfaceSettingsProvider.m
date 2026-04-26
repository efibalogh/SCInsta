#import "SCIInterfaceSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "SCIFeedbackPillSettingsProvider.h"

@implementation SCIInterfaceSettingsProvider

+ (SCISetting *)experimentalLiquidGlassSetting {
    return [SCISetting navigationCellWithTitle:@"Liquid Glass"
                                      subtitle:@"Unsafe per-hook overrides for Instagram's internal liquid glass gates"
                                          icon:[SCISymbol symbolWithName:@"exclamationmark.triangle.fill" color:[UIColor systemOrangeColor] size:24.0]
                                   navSections:@[
        SCITopicSection(@"Unsafe / Experimental", @[
            [SCISetting switchCellWithTitle:@"In-App Notifications (Launcher)" subtitle:@"Forces liquid-glass styling for in-app notification surfaces when enabled" defaultsKey:@"liquid_glass_in_app_notifications" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Context Menus (Launcher)" subtitle:@"Forces liquid-glass styling for context menus when enabled" defaultsKey:@"liquid_glass_context_menus" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Toasts (Launcher)" subtitle:@"Toast chrome from launcher config" defaultsKey:@"liquid_glass_toasts" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Toast Peek (Launcher)" subtitle:@"Peek-style toast treatment" defaultsKey:@"liquid_glass_toast_peek" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Alert Dialogs (Launcher)" subtitle:@"System-style alert dialogs gated by launcher" defaultsKey:@"liquid_glass_alert_dialogs" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Icon Bar Buttons (Launcher)" subtitle:@"Small icon strip or accessory controls" defaultsKey:@"liquid_glass_icon_bar_buttons" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Internal Liquid Glass Debugger" subtitle:@"Enables Instagram's internal debugger entry points" defaultsKey:@"liquid_glass_internal_debugger" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"IGLiquidGlass +isEnabled" subtitle:@"Global IGLiquidGlass class gate" defaultsKey:@"liquid_glass_core_class" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Navigation Experiment: isEnabled" subtitle:@"IGLiquidGlassNavigationExperimentHelper shared state" defaultsKey:@"liquid_glass_nav_is_enabled" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Navigation Experiment: isDefaultValueSet" subtitle:@"Whether Instagram considers the nav experiment default applied" defaultsKey:@"liquid_glass_nav_default_value_set" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Navigation Experiment: Home Feed Header" subtitle:@"Liquid glass on the main feed header chrome" defaultsKey:@"liquid_glass_nav_home_feed_header" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Internal Swizzle Toggle" subtitle:@"Affects method swizzling used for liquid glass rollout" defaultsKey:@"liquid_glass_swizzle_toggle" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Badged Navigation Buttons" subtitle:@"Tab or navigation buttons that show notification badges" defaultsKey:@"liquid_glass_badged_nav_button" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Unified Video Back Button" subtitle:@"Back control in the unified video viewer" defaultsKey:@"liquid_glass_video_back_button" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Unified Video Camera Entry" subtitle:@"Camera entry control in unified video flow" defaultsKey:@"liquid_glass_video_camera_button" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Alert Dialog Action Buttons" subtitle:@"Primary and secondary actions on IGDS alert dialogs" defaultsKey:@"liquid_glass_alert_dialog_actions" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Interactive Liquid Tab Bar" subtitle:@"Replaces IGTabBar with IGLiquidGlassInteractiveTabBar and can break navigation" defaultsKey:@"liquid_glass_interactive_tab_bar" requiresRestart:YES]
        ], @"Restart Instagram after changes. These override Instagram's internal liquid-glass gates and may crash or mis-render the UI.")
    ]];
}

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Interface", @"interface", 24.0, @[
        SCITopicSection(@"Navigation", @[
            [SCISetting menuCellWithTitle:@"Icon Order" subtitle:@"The order of the icons on the bottom navigation bar" menu:SCINavigationIconOrderingMenu()],
            [SCISetting menuCellWithTitle:@"Swipe Between Tabs" subtitle:@"Lets you swipe to switch between navigation bar tabs" menu:SCISwipeBetweenTabsMenu()],
            [SCISetting switchCellWithTitle:@"Hide Feed Tab" subtitle:@"Hides the feed or home tab on the bottom navigation bar" defaultsKey:@"hide_feed_tab" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Hide Explore Tab" subtitle:@"Hides the explore or search tab on the bottom navigation bar" defaultsKey:@"hide_explore_tab" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Hide Messages Tab" subtitle:@"Hides the direct messages tab on the bottom navigation bar" defaultsKey:@"hide_messages_tab" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Hide Reels Tab" subtitle:@"Hides the reels tab on the bottom navigation bar" defaultsKey:@"hide_reels_tab" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Hide Create Tab" subtitle:@"Hides the create tab on the bottom navigation bar" defaultsKey:@"hide_create_tab" requiresRestart:YES]
        ], nil),
        SCITopicSection(@"Appearance", @[
            [SCISetting navigationCellWithTitle:@"Feedback Pill"
                                       subtitle:@"Style and preview the feedback pill"
                                           icon:[SCISymbol resourceSymbolWithName:@"info" color:[UIColor labelColor] size:20.0]
                                    navSections:[SCIFeedbackPillSettingsProvider sections]],
            [SCISetting switchCellWithTitle:@"Enable Teen App Icons" subtitle:@"When enabled, hold down on the Instagram logo to change the app icon" defaultsKey:@"teen_app_icons" requiresRestart:YES],
            [SCISetting switchCellWithTitle:@"Disable App Haptics" subtitle:@"Disables haptics and vibrations within the Instagram app" defaultsKey:@"disable_haptics"]
        ], nil),
        SCITopicSection(@"Explore", @[
            [SCISetting switchCellWithTitle:@"Hide Explore Posts Grid" subtitle:@"Hides the grid of suggested posts on the explore and search tab" defaultsKey:@"hide_explore_grid"],
            [SCISetting switchCellWithTitle:@"Hide Trending Searches" subtitle:@"Hides the trending searches under the explore search bar" defaultsKey:@"hide_trending_searches"]
        ], nil)
    ]);
}

@end
