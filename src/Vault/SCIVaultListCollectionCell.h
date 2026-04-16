#import <UIKit/UIKit.h>

@class SCIVaultFile;

NS_ASSUME_NONNULL_BEGIN

/// List-style row for use inside a collection view (do not use UITableViewCell here).
@interface SCIVaultListCollectionCell : UICollectionViewCell

- (void)configureWithVaultFile:(SCIVaultFile *)file;

@end

NS_ASSUME_NONNULL_END
