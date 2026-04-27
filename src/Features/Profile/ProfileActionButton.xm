#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Downloader/Download.h"
#import "../../Shared/MediaPreview/SCIFullScreenMediaPlayer.h"
#import "../../Shared/Vault/SCIVaultFile.h"
#import "../../Shared/Vault/SCIVaultOriginController.h"
#import "../../Shared/Vault/SCIVaultSaveMetadata.h"

static NSString * const kSCIProfileActionButtonDefaultKey = @"action_button_profile_default_action";
static NSString * const kSCIProfileActionButtonDefaultCopyInfoKey = @"action_button_profile_default_copy_info_action";
static NSString * const kSCIProfileActionNone = @"none";
static NSString * const kSCIProfileActionCopyInfo = @"copy_info";
static NSString * const kSCIProfileActionViewPicture = @"view_picture";
static NSString * const kSCIProfileActionSharePicture = @"share_picture";
static NSString * const kSCIProfileActionSavePictureToVault = @"save_picture_vault";
static NSString * const kSCIProfileActionOpenSettings = @"profile_settings";
static NSString * const kSCIProfileCopyInfoID = @"id";
static NSString * const kSCIProfileCopyInfoUsername = @"username";
static NSString * const kSCIProfileCopyInfoName = @"name";
static NSString * const kSCIProfileCopyInfoBio = @"bio";
static NSString * const kSCIProfileCopyInfoLink = @"link";
static CGFloat const kSCIProfileActionButtonSide = 44.0;
static CGFloat const kSCIProfileActionIconPointSize = 24.0;
static CGFloat const kSCIProfileActionMenuIconPointSize = 22.0;

static UIImage *SCIProfileMenuIcon(NSString *resourceName, NSString *fallbackSystemName) {
    UIImage *image = resourceName.length > 0
        ? [SCIUtils sci_resourceImageNamed:resourceName template:YES maxPointSize:kSCIProfileActionMenuIconPointSize]
        : nil;
    if (!image && fallbackSystemName.length > 0) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:kSCIProfileActionMenuIconPointSize
                                                                                                     weight:UIImageSymbolWeightRegular];
        image = [UIImage systemImageNamed:fallbackSystemName withConfiguration:configuration];
    }
    return image;
}

static id SCIProfileSafeValue(id target, NSString *key) {
    if (!target || key.length == 0) return nil;
    @try {
        return [target valueForKey:key];
    } @catch (__unused NSException *exception) {
    }
    return nil;
}

static NSString *SCIProfileStringValue(id value) {
    if (!value) return nil;
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value length] > 0 ? value : nil;
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *stringValue = [value stringValue];
        return stringValue.length > 0 ? stringValue : nil;
    }
    return nil;
}

static NSNumber *SCIProfileNumberValue(id value) {
    if (!value) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value respondsToSelector:@selector(integerValue)]) return @([value integerValue]);
    return nil;
}

static id SCIProfileResolvedUserFromObject(id object, NSInteger depth) {
    if (!object || depth > 3) return nil;

    for (NSString *key in @[@"user", @"userGQL", @"profileUser", @"profileController.user", @"profileController.userGQL"]) {
        id value = nil;
        if ([key containsString:@"."]) {
            id current = object;
            for (NSString *part in [key componentsSeparatedByString:@"."]) {
                current = SCIProfileSafeValue(current, part);
                if (!current) break;
            }
            value = current;
        } else {
            value = SCIProfileSafeValue(object, key);
        }
        if (value) return value;
    }

    for (NSString *key in @[@"delegate", @"viewController", @"_viewController", @"nextResponder"]) {
        id nested = SCIProfileSafeValue(object, key);
        if (nested && nested != object) {
            id resolved = SCIProfileResolvedUserFromObject(nested, depth + 1);
            if (resolved) return resolved;
        }
    }

    if ([object isKindOfClass:[UIView class]]) {
        UIViewController *controller = [SCIUtils nearestViewControllerForView:(UIView *)object];
        if (controller && controller != object) {
            id resolved = SCIProfileResolvedUserFromObject(controller, depth + 1);
            if (resolved) return resolved;
        }
    }

    return nil;
}

