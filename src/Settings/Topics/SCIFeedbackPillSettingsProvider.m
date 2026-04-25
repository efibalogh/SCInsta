#import "SCIFeedbackPillSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Utils.h"

@implementation SCIFeedbackPillSettingsProvider

+ (void)sci_showNextFeedbackPillPreview {
    static NSUInteger toneIndex = 0;

    NSArray<NSDictionary *> *configs = @[
        @{
            @"title": @"Saved to Vault",
            @"subtitle": @"Feedback pill preview: success tone.",
            @"iconResource": @"circle_check_filled",
            @"fallback": @"checkmark.circle.fill",
            @"tone": @(SCIFeedbackPillToneSuccess)
        },
        @{
            @"title": @"Something Went Wrong",
            @"subtitle": @"Feedback pill preview: error tone.",
            @"iconResource": @"error_filled",
            @"fallback": @"xmark.octagon.fill",
            @"tone": @(SCIFeedbackPillToneError)
        },
        @{
            @"title": @"Heads Up",
            @"subtitle": @"Feedback pill preview: info tone.",
            @"iconResource": @"info_filled",
            @"fallback": @"info.circle.fill",
            @"tone": @(SCIFeedbackPillToneInfo)
        }
    ];

    NSDictionary *config = configs[toneIndex % configs.count];
    toneIndex++;

    [SCIUtils showToastForDuration:2.0
                             title:config[@"title"]
                          subtitle:config[@"subtitle"]
                      iconResource:config[@"iconResource"]
           fallbackSystemImageName:config[@"fallback"]
                              tone:[config[@"tone"] unsignedIntegerValue]];
}

+ (NSArray *)sections {
    return @[
        SCITopicSection(@"Style", @[
            [SCISetting menuCellWithTitle:@"Style" subtitle:@"Neutral glass vs. tone-tinted pill chrome" menu:SCIFeedbackPillStyleMenu()]
        ], nil),
        SCITopicSection(@"Preview", @[
            [SCISetting buttonCellWithTitle:@"Test Feedback Pill" subtitle:@"Cycles through the success, error, and info tones" icon:[SCISymbol resourceSymbolWithName:@"info" color:[UIColor labelColor] size:20.0] action:^{
                [self sci_showNextFeedbackPillPreview];
            }]
        ], nil)
    ];
}

@end
