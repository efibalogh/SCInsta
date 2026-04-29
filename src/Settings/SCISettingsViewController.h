#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "TweakSettings.h"
#import "SCISetting.h"
#import "../Utils.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCISettingsViewController : UIViewController

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray *)sections reduceMargin:(BOOL)reduceMargin;
- (instancetype)init;

@property (nonatomic, assign) BOOL searchesAllSettings;

@end

NS_ASSUME_NONNULL_END
