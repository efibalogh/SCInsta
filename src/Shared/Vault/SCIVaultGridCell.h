#import <UIKit/UIKit.h>

@class SCIVaultFile;

NS_ASSUME_NONNULL_BEGIN

@interface SCIVaultGridCell : UICollectionViewCell

- (void)configureWithVaultFile:(SCIVaultFile *)file;

@end

NS_ASSUME_NONNULL_END
