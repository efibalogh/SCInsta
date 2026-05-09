#import "SCIAboutSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Tweak.h"
#import "../../Utils.h"
#import "../../AssetUtils.h"

@implementation SCIAboutSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"About", @"info", 24.0, @[
        SCITopicSection(@"Support", @[
            SCISettingApplyIconTint([SCISetting linkCellWithTitle:@"Donate to the original developer"
                                                         subtitle:@""
                                                             icon:[SCIAssetUtils instagramIconNamed:@"heart_filled" pointSize:24.0]
                                                              url:@"https://ko-fi.com/SoCuul"],
                                   [SCIUtils SCIColor_InstagramFavorite])
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
                                       icon:[SCIAssetUtils instagramIconNamed:@"action" pointSize:24.0]],
            [SCISetting staticCellWithTitle:@"Instagram"
                                   subtitle:[SCIUtils IGVersionString]
                                       icon:[SCIAssetUtils instagramIconNamed:@"app" pointSize:24.0]],
            [SCISetting staticCellWithTitle:@"Bundle ID"
                                   subtitle:[[NSBundle mainBundle] bundleIdentifier]
                                       icon:[SCIAssetUtils instagramIconNamed:@"key" pointSize:24.0]]
        ], nil)
    ]);
}

@end
