#import "SCIMediaVaultSettingsProvider.h"

#import "../SCISetting.h"
#import "../../Shared/Vault/SCIVaultViewController.h"

@implementation SCIMediaVaultSettingsProvider

+ (SCISetting *)rootSetting {
    return [SCISetting buttonCellWithTitle:@"Media Vault"
                                  subtitle:@""
                                      icon:[SCISymbol resourceSymbolWithName:@"photo_gallery" color:[UIColor labelColor] size:24.0]
                                    action:^(void) {
        [SCIVaultViewController presentVault];
    }];
}

@end
