#pragma once

#import <Foundation/Foundation.h>
#import "ActionButtonCore.h"
#import "SCIActionMenuSection.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIActionButtonConfiguration : NSObject

@property (nonatomic) SCIActionButtonSource source;
@property (nonatomic, copy) NSString *topicTitle;
@property (nonatomic, copy) NSArray<NSString *> *supportedActions;
@property (nonatomic, strong) NSMutableArray<SCIActionMenuSection *> *sections;
@property (nonatomic, strong) NSMutableArray<NSString *> *disabledActions;
@property (nonatomic, strong) NSMutableArray<NSString *> *unassignedActions;

+ (instancetype)configurationForSource:(SCIActionButtonSource)source
                            topicTitle:(NSString *)topicTitle
                      supportedActions:(NSArray<NSString *> *)supportedActions
                       defaultSections:(NSArray<SCIActionMenuSection *> *)defaultSections;

- (NSString *)configDefaultsKey;
- (NSDictionary *)dictionaryRepresentation;
- (void)save;
- (void)normalize;
- (nullable SCIActionMenuSection *)sectionWithIdentifier:(NSString *)identifier;
- (NSArray<SCIActionMenuSection *> *)visibleSections;
- (NSArray<NSString *> *)assignedActions;
- (nullable NSString *)sectionIdentifierForAction:(NSString *)identifier;
- (void)setAction:(NSString *)identifier assignedToSectionIdentifier:(nullable NSString *)sectionIdentifier;
- (void)moveSectionFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex;
- (void)moveActionInSectionIdentifier:(NSString *)sectionIdentifier fromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex;

@end

FOUNDATION_EXPORT NSString *SCIActionButtonTopicKeyForSource(SCIActionButtonSource source);
FOUNDATION_EXPORT NSString *SCIActionButtonTopicTitleForSource(SCIActionButtonSource source);
FOUNDATION_EXPORT NSArray<NSString *> *SCIActionButtonSupportedActionsForSource(SCIActionButtonSource source);
FOUNDATION_EXPORT NSArray<SCIActionMenuSection *> *SCIActionButtonDefaultSectionsForSource(SCIActionButtonSource source);
FOUNDATION_EXPORT NSArray<NSString *> *SCIActionButtonBulkDownloadSupportedActionsForSource(SCIActionButtonSource source);
FOUNDATION_EXPORT NSArray<NSString *> *SCIActionButtonBulkCopySupportedActionsForSource(SCIActionButtonSource source);
FOUNDATION_EXPORT NSArray<NSString *> *SCIActionButtonConfiguredBulkDownloadActionsForSource(SCIActionButtonSource source);
FOUNDATION_EXPORT NSArray<NSString *> *SCIActionButtonConfiguredBulkCopyActionsForSource(SCIActionButtonSource source);
FOUNDATION_EXPORT void SCIActionButtonSetConfiguredBulkDownloadActionsForSource(SCIActionButtonSource source, NSArray<NSString *> *actions);
FOUNDATION_EXPORT void SCIActionButtonSetConfiguredBulkCopyActionsForSource(SCIActionButtonSource source, NSArray<NSString *> *actions);

NS_ASSUME_NONNULL_END
