#import "SCIAboutSettingsProvider.h"
#import "../../Utils.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Tweak.h"
#import "../../Utils.h"

@implementation SCIAboutSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"About", @"info", 24.0, @[
        SCITopicSection(@"Support", @[
            [SCISetting linkCellWithTitle:@"Donate to the original developer"
                                 subtitle:@""
                                     icon:[SCISymbol resourceSymbolWithName:@"heart_filled" color:[SCIUtils SCIColor_InstagramFavorite] size:24.0]
                                      url:@"https://ko-fi.com/SoCuul"]
        ], @"Consider donating to support this tweak's development"),
        SCITopicSection(@"Credits", @[
            [SCISetting linkCellWithTitle:@"Socuul"
                                 subtitle:@"Original developer"
                                 imageUrl:@"https://i.imgur.com/c9CbytZ.png"
                                      url:@"https://socuul.dev"],
            [SCISetting linkCellWithTitle:@"..."
                                 subtitle:@"... developer"
                                 imageUrl:@"https://avatars.githubusercontent.com/u/117626247?v=4"
                                      url:@"https://example.com"],
            [SCISetting linkCellWithTitle:@"View Repo"
                                 subtitle:@"View the tweak's source code on GitHub"
                                 imageUrl:@"https://i.imgur.com/BBUNzeP.png"
                                      url:@"https://github.com/efibalogh/SCInsta"]
        ], nil),
        SCITopicSection(@"Information", @[
            [SCISetting staticCellWithTitle:@"Tweak"
                                   subtitle:SCIVersionString
                                       icon:[SCISymbol resourceSymbolWithName:@"action" color:[SCIUtils SCIColor_InstagramPrimaryText] size:24.0]],
            [SCISetting staticCellWithTitle:@"Instagram"
                                   subtitle:[SCIUtils IGVersionString]
                                       icon:[SCISymbol resourceSymbolWithName:@"app" color:[SCIUtils SCIColor_InstagramPrimaryText] size:24.0]],
            [SCISetting staticCellWithTitle:@"Bundle ID"
                                   subtitle:[[NSBundle mainBundle] bundleIdentifier]
                                       icon:[SCISymbol resourceSymbolWithName:@"key" color:[SCIUtils SCIColor_InstagramPrimaryText] size:24.0]]
        ], nil)
    ]);
}

@end
