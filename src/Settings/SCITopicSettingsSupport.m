#import "SCITopicSettingsSupport.h"
#import "SCIEditActionsListViewController.h"
#import "SCIBulkActionMenuEditViewController.h"

#import "../AssetUtils.h"
#import "../Utils.h"
#import "../Shared/ActionButton/SCIActionDescriptor.h"
#import "../Shared/ActionButton/SCIActionButtonConfiguration.h"

NSDictionary *SCITopicSection(NSString *header, NSArray *rows, NSString *footer) {
    NSMutableDictionary *section = [@{
        @"header": header ?: @"",
        @"rows": rows ?: @[]
    } mutableCopy];

    if (footer.length > 0) {
        section[@"footer"] = footer;
    }

    return [section copy];
}

UIImage *SCISettingsInstagramIcon(NSString *name, CGFloat pointSize) {
    return [SCIAssetUtils instagramIconNamed:name pointSize:pointSize];
}

UIImage *SCISettingsSystemIcon(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight) {
    return [SCIAssetUtils resolvedImageNamed:name
                                   pointSize:pointSize
                                      weight:weight
                                      source:SCIResolvedImageSourceSystemSymbol
                               renderingMode:UIImageRenderingModeAlwaysTemplate];
}

SCISetting *SCISettingApplyIconTint(SCISetting *setting, UIColor *tintColor) {
    setting.iconTintColor = tintColor;
    return setting;
}

SCISetting *SCITopicNavigationSetting(NSString *title, NSString *iconName, CGFloat iconSize, NSArray *sections) {
    return SCISettingApplyIconTint([SCISetting navigationCellWithTitle:title
                                                              subtitle:@""
                                                                  icon:SCISettingsInstagramIcon(iconName, iconSize)
                                                           navSections:sections],
                                   [SCIUtils SCIColor_InstagramPrimaryText]);
}

static UICommand *SCIMenuCommand(NSString *title, NSString *imageName, NSString *fallback, NSString *defaultsKey, NSString *value, BOOL requiresRestart) {
    NSMutableDictionary *propertyList = [@{
        @"defaultsKey": defaultsKey,
        @"value": value
    } mutableCopy];

    if (requiresRestart) {
        propertyList[@"requiresRestart"] = @YES;
    }

    UIImage *image = [SCIAssetUtils resolvedImageNamed:imageName
                                    fallbackSystemName:fallback
                                             pointSize:22.0
                                                weight:UIImageSymbolWeightRegular
                                                source:(imageName.length > 0 ? SCIResolvedImageSourceInstagramIcon : SCIResolvedImageSourceSystemSymbol)
                                         renderingMode:UIImageRenderingModeAlwaysTemplate];

    return [UICommand commandWithTitle:title
                                 image:image
                                action:@selector(menuChanged:)
                          propertyList:[propertyList copy]];
}

static NSString *SCIActionButtonDisplayTitle(NSString *identifier, NSString *topicTitle) {
    return SCIActionDescriptorDisplayTitle(identifier, topicTitle);
}

