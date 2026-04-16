#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIVaultSortMode) {
    SCIVaultSortModeDateAddedDesc = 0,  // Newest first (default)
    SCIVaultSortModeDateAddedAsc,       // Oldest first
    SCIVaultSortModeNameAsc,            // A→Z
    SCIVaultSortModeNameDesc,           // Z→A
    SCIVaultSortModeSizeDesc,           // Largest first
    SCIVaultSortModeSizeAsc,            // Smallest first
    SCIVaultSortModeTypeAsc,            // Images then videos
    SCIVaultSortModeTypeDesc,           // Videos then images
};

@class SCIVaultSortViewController;

@protocol SCIVaultSortViewControllerDelegate <NSObject>
- (void)sortController:(SCIVaultSortViewController *)controller didSelectSortMode:(SCIVaultSortMode)mode;
@end

@interface SCIVaultSortViewController : UIViewController

@property (nonatomic, weak) id<SCIVaultSortViewControllerDelegate> delegate;
@property (nonatomic, assign) SCIVaultSortMode currentSortMode;

+ (NSArray<NSSortDescriptor *> *)sortDescriptorsForMode:(SCIVaultSortMode)mode;
+ (NSString *)labelForMode:(SCIVaultSortMode)mode;

@end

NS_ASSUME_NONNULL_END
