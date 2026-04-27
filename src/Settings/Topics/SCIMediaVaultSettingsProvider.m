#import "SCIMediaVaultSettingsProvider.h"
#import "../../Utils.h"

#import "../SCISetting.h"
#import "../SCITopicSettingsSupport.h"
#import "../../Shared/Vault/SCIVaultViewController.h"

@implementation SCIMediaVaultSettingsProvider

+ (SCISetting *)rootSetting {
    return [SCISetting buttonCellWithTitle:@"Media Vault"
                                  subtitle:@""
                                      icon:SCISettingsInstagramIcon(@"photo_gallery", 24.0)
                                    action:^(void) {
        [SCIVaultViewController presentVault];
    }];
}

@end