UIMenu *SCIActionButtonDefaultActionMenu(NSString *defaultsKey, NSString *topicTitle, NSArray<NSString *> *supportedActions) {
    NSMutableArray<UIMenuElement *> *commands = [NSMutableArray array];

    NSMutableOrderedSet<NSString *> *supportedSet = [NSMutableOrderedSet orderedSet];
    for (NSString *identifier in supportedActions ?: @[]) {
        if ([identifier isKindOfClass:[NSString class]] && identifier.length > 0) {
            [supportedSet addObject:identifier];
        }
    }

    NSArray<NSArray<NSString *> *> *groups = @[
        @[kSCIActionDownloadLibrary, kSCIActionDownloadShare, kSCIActionDownloadGallery],
        @[kSCIActionExpand, kSCIActionViewThumbnail],
        @[kSCIActionCopyMedia, kSCIActionCopyDownloadLink, kSCIActionCopyCaption],
        @[kSCIActionOpenTopicSettings, kSCIActionRepost]
    ];

    for (NSInteger groupIndex = 0; groupIndex < (NSInteger)groups.count; groupIndex++) {
        NSArray<NSString *> *group = groups[groupIndex];
        NSMutableArray<UIMenuElement *> *groupCommands = [NSMutableArray array];
        for (NSString *identifier in group) {
            if (![supportedSet containsObject:identifier]) continue;
            [groupCommands addObject:SCIMenuCommand(SCIActionButtonDisplayTitle(identifier, topicTitle),
                                                    SCIActionDescriptorIconName(identifier),
                                                    nil,
                                                    defaultsKey,
                                                    identifier,
                                                    NO)];
        }
        if (groupIndex == (NSInteger)groups.count - 1) {
            [groupCommands addObject:SCIMenuCommand(@"None", @"action", nil, defaultsKey, kSCIActionNone, NO)];
        }
        if (groupCommands.count == 0) continue;
        [commands addObject:[UIMenu menuWithTitle:@""
                                            image:nil
                                       identifier:nil
                                          options:UIMenuOptionsDisplayInline
                                         children:groupCommands]];
    }

    if (commands.count == 0) {
        [commands addObject:SCIMenuCommand(@"None", @"action", nil, defaultsKey, kSCIActionNone, NO)];
    }

    return [UIMenu menuWithChildren:commands];
}

SCISetting *SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSource source, NSString *topicTitle, NSArray<NSString *> *supportedActions, NSArray<SCIActionMenuSection *> *defaultSections) {
    SCIEditActionsListViewController *controller = [[SCIEditActionsListViewController alloc] initWithSource:source topicTitle:topicTitle];
    (void)supportedActions;
    (void)defaultSections;
    return [SCISetting navigationCellWithTitle:@"Configure Actions"
                                      subtitle:@"Edit primary sections and bulk submenus"
                                          icon:nil
                                 viewController:controller];
}

UIMenu *SCIReelsTapControlMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIMenuCommand(@"Default", nil, nil, @"reels_tap_control", @"default", YES),
        [UIMenu menuWithTitle:@""
                        image:nil
                   identifier:nil
                      options:UIMenuOptionsDisplayInline
                     children:@[
            SCIMenuCommand(@"Pause/Play", nil, nil, @"reels_tap_control", @"pause", YES),
            SCIMenuCommand(@"Mute/Unmute", nil, nil, @"reels_tap_control", @"mute", YES)
        ]]
    ]];
}

UIMenu *SCINavigationIconOrderingMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIMenuCommand(@"Default", nil, nil, @"nav_icon_ordering", @"default", YES),
        [UIMenu menuWithTitle:@""
                        image:nil
                   identifier:nil
                      options:UIMenuOptionsDisplayInline
                     children:@[
            SCIMenuCommand(@"Classic", nil, nil, @"nav_icon_ordering", @"classic", YES),
            SCIMenuCommand(@"Standard", nil, nil, @"nav_icon_ordering", @"standard", YES),
            SCIMenuCommand(@"Alternate", nil, nil, @"nav_icon_ordering", @"alternate", YES)
        ]]
    ]];
}

UIMenu *SCISwipeBetweenTabsMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIMenuCommand(@"Default", nil, nil, @"swipe_nav_tabs", @"default", YES),
        [UIMenu menuWithTitle:@""
                        image:nil
                   identifier:nil
                      options:UIMenuOptionsDisplayInline
                     children:@[
            SCIMenuCommand(@"Enabled", nil, nil, @"swipe_nav_tabs", @"enabled", YES),
            SCIMenuCommand(@"Disabled", nil, nil, @"swipe_nav_tabs", @"disabled", YES)
        ]]
    ]];
}

UIMenu *SCIFeedbackPillStyleMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIMenuCommand(@"Clean", nil, nil, @"feedback_pill_style", @"clean", NO),
        SCIMenuCommand(@"Colorful", nil, nil, @"feedback_pill_style", @"colorful", NO),
        SCIMenuCommand(@"Dynamic", nil, nil, @"feedback_pill_style", @"dynamic", NO)
    ]];
}