static NSString *SCIProfileUsername(id user) {
    return SCIProfileStringValue(SCIProfileSafeValue(user, @"username"));
}

static NSString *SCIProfileUserPK(id user) {
    NSString *pk = SCIProfileStringValue(SCIProfileSafeValue(user, @"pk"));
    if (pk.length == 0) pk = SCIProfileStringValue(SCIProfileSafeValue(user, @"id"));
    return pk;
}

static NSString *SCIProfileFullName(id user) {
    NSString *name = SCIProfileStringValue(SCIProfileSafeValue(user, @"fullName"));
    if (name.length == 0) name = SCIProfileStringValue(SCIProfileSafeValue(user, @"full_name"));
    if (name.length == 0) name = SCIProfileStringValue(SCIProfileSafeValue(user, @"name"));
    return name;
}

static NSString *SCIProfileBiography(id user) {
    NSString *bio = SCIProfileStringValue(SCIProfileSafeValue(user, @"biography"));
    if (bio.length == 0) bio = SCIProfileStringValue(SCIProfileSafeValue(user, @"bio"));
    return bio;
}

static NSURL *SCIProfileURL(id user) {
    NSString *username = SCIProfileUsername(user);
    if (username.length == 0) return nil;
    NSString *encoded = [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    if (encoded.length == 0) return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://www.instagram.com/%@/", encoded]];
}

static NSURL *SCIProfilePictureURL(id user) {
    return [SCIUtils getBestProfilePictureURLForUser:user];
}

static NSString *SCIProfilePictureExtension(NSURL *url) {
    NSString *extension = url.pathExtension.lowercaseString;
    return extension.length > 0 ? extension : @"jpg";
}

static NSString *SCIProfileInfoString(NSNumber *value) {
    if (!value) return nil;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [formatter stringFromNumber:value];
}

static NSString *SCIProfileResolvedDefaultActionIdentifier(void) {
    NSString *identifier = [SCIUtils getStringPref:kSCIProfileActionButtonDefaultKey] ?: kSCIProfileActionNone;
    NSSet<NSString *> *supported = [NSSet setWithArray:@[
        kSCIProfileActionNone,
        kSCIProfileActionCopyInfo,
        kSCIProfileActionViewPicture,
        kSCIProfileActionSharePicture,
        kSCIProfileActionSavePictureToVault,
        kSCIProfileActionOpenSettings
    ]];
    return [supported containsObject:identifier] ? identifier : kSCIProfileActionNone;
}

static NSString *SCIProfileResolvedDefaultCopyInfoIdentifier(void) {
    NSString *identifier = [SCIUtils getStringPref:kSCIProfileActionButtonDefaultCopyInfoKey] ?: kSCIProfileCopyInfoUsername;
    NSSet<NSString *> *supported = [NSSet setWithArray:@[
        kSCIProfileCopyInfoID,
        kSCIProfileCopyInfoUsername,
        kSCIProfileCopyInfoName,
        kSCIProfileCopyInfoBio,
        kSCIProfileCopyInfoLink
    ]];
    return [supported containsObject:identifier] ? identifier : kSCIProfileCopyInfoUsername;
}

static NSString *SCIProfilePrivacyText(id user) {
    NSNumber *privacyStatus = SCIProfileNumberValue(SCIProfileSafeValue(user, @"privacyStatus"));
    if (privacyStatus) {
        if (privacyStatus.integerValue == 2) return @"Private Profile";
        if (privacyStatus.integerValue == 1) return @"Public Profile";
    }

    id privateValue = SCIProfileSafeValue(user, @"isPrivate");
    if (!privateValue) privateValue = SCIProfileSafeValue(user, @"privateAccount");
    if (!privateValue) privateValue = SCIProfileSafeValue(user, @"isPrivateAccount");
    if ([privateValue respondsToSelector:@selector(boolValue)]) {
        return [privateValue boolValue] ? @"Private Profile" : @"Public Profile";
    }

    return nil;
}

static void SCIProfileCopyValue(NSString *value, NSString *successTitle) {
    if (value.length == 0) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionProfileCopyInfo duration:2.0 title:@"Nothing to copy" subtitle:nil iconResource:@"error_filled" fallbackSystemImageName:@"exclamationmark.circle.fill" tone:SCIFeedbackPillToneError];
        return;
    }
    UIPasteboard.generalPasteboard.string = value;
    [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionProfileCopyInfo duration:1.6 title:successTitle subtitle:nil iconResource:@"copy_filled" fallbackSystemImageName:@"doc.on.doc.fill" tone:SCIFeedbackPillToneSuccess];
}

