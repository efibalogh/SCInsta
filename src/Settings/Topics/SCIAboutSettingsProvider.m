#import "SCIAboutSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Tweak.h"
#import "../../Utils.h"

@implementation SCIAboutSettingsProvider

+ (SCISetting *)rootSetting {
    NSString *footer = [NSString stringWithFormat:@"SCInsta %@\n\nInstagram v%@", SCIVersionString, [SCIUtils IGVersionString]];

    return SCITopicNavigationSetting(@"About", @"info", 24.0, @[
        SCITopicSection(@"Support", @[
            [SCISetting linkCellWithTitle:@"Donate" subtitle:@"Consider donating to support this tweak's development" icon:[SCISymbol symbolWithName:@"heart.circle.fill" color:[UIColor systemPinkColor] size:20.0] url:@"https://ko-fi.com/SoCuul"]
        ], nil),
        SCITopicSection(@"Credits", @[
            [SCISetting linkCellWithTitle:@"Developer" subtitle:@"SoCuul" imageUrl:@"https://i.imgur.com/c9CbytZ.png" url:@"https://socuul.dev"],
            [SCISetting linkCellWithTitle:@"View Repo" subtitle:@"View the tweak's source code on GitHub" imageUrl:@"https://i.imgur.com/BBUNzeP.png" url:@"https://github.com/SoCuul/SCInsta"]
        ], footer)
    ]);
}

@end
