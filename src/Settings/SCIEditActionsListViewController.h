#pragma once

#import <UIKit/UIKit.h>
#import "../Shared/ActionButton/SCIActionButtonConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIEditActionsListViewController : UIViewController

- (instancetype)initWithSource:(SCIActionButtonSource)source topicTitle:(NSString *)topicTitle;

@end

NS_ASSUME_NONNULL_END
