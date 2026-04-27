#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIActionDescriptor : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;

+ (instancetype)descriptorWithIdentifier:(NSString *)identifier
                                   title:(NSString *)title
                                iconName:(NSString *)iconName;

+ (nullable instancetype)descriptorForIdentifier:(NSString *)identifier;
+ (NSArray<SCIActionDescriptor *> *)availableSectionIconDescriptors;
+ (NSArray<SCIActionDescriptor *> *)feedbackPillConfigurableDescriptors;

@end

FOUNDATION_EXPORT NSString *SCIActionDescriptorDisplayTitle(NSString *identifier, NSString * _Nullable topicTitle);
FOUNDATION_EXPORT NSString *SCIActionDescriptorIconName(NSString *identifier);
FOUNDATION_EXPORT NSString *SCIActionDescriptorFeedbackPillDefaultsKey(NSString *identifier);

NS_ASSUME_NONNULL_END