static void SCIProfileExecuteCopyInfoAction(id user, NSString *identifier) {
    if ([identifier isEqualToString:kSCIProfileCopyInfoID]) {
        SCIProfileCopyValue(SCIProfileUserPK(user), @"ID copied");
    } else if ([identifier isEqualToString:kSCIProfileCopyInfoName]) {
        SCIProfileCopyValue(SCIProfileFullName(user), @"Name copied");
    } else if ([identifier isEqualToString:kSCIProfileCopyInfoBio]) {
        SCIProfileCopyValue(SCIProfileBiography(user), @"Bio copied");
    } else if ([identifier isEqualToString:kSCIProfileCopyInfoLink]) {
        SCIProfileCopyValue(SCIProfileURL(user).absoluteString, @"Profile link copied");
    } else {
        SCIProfileCopyValue(SCIProfileUsername(user), @"Username copied");
    }
}

static void SCIProfileSharePicture(id user) {
    NSURL *url = SCIProfilePictureURL(user);
    if (!url) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionProfileSharePicture duration:2.0 title:@"Picture not found" subtitle:nil iconResource:@"error_filled" fallbackSystemImageName:@"exclamationmark.circle.fill" tone:SCIFeedbackPillToneError];
        return;
    }
    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:share showProgress:[SCIUtils shouldShowFeedbackPillForActionIdentifier:kSCIFeedbackActionProfileSharePicture]];
    [delegate downloadFileWithURL:url fileExtension:SCIProfilePictureExtension(url) hudLabel:nil];
}

static void SCIProfileSavePictureToVault(id user) {
    NSURL *url = SCIProfilePictureURL(user);
    if (!url) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionProfileVaultPicture duration:2.0 title:@"Picture not found" subtitle:nil iconResource:@"error_filled" fallbackSystemImageName:@"exclamationmark.circle.fill" tone:SCIFeedbackPillToneError];
        return;
    }

    SCIVaultSaveMetadata *metadata = [[SCIVaultSaveMetadata alloc] init];
    metadata.source = (int16_t)SCIVaultSourceProfile;
    [SCIVaultOriginController populateProfileMetadata:metadata username:SCIProfileUsername(user) user:user];

    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:saveToVault showProgress:[SCIUtils shouldShowFeedbackPillForActionIdentifier:kSCIFeedbackActionProfileVaultPicture]];
    delegate.pendingVaultSaveMetadata = metadata;
    [delegate downloadFileWithURL:url fileExtension:SCIProfilePictureExtension(url) hudLabel:nil];
}

@interface SCIProfileHeaderActionButton : UIButton
@property (nonatomic, weak) id sourceObject;
@property (nonatomic, assign) BOOL sciDidConfigure;
@end

static void SCIConfigureProfileActionButton(SCIProfileHeaderActionButton *button);

@implementation SCIProfileHeaderActionButton

- (CGSize)sizeThatFits:(CGSize)size {
    (void)size;
    return CGSizeMake(kSCIProfileActionButtonSide, kSCIProfileActionButtonSide);
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(kSCIProfileActionButtonSide, kSCIProfileActionButtonSide);
}

