#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIIGAlertActionStyle) {
    SCIIGAlertActionStyleDefault = 0,
    SCIIGAlertActionStyleCancel = 1,
    SCIIGAlertActionStyleDestructive = 2,
};

typedef void (^SCIIGAlertActionHandler)(void);
typedef void (^SCIIGAlertTextHandler)(NSString * _Nullable text);

@interface SCIIGAlertAction : NSObject

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, assign, readonly) SCIIGAlertActionStyle style;
@property (nonatomic, copy, nullable, readonly) SCIIGAlertActionHandler handler;

+ (instancetype)actionWithTitle:(NSString *)title
                          style:(SCIIGAlertActionStyle)style
                        handler:(nullable SCIIGAlertActionHandler)handler;

@end

@interface SCIIGAlertPresenter : NSObject

+ (BOOL)presentAlertFromViewController:(nullable UIViewController *)presenter
                                 title:(nullable NSString *)title
                               message:(nullable NSString *)message
                               actions:(NSArray<SCIIGAlertAction *> *)actions;

+ (BOOL)presentActionSheetFromViewController:(nullable UIViewController *)presenter
                                       title:(nullable NSString *)title
                                     message:(nullable NSString *)message
                                     actions:(NSArray<SCIIGAlertAction *> *)actions;

+ (BOOL)presentTextInputAlertFromViewController:(nullable UIViewController *)presenter
                                          title:(nullable NSString *)title
                                        message:(nullable NSString *)message
                                    placeholder:(nullable NSString *)placeholder
                                    initialText:(nullable NSString *)initialText
                               autocapitalized:(BOOL)autocapitalized
                                  confirmTitle:(NSString *)confirmTitle
                                   cancelTitle:(NSString *)cancelTitle
                                  confirmStyle:(SCIIGAlertActionStyle)confirmStyle
                                  confirmBlock:(SCIIGAlertTextHandler)confirmBlock
                                   cancelBlock:(nullable SCIIGAlertActionHandler)cancelBlock;

@end

NS_ASSUME_NONNULL_END
