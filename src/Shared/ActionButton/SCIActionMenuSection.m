#import "SCIActionMenuSection.h"

@implementation SCIActionMenuSection

+ (instancetype)sectionWithIdentifier:(NSString *)identifier
                                title:(NSString *)title
                             iconName:(NSString *)iconName
                          collapsible:(BOOL)collapsible
                              actions:(NSArray<NSString *> *)actions
{
    SCIActionMenuSection *section = [[self alloc] init];
    section.identifier = identifier;
    section.title = title;
    section.iconName = iconName;
    section.collapsible = collapsible;
    section.actions = [actions mutableCopy] ?: [NSMutableArray array];
    return section;
}

+ (nullable instancetype)sectionFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;

    NSString *identifier = [dictionary[@"identifier"] isKindOfClass:[NSString class]] ? dictionary[@"identifier"] : NSUUID.UUID.UUIDString;
    NSString *title = [dictionary[@"title"] isKindOfClass:[NSString class]] ? dictionary[@"title"] : @"Section";
    NSString *iconName = [dictionary[@"icon_name"] isKindOfClass:[NSString class]] ? dictionary[@"icon_name"] : @"action";
    NSString *type = [dictionary[@"type"] isKindOfClass:[NSString class]] ? dictionary[@"type"] : @"collapsible";
    NSArray *actions = [dictionary[@"actions"] isKindOfClass:[NSArray class]] ? dictionary[@"actions"] : @[];
    return [self sectionWithIdentifier:identifier
                                 title:title
                              iconName:iconName
                           collapsible:![type isEqualToString:@"inline"]
                               actions:actions];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"identifier": self.identifier ?: NSUUID.UUID.UUIDString,
        @"title": self.title ?: @"Section",
        @"icon_name": self.iconName ?: @"action",
        @"type": self.collapsible ? @"collapsible" : @"inline",
        @"actions": [self.actions copy] ?: @[]
    };
}

- (id)copyWithZone:(NSZone *)zone {
    return [SCIActionMenuSection sectionWithIdentifier:self.identifier
                                                 title:self.title
                                              iconName:self.iconName
                                           collapsible:self.collapsible
                                               actions:self.actions];
}

@end