- (void)setFrame:(CGRect)frame {
    frame.size.width = kSCIProfileActionButtonSide;
    frame.size.height = kSCIProfileActionButtonSide;
    [super setFrame:frame];
}

- (void)setBounds:(CGRect)bounds {
    bounds.size.width = kSCIProfileActionButtonSide;
    bounds.size.height = kSCIProfileActionButtonSide;
    [super setBounds:bounds];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.imageView.contentMode = UIViewContentModeCenter;
    CGRect bounds = self.bounds;
    CGRect imageFrame = CGRectMake(floor((CGRectGetWidth(bounds) - kSCIProfileActionIconPointSize) / 2.0),
                                   floor((CGRectGetHeight(bounds) - kSCIProfileActionIconPointSize) / 2.0),
                                   kSCIProfileActionIconPointSize,
                                   kSCIProfileActionIconPointSize);
    self.imageView.frame = imageFrame;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window && !self.sciDidConfigure) {
        self.sciDidConfigure = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            SCIConfigureProfileActionButton(self);
        });
    }
}

- (void)setSourceObject:(id)sourceObject {
    _sourceObject = sourceObject;
    _sciDidConfigure = NO;
    if (self.window) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SCIConfigureProfileActionButton(self);
        });
    }
}

- (void)setMenu:(UIMenu *)menu {
    [super setMenu:menu];
    self.sciDidConfigure = YES;
}

@end

static UIAction *SCIProfileDisabledInfoAction(NSString *title, NSString *resourceName, NSString *fallbackSystemName) {
    UIAction *action = [UIAction actionWithTitle:title image:SCIProfileMenuIcon(resourceName, fallbackSystemName) identifier:nil handler:^(__unused UIAction *menuAction) {}];
    action.attributes = UIMenuElementAttributesDisabled;
    return action;
}

static UIMenu *SCIProfileCopyInfoMenu(id user) {
    NSMutableArray<UIMenuElement *> *children = [NSMutableArray array];
    [children addObject:[UIAction actionWithTitle:@"Copy ID" image:SCIProfileMenuIcon(@"key", @"key") identifier:nil handler:^(__unused UIAction *action) {
        SCIProfileExecuteCopyInfoAction(user, kSCIProfileCopyInfoID);
    }]];
    [children addObject:[UIAction actionWithTitle:@"Copy Username" image:SCIProfileMenuIcon(@"username", @"person") identifier:nil handler:^(__unused UIAction *action) {
        SCIProfileExecuteCopyInfoAction(user, kSCIProfileCopyInfoUsername);
    }]];
    [children addObject:[UIAction actionWithTitle:@"Copy Name" image:SCIProfileMenuIcon(@"text", @"textformat") identifier:nil handler:^(__unused UIAction *action) {
        SCIProfileExecuteCopyInfoAction(user, kSCIProfileCopyInfoName);
    }]];
    [children addObject:[UIAction actionWithTitle:@"Copy Bio" image:SCIProfileMenuIcon(@"caption", @"captions.bubble") identifier:nil handler:^(__unused UIAction *action) {
        SCIProfileExecuteCopyInfoAction(user, kSCIProfileCopyInfoBio);
    }]];
    [children addObject:[UIAction actionWithTitle:@"Copy Profile Link" image:SCIProfileMenuIcon(@"link", @"link") identifier:nil handler:^(__unused UIAction *action) {
        SCIProfileExecuteCopyInfoAction(user, kSCIProfileCopyInfoLink);
    }]];

    return [UIMenu menuWithTitle:@"Copy Info" image:SCIProfileMenuIcon(@"copy", @"doc.on.doc") identifier:nil options:0 children:children];
}

