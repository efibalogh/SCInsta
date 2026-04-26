#pragma once

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIActionSectionIconPickerViewController : UIViewController

- (instancetype)initWithSelectedIconName:(NSString *)selectedIconName
                                onSelect:(void (^)(NSString *iconName))onSelect;

@end

NS_ASSUME_NONNULL_END
