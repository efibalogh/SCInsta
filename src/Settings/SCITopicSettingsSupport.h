#import <UIKit/UIKit.h>

#import "SCISetting.h"
#import "SCISymbol.h"
#import "../Shared/ActionButton/ActionButtonCore.h"
#import "../Shared/ActionButton/SCIActionMenuSection.h"

NS_ASSUME_NONNULL_BEGIN

NSDictionary *SCITopicSection(NSString *header, NSArray *rows, NSString * _Nullable footer);
SCISetting *SCITopicNavigationSetting(NSString *title, NSString *iconName, CGFloat iconSize, NSArray *sections);
UIMenu *SCIActionButtonDefaultActionMenu(NSString *defaultsKey, NSString *topicTitle, NSArray<NSString *> *supportedActions);
SCISetting *SCIActionButtonConfigurationNavigationSetting(SCIActionButtonSource source, NSString *topicTitle, NSArray<NSString *> *supportedActions, NSArray<SCIActionMenuSection *> *defaultSections);
UIMenu *SCIReelsTapControlMenu(void);
UIMenu *SCINavigationIconOrderingMenu(void);
UIMenu *SCISwipeBetweenTabsMenu(void);
UIMenu *SCIFeedbackPillStyleMenu(void);
NSArray *SCIDevExampleSections(void);

NS_ASSUME_NONNULL_END
