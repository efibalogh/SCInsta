#import "SCIProfileSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"

@implementation SCIProfileSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Profile", @"profile", 22.0, @[
        SCITopicSection(@"Profile Picture", @[
            [SCISetting switchCellWithTitle:@"Long Press to Expand Photo" subtitle:@"When enabled, long-pressing a profile picture opens the full-size expanded view" defaultsKey:@"profile_photo_zoom"]
        ], nil),
        SCITopicSection(@"Indicators", @[
            [SCISetting switchCellWithTitle:@"Show Following Indicator" subtitle:@"Shows whether the profile user follows you" defaultsKey:@"follow_indicator"]
        ], nil)
    ]);
}

@end
