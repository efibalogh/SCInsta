#import "SCITopicSettingsSupport.h"
#import "SCIEditActionsListViewController.h"

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

SCISetting *SCITopicNavigationSetting(NSString *title, NSString *iconName, CGFloat iconSize, NSArray *sections) {
    return [SCISetting navigationCellWithTitle:title
                                      subtitle:@""
                                          icon:[SCISymbol resourceSymbolWithName:iconName color:[UIColor labelColor] size:iconSize]
                                   navSections:sections];
}

static UICommand *SCIMenuCommand(NSString *title, NSString *imageName, NSString *fallback, NSString *defaultsKey, NSString *value, BOOL requiresRestart) {
    NSMutableDictionary *propertyList = [@{
        @"defaultsKey": defaultsKey,
        @"value": value
    } mutableCopy];

    if (requiresRestart) {
        propertyList[@"requiresRestart"] = @YES;
    }

    UIImage *image = nil;
    if (imageName.length > 0) {
        image = [[SCISymbol resourceSymbolWithName:imageName color:[UIColor labelColor] size:22.0] image];
    } else if (fallback.length > 0) {
        image = [[SCISymbol symbolWithName:fallback color:[UIColor labelColor] size:22.0] image];
    }

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
    [commands addObject:SCIMenuCommand(@"None", @"action", nil, defaultsKey, kSCIActionNone, NO)];
    for (NSString *identifier in supportedActions) {
        [commands addObject:SCIMenuCommand(SCIActionButtonDisplayTitle(identifier, topicTitle),
                                           SCIActionDescriptorIconName(identifier),
                                           nil,
                                           defaultsKey,
                                           identifier,
                                           NO)];
    }
    return [UIMenu menuWithChildren:commands];
}

SCISetting *SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSource source, NSString *topicTitle, NSArray<NSString *> *supportedActions, NSArray<SCIActionMenuSection *> *defaultSections) {
    SCIEditActionsListViewController *controller = [[SCIEditActionsListViewController alloc] initWithSource:source topicTitle:topicTitle];
    (void)supportedActions;
    (void)defaultSections;
    return [SCISetting navigationCellWithTitle:@"Configure Actions"
                                      subtitle:@"Edit sections, ordering, and disabled actions"
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
        SCIMenuCommand(@"Colorful", nil, nil, @"feedback_pill_style", @"colorful", NO)
    ]];
}

NSArray *SCIDevExampleSections(void) {
    return @[
        SCITopicSection(@"_ Example", @[
            [SCISetting staticCellWithTitle:@"Static Cell" subtitle:@"" icon:[SCISymbol symbolWithName:@"tablecells"]],
            [SCISetting switchCellWithTitle:@"Switch Cell" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell"],
            [SCISetting switchCellWithTitle:@"Switch Cell (Restart)" subtitle:@"Tap the switch" defaultsKey:@"test_switch_cell_restart" requiresRestart:YES],
            [SCISetting stepperCellWithTitle:@"Stepper Cell" subtitle:@"I have %@%@" defaultsKey:@"test_stepper_cell" min:-10 max:1000 step:5.5 label:@"$" singularLabel:@"$"],
            [SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using icon" icon:[SCISymbol symbolWithName:@"link" color:[UIColor systemTealColor] size:20.0] url:@"https://google.com"],
            [SCISetting linkCellWithTitle:@"Link Cell" subtitle:@"Using image" imageUrl:@"https://i.imgur.com/c9CbytZ.png" url:@"https://google.com"],
            [SCISetting buttonCellWithTitle:@"Button Cell" subtitle:@"" icon:[SCISymbol symbolWithName:@"oval.inset.filled"] action:^(void) { [SCIUtils showConfirmation:^(void){}]; }],
            [SCISetting menuCellWithTitle:@"Menu Cell" subtitle:@"Change the value on the right" menu:[UIMenu menuWithChildren:@[
                [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[
                    SCIMenuCommand(@"ABC", nil, nil, @"test_menu_cell", @"abc", NO),
                    SCIMenuCommand(@"123", nil, nil, @"test_menu_cell", @"123", NO)
                ]],
                SCIMenuCommand(@"Requires Restart", nil, nil, @"test_menu_cell", @"requires_restart", YES)
            ]]],
            [SCISetting navigationCellWithTitle:@"Navigation Cell" subtitle:@"" icon:[SCISymbol symbolWithName:@"rectangle.stack"] navSections:@[SCITopicSection(@"", @[], nil)]]
        ], @"_ Example")
    ];
}
