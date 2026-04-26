#pragma once

#import <UIKit/UIKit.h>
#import "../Shared/ActionButton/SCIActionButtonConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIActionSectionEditViewController : UIViewController

- (instancetype)initWithConfiguration:(SCIActionButtonConfiguration *)configuration
                    sectionIdentifier:(NSString *)sectionIdentifier
                             onChange:(dispatch_block_t)onChange;

@end

NS_ASSUME_NONNULL_END
