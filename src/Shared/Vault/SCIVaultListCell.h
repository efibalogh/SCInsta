#import <UIKit/UIKit.h>

@class SCIVaultFile;

NS_ASSUME_NONNULL_BEGIN

@interface SCIVaultListCell : UITableViewCell

@property (nonatomic, strong, readonly) SCIVaultFile *file;

- (void)configureWithVaultFile:(SCIVaultFile *)file;

@end

NS_ASSUME_NONNULL_END
