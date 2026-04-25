#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIVaultViewController : UIViewController

+ (void)presentVault;

/// Initializes the vault for browsing the given folder path. Pass nil for root.
- (instancetype)initWithFolderPath:(nullable NSString *)folderPath;

@end

NS_ASSUME_NONNULL_END
