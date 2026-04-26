#import <UIKit/UIKit.h>

@class SCIVaultFile;

NS_ASSUME_NONNULL_BEGIN

@interface SCIVaultGridCell : UICollectionViewCell

- (void)configureWithVaultFile:(SCIVaultFile *)file
                 selectionMode:(BOOL)selectionMode
                      selected:(BOOL)selected;

- (void)setSelectionMode:(BOOL)selectionMode selected:(BOOL)selected animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
