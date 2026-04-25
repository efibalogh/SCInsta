#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIVaultFolderCell : UICollectionViewCell

/// Folders are list-only; this matches the vault list row rhythm.
- (void)configureWithFolderName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
