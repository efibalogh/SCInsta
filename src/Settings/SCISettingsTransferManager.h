#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCISettingsTransferManager : NSObject

+ (instancetype)sharedManager;
- (void)exportSettingsAndVaultFromController:(UIViewController *)controller;
- (void)importSettingsAndVaultFromController:(UIViewController *)controller;
- (void)presentExportOptionsFromController:(UIViewController *)controller;
- (void)presentImportOptionsFromController:(UIViewController *)controller;
- (void)exportFromController:(UIViewController *)controller includeSettings:(BOOL)includeSettings includeVault:(BOOL)includeVault;
- (void)importFromController:(UIViewController *)controller includeSettings:(BOOL)includeSettings includeVault:(BOOL)includeVault;

@end

NS_ASSUME_NONNULL_END
