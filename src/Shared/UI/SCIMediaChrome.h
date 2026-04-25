#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT CGFloat const SCIMediaChromeTopBarContentHeight;
FOUNDATION_EXPORT CGFloat const SCIMediaChromeBottomBarHeight;

UIBlurEffect *SCIMediaChromeBlurEffect(void);
void SCIApplyMediaChromeNavigationBar(UINavigationBar *bar);

UILabel *SCIMediaChromeTitleLabel(NSString *text);
UIImage *SCIMediaChromeTopIcon(NSString *resourceName, NSString *systemName);
UIImage *SCIMediaChromeBottomIcon(NSString *resourceName, NSString *systemName);
UIBarButtonItem *SCIMediaChromeTopBarButtonItem(NSString *resourceName, NSString *systemName, id target, SEL action);

UIView *SCIMediaChromeInstallBottomBar(UIView *hostView);
UIButton *SCIMediaChromeBottomButton(NSString *symbolName, NSString *resourceName, NSString *accessibilityLabel);
UIStackView *SCIMediaChromeInstallBottomRow(UIView *bottomBar, NSArray<UIView *> *row);

NS_ASSUME_NONNULL_END
