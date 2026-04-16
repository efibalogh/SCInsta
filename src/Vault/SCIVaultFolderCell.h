#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIVaultFolderCell : UICollectionViewCell

/// `listStyle` uses the same row rhythm as file list rows; grid matches vault grid tiles.
- (void)configureWithFolderName:(NSString *)name listStyle:(BOOL)listStyle;

@end

NS_ASSUME_NONNULL_END
