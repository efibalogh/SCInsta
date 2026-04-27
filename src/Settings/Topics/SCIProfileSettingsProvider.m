#import "SCIProfileSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../AssetUtils.h"
#import "../../Utils.h"

static NSString * const kSCIProfileActionNone = @"none";
static NSString * const kSCIProfileActionCopyInfo = @"copy_info";
static NSString * const kSCIProfileActionViewPicture = @"view_picture";
static NSString * const kSCIProfileActionSharePicture = @"share_picture";
static NSString * const kSCIProfileActionSavePictureToGallery = @"save_picture_gallery";
static NSString * const kSCIProfileActionOpenSettings = @"profile_settings";
static NSString * const kSCIProfileDefaultCopyInfoKey = @"action_button_profile_default_copy_info_action";
static NSString * const kSCIProfileCopyInfoID = @"id";
static NSString * const kSCIProfileCopyInfoUsername = @"username";
static NSString * const kSCIProfileCopyInfoName = @"name";
static NSString * const kSCIProfileCopyInfoBio = @"bio";
static NSString * const kSCIProfileCopyInfoLink = @"link";
static CGFloat const kSCIProfileSettingsMenuIconPointSize = 22.0;

static UIImage *SCIProfileSettingsMenuIcon(NSString *resourceName) {
    return [SCIAssetUtils instagramIconNamed:resourceName pointSize:kSCIProfileSettingsMenuIconPointSize];
}

static UICommand *SCIProfileActionDefaultCommand(NSString *title, NSString *resourceName, NSString *value) {
    UIImage *image = SCIProfileSettingsMenuIcon(resourceName);
    return [UICommand commandWithTitle:title
                                 image:image
                                action:@selector(menuChanged:)
                          propertyList:@{
        @"defaultsKey": @"action_button_profile_default_action",
        @"value": value
    }];
}

static UIMenu *SCIProfileActionDefaultMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIProfileActionDefaultCommand(@"None", @"action", kSCIProfileActionNone),
        SCIProfileActionDefaultCommand(@"Copy Info", @"copy", kSCIProfileActionCopyInfo),
        SCIProfileActionDefaultCommand(@"View Picture", @"photo", kSCIProfileActionViewPicture),
        SCIProfileActionDefaultCommand(@"Share Picture", @"share", kSCIProfileActionSharePicture),
        SCIProfileActionDefaultCommand(@"Download to Gallery", @"photo_gallery", kSCIProfileActionSavePictureToGallery),
        SCIProfileActionDefaultCommand(@"Profile Settings", @"settings", kSCIProfileActionOpenSettings)
    ]];
}

static UICommand *SCIProfileDefaultCopyInfoCommand(NSString *title, NSString *resourceName, NSString *value) {
    UIImage *image = SCIProfileSettingsMenuIcon(resourceName);
    return [UICommand commandWithTitle:title
                                 image:image
                                action:@selector(menuChanged:)
                          propertyList:@{
        @"defaultsKey": kSCIProfileDefaultCopyInfoKey,
        @"value": value
    }];
}

static UIMenu *SCIProfileDefaultCopyInfoMenu(void) {
    return [UIMenu menuWithChildren:@[
        SCIProfileDefaultCopyInfoCommand(@"ID", @"key", kSCIProfileCopyInfoID),
        SCIProfileDefaultCopyInfoCommand(@"Username", @"username", kSCIProfileCopyInfoUsername),
        SCIProfileDefaultCopyInfoCommand(@"Name", @"text", kSCIProfileCopyInfoName),
        SCIProfileDefaultCopyInfoCommand(@"Bio", @"caption", kSCIProfileCopyInfoBio),
        SCIProfileDefaultCopyInfoCommand(@"Profile Link", @"link", kSCIProfileCopyInfoLink)
    ]];
}

@implementation SCIProfileSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Profile", @"profile", 24.0, @[
        SCITopicSection(@"Action Button", @[
            [SCISetting switchCellWithTitle:@"Enable Action Button" subtitle:@"Adds an action button to profile pages" defaultsKey:@"action_button_profile_enabled"],
            [SCISetting menuCellWithTitle:@"Default Tap Action" subtitle:@"Tap runs this profile tool. Long press opens the full menu" menu:SCIProfileActionDefaultMenu()],
            [SCISetting menuCellWithTitle:@"Copy Info Default" subtitle:@"When Default Tap Action is set to Copy Info, choose what gets copied" menu:SCIProfileDefaultCopyInfoMenu()]
        ], nil),
        SCITopicSection(@"Profile Picture", @[
            [SCISetting switchCellWithTitle:@"Long Press to Expand Photo" subtitle:@"When enabled, long-pressing a profile picture opens the full-size expanded view" defaultsKey:@"profile_photo_zoom"]
        ], nil),
        SCITopicSection(@"Indicators", @[
            [SCISetting switchCellWithTitle:@"Show Following Indicator" subtitle:@"Shows whether the profile user follows you" defaultsKey:@"follow_indicator"]
        ], nil),
        SCITopicSection(@"Confirmation", @[
            [SCISetting switchCellWithTitle:@"Confirm Follow" subtitle:@"Shows an alert when you tap Follow to confirm the action" defaultsKey:@"follow_confirm"],
            [SCISetting switchCellWithTitle:@"Confirm Unfollow" subtitle:@"Shows an alert when you unfollow to confirm the action" defaultsKey:@"unfollow_confirm"]
        ], nil)
    ]);
}

@end
