#import <UIKit/UIKit.h>

#import "SCISetting.h"
#import "SCISymbol.h"

NS_ASSUME_NONNULL_BEGIN

NSDictionary *SCITopicSection(NSString *header, NSArray *rows, NSString * _Nullable footer);
SCISetting *SCITopicNavigationSetting(NSString *title, NSString *iconName, CGFloat iconSize, NSArray *sections);
UIMenu *SCIActionButtonDefaultActionMenu(NSString *defaultsKey);
UIMenu *SCIReelsTapControlMenu(void);
UIMenu *SCINavigationIconOrderingMenu(void);
UIMenu *SCISwipeBetweenTabsMenu(void);
UIMenu *SCIFeedbackPillStyleMenu(void);
NSArray *SCIDevExampleSections(void);

NS_ASSUME_NONNULL_END
