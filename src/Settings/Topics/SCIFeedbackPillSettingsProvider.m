#import "SCIFeedbackPillSettingsProvider.h"
#import "../../Utils.h"

#import "../SCITopicSettingsSupport.h"

@implementation SCIFeedbackPillSettingsProvider

+ (NSArray<NSDictionary *> *)sci_actionSections {
    NSMutableArray<NSDictionary *> *sections = [NSMutableArray array];

    for (NSDictionary *sectionInfo in SCIFeedbackPillPreferenceSections()) {
        NSMutableArray<SCISetting *> *rows = [NSMutableArray array];
        for (NSDictionary *item in sectionInfo[@"items"] ?: @[]) {
            NSString *identifier = item[@"identifier"];
            NSString *title = item[@"title"] ?: @"Action";
            NSString *iconName = item[@"iconName"] ?: @"info";
            SCISetting *setting = [SCISetting switchCellWithTitle:title
                                                         subtitle:@""
                                                             icon:SCISettingsInstagramIcon(iconName, 20.0)
                                                      defaultsKey:SCIFeedbackPillDefaultsKey(identifier)];
            setting.userInfo = @{@"defaultValue": @YES};
            [rows addObject:setting];
        }

        [sections addObject:SCITopicSection(sectionInfo[@"title"], [rows copy], nil)];
    }

    return [sections copy];
}

+ (void)sci_showNextFeedbackPillPreview {
    static NSUInteger toneIndex = 0;

    NSArray<NSDictionary *> *configs = @[
        @{
            @"title": @"Saved to Gallery",
            @"subtitle": @"Feedback pill preview: success tone.",
            @"iconResource": @"circle_check_filled",
            @"tone": @(SCIFeedbackPillToneSuccess)
        },
        @{
            @"title": @"Something Went Wrong",
            @"subtitle": @"Feedback pill preview: error tone.",
            @"iconResource": @"error_filled",
            @"tone": @(SCIFeedbackPillToneError)
        },
        @{
            @"title": @"Heads Up",
            @"subtitle": @"Feedback pill preview: info tone.",
            @"iconResource": @"info_filled",
            @"tone": @(SCIFeedbackPillToneInfo)
        }
    ];

    NSDictionary *config = configs[toneIndex % configs.count];
    toneIndex++;

    [SCIUtils showToastForDuration:2.0
                             title:config[@"title"]
                          subtitle:config[@"subtitle"]
                      iconResource:config[@"iconResource"]
                              tone:[config[@"tone"] unsignedIntegerValue]];
}

+ (NSArray *)sections {
    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        SCITopicSection(@"", @[
            [SCISetting menuCellWithTitle:@"Style"
                                 subtitle:@""
                                     menu:SCIFeedbackPillStyleMenu()]
        ], @"Choose between neutral or colorful pill style"),
        SCITopicSection(@"Preview", @[
            [SCISetting buttonCellWithTitle:@"Test Feedback Pill" subtitle:@"Cycles through the success, error, and info tones" icon:SCISettingsInstagramIcon(@"info", 20.0) action:^{
                [self sci_showNextFeedbackPillPreview];
            }]
        ], nil)
    ]];

    NSArray *actionSections = [self sci_actionSections];
    [sections addObjectsFromArray:actionSections];
    return [sections copy];
}

@end
