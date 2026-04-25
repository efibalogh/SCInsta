#import "SCIMediaVaultSettingsProvider.h"

#import "../SCITopicSettingsSupport.h"
#import "../../Shared/Vault/SCIVaultSettingsViewController.h"
#import "../../Shared/Vault/SCIVaultViewController.h"

@implementation SCIMediaVaultSettingsProvider

+ (SCISetting *)rootSetting {
    return SCITopicNavigationSetting(@"Media Vault", @"media", 24.0, @[
        SCITopicSection(@"Access", @[
            [SCISetting buttonCellWithTitle:@"Open Media Vault" subtitle:@"Open the saved media vault" icon:[SCISymbol resourceSymbolWithName:@"media" color:[UIColor labelColor] size:24.0] action:^(void) {
                [SCIVaultViewController presentVault];
            }],
            [SCISetting navigationCellWithTitle:@"Vault Settings" subtitle:@"Manage storage stats, lock settings, shortcuts, and delete tools" icon:[SCISymbol resourceSymbolWithName:@"settings" color:[UIColor labelColor] size:24.0] viewController:[[SCIVaultSettingsViewController alloc] init]]
        ], nil)
    ]);
}

@end
