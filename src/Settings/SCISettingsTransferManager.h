#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCISettingsTransferManager : NSObject

+ (instancetype)sharedManager;
- (void)exportSettingsAndVaultFromController:(UIViewController *)controller;
- (void)importSettingsAndVaultFromController:(UIViewController *)controller;

@end

NS_ASSUME_NONNULL_END