static UIMenu *SCIProfileActionMenu(id sourceObject) {
    id user = SCIProfileResolvedUserFromObject(sourceObject, 0);
    if (!user) {
        UIAction *empty = [UIAction actionWithTitle:@"Profile unavailable" image:nil identifier:nil handler:^(__unused UIAction *action) {}];
        empty.attributes = UIMenuElementAttributesDisabled;
        return [UIMenu menuWithTitle:@"" children:@[empty]];
    }

    NSMutableArray<UIMenuElement *> *items = [NSMutableArray array];
    [items addObject:SCIProfileCopyInfoMenu(user)];

    [items addObject:[UIAction actionWithTitle:@"View Picture" image:SCIProfileMenuIcon(@"photo", @"photo") identifier:nil handler:^(__unused UIAction *action) {
        NSURL *url = SCIProfilePictureURL(user);
        if (!url) {
            [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionProfileViewPicture duration:2.0 title:@"Picture not found" subtitle:nil iconResource:@"error_filled" fallbackSystemImageName:@"exclamationmark.circle.fill" tone:SCIFeedbackPillToneError];
            return;
        }
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionProfileViewPicture duration:1.4 title:@"Opened profile picture" subtitle:nil iconResource:@"photo" fallbackSystemImageName:@"photo" tone:SCIFeedbackPillToneInfo];
        [SCIFullScreenMediaPlayer showRemoteImageURL:url profileUsername:SCIProfileUsername(user)];
    }]];

    [items addObject:[UIAction actionWithTitle:@"Share Picture" image:SCIProfileMenuIcon(@"share", @"square.and.arrow.up") identifier:nil handler:^(__unused UIAction *action) {
        SCIProfileSharePicture(user);
    }]];

    [items addObject:[UIAction actionWithTitle:@"Download to Vault" image:SCIProfileMenuIcon(@"photo_gallery", @"photo.on.rectangle.angled") identifier:nil handler:^(__unused UIAction *action) {
        SCIProfileSavePictureToVault(user);
    }]];

    [items addObject:[UIAction actionWithTitle:@"Profile Settings" image:SCIProfileMenuIcon(@"settings", @"gear") identifier:nil handler:^(__unused UIAction *action) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionProfileOpenSettings duration:1.4 title:@"Opened profile settings" subtitle:nil iconResource:@"settings" fallbackSystemImageName:@"gearshape" tone:SCIFeedbackPillToneInfo];
        [SCIUtils showSettingsForTopicTitle:@"Profile"];
    }]];

    NSMutableArray<UIMenuElement *> *infoItems = [NSMutableArray array];
    NSString *privacyText = SCIProfilePrivacyText(user);
    if (privacyText.length > 0) {
        [infoItems addObject:SCIProfileDisabledInfoAction(privacyText,
                                                          [privacyText containsString:@"Private"] ? @"lock" : @"unlock",
                                                          [privacyText containsString:@"Private"] ? @"lock" : @"lock.open")];
    }

    NSString *followers = SCIProfileInfoString(SCIProfileNumberValue(SCIProfileSafeValue(user, @"followerCount")));
    if (followers.length > 0) {
        [infoItems addObject:SCIProfileDisabledInfoAction([NSString stringWithFormat:@"Followers: %@", followers], @"users", @"person.2")];
    }

    NSString *following = SCIProfileInfoString(SCIProfileNumberValue(SCIProfileSafeValue(user, @"followingCount")));
    if (following.length > 0) {
        [infoItems addObject:SCIProfileDisabledInfoAction([NSString stringWithFormat:@"Following: %@", following], @"users", @"person.2")];
    }

    if (infoItems.count > 0) {
        [items addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:infoItems]];
    }

    return [UIMenu menuWithTitle:@"" children:items];
}

