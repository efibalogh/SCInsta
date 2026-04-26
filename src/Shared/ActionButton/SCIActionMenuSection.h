#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIActionMenuSection : NSObject <NSCopying>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic) BOOL collapsible;
@property (nonatomic, strong) NSMutableArray<NSString *> *actions;

+ (instancetype)sectionWithIdentifier:(NSString *)identifier
                                title:(NSString *)title
                             iconName:(NSString *)iconName
                          collapsible:(BOOL)collapsible
                              actions:(NSArray<NSString *> *)actions;

+ (nullable instancetype)sectionFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
