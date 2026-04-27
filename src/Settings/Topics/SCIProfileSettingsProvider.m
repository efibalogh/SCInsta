#import "SCIProfileSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Utils.h"

static NSString * const kSCIProfileActionNone = @"none";
static NSString * const kSCIProfileActionCopyInfo = @"copy_info";
static NSString * const kSCIProfileActionViewPicture = @"view_picture";
static NSString * const kSCIProfileActionSharePicture = @"share_picture";
static NSString * const kSCIProfileActionSavePictureToVault = @"save_picture_vault";
static NSString * const kSCIProfileActionOpenSettings = @"profile_settings";
static NSString * const kSCIProfileDefaultCopyInfoKey = @"action_button_profile_default_copy_info_action";
static NSString * const kSCIProfileCopyInfoID = @"id";
static NSString * const kSCIProfileCopyInfoUsername = @"username";
static NSString * const kSCIProfileCopyInfoName = @"name";
static NSString * const kSCIProfileCopyInfoBio = @"bio";
static NSString * const kSCIProfileCopyInfoLink = @"link";
static CGFloat const kSCIProfileSettingsMenuIconPointSize = 22.0;

static UIImage *SCIProfileSettingsMenuIcon(NSString *resourceName, NSString *fallbackSystemName) {
    UIImage *image = resourceName.length > 0
        ? [SCIUtils sci_resourceImageNamed:resourceName template:YES maxPointSize:kSCIProfileSettingsMenuIconPointSize]
        : nil;
    if (!image && fallbackSystemName.length > 0) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:kSCIProfileSettingsMenuIconPointSize
                                                                                                     weight:UIImageSymbolWeightRegular];
        image = [UIImage systemImageNamed:fallbackSystemName withConfiguration:configuration];
    }
    return image;
}

static UICommand *SCIProfileActionDefaultCommand(NSString *title, NSString *resourceName, NSString *systemImageName, NSString *value) {
    UIImage *image = SCIProfileSettingsMenuIcon(resourceName, systemImageName);
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
        SCIProfileActionDefaultCommand(@"None", @"action", @"option", kSCIProfileActionNone),
        SCIProfileActionDefaultCommand(@"Copy Info", @"copy", @"doc.on.doc", kSCIProfileActionCopyInfo),
        SCIProfileActionDefaultCommand(@"View Picture", @"photo", @"photo", kSCIProfileActionViewPicture),
        SCIProfileActionDefaultCommand(@"Share Picture", @"share", @"square.and.arrow.up", kSCIProfileActionSharePicture),
        SCIProfileActionDefaultCommand(@"Download to Vault", @"photo_gallery", @"photo.on.rectangle.angled", kSCIProfileActionSavePictureToVault),
        SCIProfileActionDefaultCommand(@"Profile Settings", @"settings", @"gearshape", kSCIProfileActionOpenSettings)
    ]];
}

static UICommand *SCIProfileDefaultCopyInfoCommand(NSString *title, NSString *resourceName, NSString *systemImageName, NSString *value) {
    UIImage *image = SCIProfileSettingsMenuIcon(resourceName, systemImageName);
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
        SCIProfileDefaultCopyInfoCommand(@"ID", @"key", @"key", kSCIProfileCopyInfoID),
        SCIProfileDefaultCopyInfoCommand(@"Username", @"username", @"person", kSCIProfileCopyInfoUsername),
        SCIProfileDefaultCopyInfoCommand(@"Name", @"text", @"textformat", kSCIProfileCopyInfoName),
        SCIProfileDefaultCopyInfoCommand(@"Bio", @"caption", @"captions.bubble", kSCIProfileCopyInfoBio),
        SCIProfileDefaultCopyInfoCommand(@"Profile Link", @"link", @"link", kSCIProfileCopyInfoLink)
    ]];
}

@implementation SCIProfileSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Profile", @"profile", 22.0, @[
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