static void SCIExecuteProfileDefaultAction(SCIProfileHeaderActionButton *button) {
    id user = SCIProfileResolvedUserFromObject(button.sourceObject ?: button, 0);
    if (!user) return;

    NSString *identifier = SCIProfileResolvedDefaultActionIdentifier();
    if ([identifier isEqualToString:kSCIProfileActionCopyInfo]) {
        SCIProfileExecuteCopyInfoAction(user, SCIProfileResolvedDefaultCopyInfoIdentifier());
    } else if ([identifier isEqualToString:kSCIProfileActionViewPicture]) {
        NSURL *url = SCIProfilePictureURL(user);
        if (url) {
            [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionProfileViewPicture duration:1.4 title:@"Opened profile picture" subtitle:nil iconResource:@"photo" fallbackSystemImageName:@"photo" tone:SCIFeedbackPillToneInfo];
            [SCIFullScreenMediaPlayer showRemoteImageURL:url profileUsername:SCIProfileUsername(user)];
        }
    } else if ([identifier isEqualToString:kSCIProfileActionSharePicture]) {
        SCIProfileSharePicture(user);
    } else if ([identifier isEqualToString:kSCIProfileActionSavePictureToVault]) {
        SCIProfileSavePictureToVault(user);
    } else if ([identifier isEqualToString:kSCIProfileActionOpenSettings]) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionProfileOpenSettings duration:1.4 title:@"Opened profile settings" subtitle:nil iconResource:@"settings" fallbackSystemImageName:@"gearshape" tone:SCIFeedbackPillToneInfo];
        [SCIUtils showSettingsForTopicTitle:@"Profile"];
    }
}

static void SCIProfileDefaultTapHandler(id target, SEL _cmd) {
    SCIExecuteProfileDefaultAction((SCIProfileHeaderActionButton *)target);
}

static UIImage *SCIProfileButtonIconForDefaultAction(NSString *defaultIdentifier) {
    NSString *resourceName = @"action";
    NSString *fallbackName = @"gearshape";

    if ([defaultIdentifier isEqualToString:kSCIProfileActionCopyInfo]) {
        resourceName = @"copy";
        fallbackName = @"doc.on.doc";
    } else if ([defaultIdentifier isEqualToString:kSCIProfileActionViewPicture]) {
        resourceName = @"photo";
        fallbackName = @"photo";
    } else if ([defaultIdentifier isEqualToString:kSCIProfileActionSharePicture]) {
        resourceName = @"share";
        fallbackName = @"square.and.arrow.up";
    } else if ([defaultIdentifier isEqualToString:kSCIProfileActionSavePictureToVault]) {
        resourceName = @"photo_gallery";
        fallbackName = @"photo.on.rectangle.angled";
    } else if ([defaultIdentifier isEqualToString:kSCIProfileActionOpenSettings]) {
        resourceName = @"settings";
        fallbackName = @"gearshape";
    }

    UIImage *image = [SCIUtils sci_resourceImageNamed:resourceName template:YES maxPointSize:kSCIProfileActionIconPointSize];
    if (!image) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:kSCIProfileActionIconPointSize weight:UIImageSymbolWeightRegular];
        image = [UIImage systemImageNamed:fallbackName withConfiguration:configuration];
    }
    return image;
}