UIMenu *SCICacheAutoClearMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIMenuCommand(@"Never", nil, nil, @"cache_auto_clear_mode", @"never", NO),
        SCIMenuCommand(@"Always", nil, nil, @"cache_auto_clear_mode", @"always", NO),
        SCIMenuCommand(@"Daily", nil, nil, @"cache_auto_clear_mode", @"daily", NO),
        SCIMenuCommand(@"Weekly", nil, nil, @"cache_auto_clear_mode", @"weekly", NO),
        SCIMenuCommand(@"Monthly", nil, nil, @"cache_auto_clear_mode", @"monthly", NO)
    ]];
}

UIMenu *SCIMediaVideoQualityMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIMenuCommand(@"Always Ask", nil, nil, @"media_video_quality_default", @"always_ask", NO),
        SCIMenuCommand(@"High", nil, nil, @"media_video_quality_default", @"high", NO),
        SCIMenuCommand(@"High (Ignore Dash)", nil, nil, @"media_video_quality_default", @"high_ignore_dash", NO),
        SCIMenuCommand(@"Medium", nil, nil, @"media_video_quality_default", @"medium", NO),
        SCIMenuCommand(@"Low", nil, nil, @"media_video_quality_default", @"low", NO)
    ]];
}

UIMenu *SCIMediaPhotoQualityMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIMenuCommand(@"Always Ask", nil, nil, @"media_photo_quality_default", @"always_ask", NO),
        SCIMenuCommand(@"High", nil, nil, @"media_photo_quality_default", @"high", NO),
        SCIMenuCommand(@"Low", nil, nil, @"media_photo_quality_default", @"low", NO)
    ]];
}

NSArray *SCIDevExampleSections(void) {
    return @[
        SCITopicSection(@"_ Example", @[
            [SCISetting staticCellWithTitle:@"Static Cell" subtitle:@"" icon:SCISettingsSystemIcon(@"tablecells", 18.0, UIImageSymbolWeightRegular)],
            [SCISetting switchCellWithTitle:@"Switch Cell" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell"],
            [SCISetting switchCellWithTitle:@"Switch Cell (Restart)" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell_restart" requiresRestart:YES],
            [SCISetting stepperCellWithTitle:@"Stepper Cell" subtitle:@"I have %@%@" defaultsKey:@"test_stepper_cell" min:-10 max:1000 step:5.5 label:@"$" singularLabel:@"$"],
            SCISettingApplyIconTint([SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using icon" icon:SCISettingsSystemIcon(@"link", 20.0, UIImageSymbolWeightRegular) url:@"https://google.com"], [UIColor systemTealColor]),
            [SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using image" imageUrl:@"https://i.imgur.com/c9CbytZ.png" url:@"https://google.com"],
            [SCISetting buttonCellWithTitle:@"Button Cell" subtitle:@"" icon:SCISettingsSystemIcon(@"oval.inset.filled", 18.0, UIImageSymbolWeightRegular) action:^(void) { [SCIUtils showConfirmation:^(void){}]; }],
            [SCISetting menuCellWithTitle:@"Menu Cell" subtitle:@"Change the value on the right" menu:[UIMenu menuWithChildren:@[
                [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[
                    SCIMenuCommand(@"ABC", nil, nil, @"test_menu_cell", @"abc", NO),
                    SCIMenuCommand(@"123", nil, nil, @"test_menu_cell", @"123", NO)
                ]],
                SCIMenuCommand(@"Requires Restart", nil, nil, @"test_menu_cell", @"requires_restart", YES)
            ]]],
            [SCISetting navigationCellWithTitle:@"Navigation Cell" subtitle:@"" icon:SCISettingsSystemIcon(@"rectangle.stack", 18.0, UIImageSymbolWeightRegular) navSections:@[SCITopicSection(@"", @[], nil)]]
        ], @"_ Example")
    ];
}
