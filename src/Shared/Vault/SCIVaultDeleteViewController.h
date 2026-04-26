#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIVaultDeletePageMode) {
    SCIVaultDeletePageModeRoot = 0,
    SCIVaultDeletePageModeUsers
};

@interface SCIVaultDeleteViewController : UITableViewController

@property (nonatomic, copy, nullable) void (^onDidDelete)(void);

- (instancetype)initWithMode:(SCIVaultDeletePageMode)mode;

@end

NS_ASSUME_NONNULL_END