static void SCIConfigureProfileActionButton(SCIProfileHeaderActionButton *button) {
    if (!button) return;

    id user = SCIProfileResolvedUserFromObject(button.sourceObject ?: button, 0);
    if (!user) {
        button.hidden = YES;
        return;
    }

    button.hidden = NO;
    NSString *defaultIdentifier = SCIProfileResolvedDefaultActionIdentifier();
    UIImage *image = SCIProfileButtonIconForDefaultAction(defaultIdentifier);
    [button setImage:image forState:UIControlStateNormal];
    button.menu = SCIProfileActionMenu(button.sourceObject ?: button);

    button.showsMenuAsPrimaryAction = [defaultIdentifier isEqualToString:kSCIProfileActionNone];
    [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    if (!button.showsMenuAsPrimaryAction) {
        [button addTarget:button action:@selector(_sci_profileButtonTap) forControlEvents:UIControlEventTouchUpInside];
    }
}

@implementation SCIProfileHeaderActionButton (TapAction)
- (void)_sci_profileButtonTap {
    SCIExecuteProfileDefaultAction(self);
}
@end

static id SCIProfileNavigationButtonWrapperForView(UIView *view, id sampleWrapper) {
    Class wrapperClass = NSClassFromString(@"IGProfileNavigationHeaderViewButtonSwift.IGProfileNavigationHeaderViewButton");
    if (!wrapperClass || !view) return nil;

    NSInteger type = 0;
    id typeValue = SCIProfileSafeValue(sampleWrapper, @"type");
    if ([typeValue respondsToSelector:@selector(integerValue)]) {
        type = [typeValue integerValue];
    }

    id wrapper = [wrapperClass alloc];
    SEL initSelector = @selector(initWithType:view:);
    if (![wrapper respondsToSelector:initSelector]) return nil;
    return ((id (*)(id, SEL, NSInteger, id))objc_msgSend)(wrapper, initSelector, type, view);
}

static BOOL SCIProfileButtonsContainSCInstaButton(NSArray *buttons) {
    for (id wrapper in buttons) {
        UIView *view = SCIProfileSafeValue(wrapper, @"view");
        if ([view.accessibilityIdentifier isEqualToString:@"scinsta-profile-action-button"]) {
            return YES;
        }
    }
    return NO;
}

static void (*orig_profileHeaderConfigure)(id, SEL, id, id, id, BOOL);

static NSArray *SCIProfilePatchedRightButtons(id self, NSArray *leftButtons, NSArray *rightButtons) {
    if (![SCIUtils getBoolPref:@"action_button_profile_enabled"]) return rightButtons;
    if (SCIProfileButtonsContainSCInstaButton(rightButtons)) return rightButtons;
    if (SCIProfileResolvedUserFromObject(self, 0) == nil) return rightButtons;

    SCIProfileHeaderActionButton *button = [SCIProfileHeaderActionButton buttonWithType:UIButtonTypeSystem];
    button.accessibilityIdentifier = @"scinsta-profile-action-button";
    button.translatesAutoresizingMaskIntoConstraints = YES;
    button.frame = CGRectMake(0.0, 0.0, kSCIProfileActionButtonSide, kSCIProfileActionButtonSide);
    button.bounds = CGRectMake(0.0, 0.0, kSCIProfileActionButtonSide, kSCIProfileActionButtonSide);
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    button.contentEdgeInsets = UIEdgeInsetsZero;
    button.imageEdgeInsets = UIEdgeInsetsZero;
    button.tintColor = [UIColor labelColor];
    button.sourceObject = self;

    id sample = rightButtons.firstObject ?: leftButtons.firstObject;
    id wrapper = SCIProfileNavigationButtonWrapperForView(button, sample);
    if (!wrapper) return rightButtons;

    NSMutableArray *patched = rightButtons ? [rightButtons mutableCopy] : [NSMutableArray array];
    [patched insertObject:wrapper atIndex:0];
    return patched;
}

static void hooked_configureProfileHeaderView(id self, SEL _cmd, id titleView, id leftButtons, id rightButtons, BOOL titleIsCentered) {
    if (titleIsCentered) {
        orig_profileHeaderConfigure(self, _cmd, titleView, leftButtons, rightButtons, titleIsCentered);
        return;
    }

    NSArray *leftArray = [leftButtons isKindOfClass:[NSArray class]] ? (NSArray *)leftButtons : @[];
    NSArray *rightArray = [rightButtons isKindOfClass:[NSArray class]] ? (NSArray *)rightButtons : @[];
    NSArray *patchedRight = SCIProfilePatchedRightButtons(self, leftArray, rightArray);
    orig_profileHeaderConfigure(self, _cmd, titleView, leftButtons, patchedRight, titleIsCentered);
}

%ctor {
    Class headerClass = objc_getClass("IGProfileNavigationSwift.IGProfileNavigationHeaderView");
    if (!headerClass) headerClass = objc_getClass("IGProfileNavigationHeaderView");
    if (!headerClass) return;

    SEL selector = @selector(configureWithTitleView:leftButtons:rightButtons:titleIsCentered:);
    if (![headerClass instancesRespondToSelector:selector]) return;
    MSHookMessageEx(headerClass, selector, (IMP)hooked_configureProfileHeaderView, (IMP *)&orig_profileHeaderConfigure);
}
