#import "SCINotificationSettingsProvider.h"
#import "../SCITopicSettingsSupport.h"
#import "../../Utils.h"
#import "../../AssetUtils.h"
#import "../../Shared/UI/SCINotificationCenter.h"

@implementation SCINotificationSettingsProvider

+ (NSArray<NSDictionary *> *)sci_featureSectionsForHaptics:(BOOL)haptics {
    NSMutableArray<NSDictionary *> *sections = [NSMutableArray array];

    for (NSDictionary *sectionInfo in SCINotificationPreferenceSections()) {
        NSMutableArray<SCISetting *> *rows = [NSMutableArray array];
        for (NSDictionary *item in sectionInfo[@"items"] ?: @[]) {
            NSString *identifier = item[@"identifier"];
            NSString *title = item[@"title"] ?: @"Feature";
            NSString *iconName = item[@"iconName"] ?: @"info";
            SCISetting *setting = [SCISetting switchCellWithTitle:title
                                                         subtitle:@""
                                                             icon:[SCIAssetUtils instagramIconNamed:iconName pointSize:20.0]
                                                      defaultsKey:haptics ? SCINotificationHapticDefaultsKey(identifier) : SCINotificationDefaultsKey(identifier)];
            setting.userInfo = @{@"defaultValue": @YES};
            [rows addObject:setting];
        }

        NSString *sectionTitle = sectionInfo[@"title"] ?: @"";
        [sections addObject:SCITopicSection(sectionTitle, [rows copy], nil)];
    }

    return [sections copy];
}

+ (void)sci_showNextNotificationPreview {
    static NSUInteger toneIndex = 0;

    NSArray<NSDictionary *> *configs = @[
        @{
            @"title": @"Saved to Gallery",
            @"subtitle": @"Notification preview: success tone.",
            @"iconResource": @"circle_check_filled",
            @"tone": @(SCINotificationToneSuccess)
        },
        @{
            @"title": @"Something Went Wrong",
            @"subtitle": @"Notification preview: error tone.",
            @"iconResource": @"error_filled",
            @"tone": @(SCINotificationToneError)
        },
        @{
            @"title": @"Heads Up",
            @"subtitle": @"Notification preview: info tone.",
            @"iconResource": @"info_filled",
            @"tone": @(SCINotificationToneInfo)
        }
    ];

    NSDictionary *config = configs[toneIndex % configs.count];
    toneIndex++;

    SCINotify(kSCINotificationSettingsClearCache,
              config[@"title"],
              config[@"subtitle"],
              config[@"iconResource"],
              [config[@"tone"] unsignedIntegerValue]);
}

+ (NSArray *)sections {
    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        SCITopicSection(@"Appearance", @[
            [SCISetting switchCellWithTitle:@"Glow"
                                   subtitle:@"Adds a glow effect around notifications"
                                defaultsKey:kSCINotificationPillGlowEnabledKey],
            [SCISetting stepperCellWithTitle:@"Duration"
                                    subtitle:@"Dismiss after %@%@"
                                 defaultsKey:kSCINotificationPillDurationKey
                                         min:0.5
                                         max:5.0
                                        step:0.1
                                       label:@" seconds"
                               singularLabel:@" second"]
        ], nil),
        SCITopicSection(@"Preview", @[
            [SCISetting buttonCellWithTitle:@"Test Notification"
                                   subtitle:@""
                                       icon:nil
                                     action:^{ [self sci_showNextNotificationPreview]; }]
        ], nil),
        SCITopicSection(@"Haptics", @[
            [SCISetting navigationCellWithTitle:@"Haptics"
                                       subtitle:@"Feature-specific haptic feedback"
                                           icon:[SCIAssetUtils instagramIconNamed:@"notification" pointSize:22.0]
                                    navSections:[self sci_featureSectionsForHaptics:YES]]
        ], nil)
    ]];

    [sections addObjectsFromArray:[self sci_featureSectionsForHaptics:NO]];
    return [sections copy];
}

@end
