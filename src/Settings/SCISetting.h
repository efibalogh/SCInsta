#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCITableCell) {
        SCITableCellStatic,
        SCITableCellLink,
        SCITableCellSwitch,
        SCITableCellStepper,
        SCITableCellButton,
        SCITableCellMenu,
        SCITableCellNavigation,
};

///

@interface SCISetting : NSObject

@property (nonatomic, readonly) SCITableCell type;

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;

@property (nonatomic, strong, nullable) UIImage *icon;
@property (nonatomic, strong, nullable) UIColor *iconTintColor;
@property (nonatomic, strong) NSString *defaultsKey;

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURL *imageUrl;

@property (nonatomic) BOOL requiresRestart;

/// When this switch is turned on, the bool at this key is forced off (and the table reloads). Used for prefs that share one gesture.
@property (nonatomic, copy, nullable) NSString *mutuallyExclusiveDefaultsKey;

@property (nonatomic) double min;
@property (nonatomic) double max;
@property (nonatomic) double step;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *singularLabel;

@property (nonatomic, copy) void (^action)(void);

@property (nonatomic, strong) UIMenu *baseMenu;
@property (nonatomic, strong, nullable) NSDictionary *userInfo;

@property (nonatomic, strong) NSArray *navSections;
@property (nonatomic, strong) UIViewController *navViewController;

+ (instancetype)staticCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                               icon:(nullable UIImage *)icon;

+ (instancetype)linkCellWithTitle:(NSString *)title
                         subtitle:(NSString *)subtitle
                             icon:(nullable UIImage *)icon
                              url:(NSString *)url;

+ (instancetype)linkCellWithTitle:(NSString *)title
                         subtitle:(NSString *)subtitle
                         imageUrl:(NSString *)imageUrl
                              url:(NSString *)url;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                        defaultsKey:(NSString *)defaultsKey;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                               icon:(nullable UIImage *)icon
                        defaultsKey:(NSString *)defaultsKey;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                        defaultsKey:(NSString *)defaultsKey
                    requiresRestart:(BOOL)requiresRestart;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                        defaultsKey:(NSString *)defaultsKey
                    requiresRestart:(BOOL)requiresRestart
         mutuallyExclusiveDefaultsKey:(nullable NSString *)exclusiveDefaultsKey;

+ (instancetype)stepperCellWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                         defaultsKey:(NSString *)defaultsKey
                                 min:(double)min
                                 max:(double)max
                                step:(double)step
                               label:(NSString *)label
                       singularLabel:(NSString *)singularLabel;

+ (instancetype)buttonCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                               icon:(nullable UIImage *)icon
                             action:(void (^)(void))action;

+ (instancetype)menuCellWithTitle:(NSString *)title
                         subtitle:(NSString *)subtitle
                             menu:(UIMenu *)menu;

+ (instancetype)navigationCellWithTitle:(NSString *)title
                               subtitle:(NSString *)subtitle
                                   icon:(nullable UIImage *)icon
                            navSections:(NSArray *)navSections;

+ (instancetype)navigationCellWithTitle:(NSString *)title
                               subtitle:(NSString *)subtitle
                                   icon:(nullable UIImage *)icon
                         viewController:(UIViewController *)viewController;


# pragma mark - Instance methods

- (UIMenu *)menuForButton:(UIButton *)button;

@end

NS_ASSUME_NONNULL_END
