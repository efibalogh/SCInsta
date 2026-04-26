#import "SCIActionButtonConfiguration.h"
#import "SCIActionDescriptor.h"

static NSArray<NSString *> *SCIFilteredActionArray(NSArray *values, NSArray<NSString *> *supported) {
    NSMutableOrderedSet<NSString *> *filtered = [NSMutableOrderedSet orderedSet];
    for (id value in values) {
        if ([value isKindOfClass:[NSString class]] && [supported containsObject:value]) {
            [filtered addObject:value];
        }
    }
    return filtered.array;
}

NSString *SCIActionButtonTopicKeyForSource(SCIActionButtonSource source) {
    switch (source) {
        case SCIActionButtonSourceFeed: return @"feed";
        case SCIActionButtonSourceReels: return @"reels";
        case SCIActionButtonSourceStories: return @"stories";
        case SCIActionButtonSourceDirect: return @"messages";
        case SCIActionButtonSourceProfile: return @"profile";
    }
}

NSString *SCIActionButtonTopicTitleForSource(SCIActionButtonSource source) {
    switch (source) {
        case SCIActionButtonSourceFeed: return @"Feed";
        case SCIActionButtonSourceReels: return @"Reels";
        case SCIActionButtonSourceStories: return @"Stories";
        case SCIActionButtonSourceDirect: return @"Messages";
        case SCIActionButtonSourceProfile: return @"Profile";
    }
}

NSArray<NSString *> *SCIActionButtonSupportedActionsForSource(SCIActionButtonSource source) {
    switch (source) {
        case SCIActionButtonSourceFeed:
        case SCIActionButtonSourceReels:
            return @[
                kSCIActionDownloadLibrary,
                kSCIActionDownloadShare,
                kSCIActionCopyDownloadLink,
                kSCIActionDownloadVault,
                kSCIActionExpand,
                kSCIActionViewThumbnail,
                kSCIActionCopyCaption,
                kSCIActionOpenTopicSettings,
                kSCIActionRepost
            ];
        case SCIActionButtonSourceStories:
        case SCIActionButtonSourceDirect:
            return @[
                kSCIActionDownloadLibrary,
                kSCIActionDownloadShare,
                kSCIActionCopyDownloadLink,
                kSCIActionDownloadVault,
                kSCIActionExpand,
                kSCIActionViewThumbnail,
                kSCIActionOpenTopicSettings
            ];
        case SCIActionButtonSourceProfile:
            return @[
                kSCIActionDownloadLibrary,
                kSCIActionDownloadShare,
                kSCIActionCopyDownloadLink,
                kSCIActionDownloadVault,
                kSCIActionExpand,
                kSCIActionOpenTopicSettings
            ];
    }
}

NSArray<SCIActionMenuSection *> *SCIActionButtonDefaultSectionsForSource(SCIActionButtonSource source) {
    NSMutableArray<SCIActionMenuSection *> *sections = [NSMutableArray array];
    NSArray<NSString *> *downloadActions = @[
        kSCIActionDownloadLibrary,
        kSCIActionDownloadShare,
        kSCIActionDownloadVault,
        kSCIActionViewThumbnail
    ];
    NSArray<NSString *> *copyActions = (source == SCIActionButtonSourceFeed || source == SCIActionButtonSourceReels)
        ? @[kSCIActionCopyDownloadLink, kSCIActionCopyCaption]
        : @[kSCIActionCopyDownloadLink];
    NSArray<NSString *> *moreActions = (source == SCIActionButtonSourceFeed || source == SCIActionButtonSourceReels)
        ? @[kSCIActionExpand, kSCIActionRepost, kSCIActionOpenTopicSettings]
        : @[kSCIActionExpand, kSCIActionOpenTopicSettings];

    [sections addObject:[SCIActionMenuSection sectionWithIdentifier:@"download"
                                                              title:@"Download"
                                                           iconName:@"download"
                                                        collapsible:YES
                                                            actions:downloadActions]];
    [sections addObject:[SCIActionMenuSection sectionWithIdentifier:@"copy"
                                                              title:@"Copy"
                                                           iconName:@"link"
                                                        collapsible:YES
                                                            actions:copyActions]];
    [sections addObject:[SCIActionMenuSection sectionWithIdentifier:@"more"
                                                              title:@"More"
                                                           iconName:@"more"
                                                        collapsible:YES
                                                            actions:moreActions]];
    return sections;
}

@implementation SCIActionButtonConfiguration

+ (instancetype)configurationForSource:(SCIActionButtonSource)source
                            topicTitle:(NSString *)topicTitle
                      supportedActions:(NSArray<NSString *> *)supportedActions
                       defaultSections:(NSArray<SCIActionMenuSection *> *)defaultSections
{
    SCIActionButtonConfiguration *configuration = [[self alloc] init];
    configuration.source = source;
    configuration.topicTitle = topicTitle.length > 0 ? topicTitle : SCIActionButtonTopicTitleForSource(source);
    configuration.supportedActions = supportedActions.count > 0 ? supportedActions : SCIActionButtonSupportedActionsForSource(source);
    configuration.sections = [NSMutableArray array];
    configuration.disabledActions = [NSMutableArray array];
    configuration.unassignedActions = [NSMutableArray array];

    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:[configuration configDefaultsKey]];
    if ([stored isKindOfClass:[NSDictionary class]]) {
        NSArray *storedSections = [stored[@"sections"] isKindOfClass:[NSArray class]] ? stored[@"sections"] : @[];
        for (NSDictionary *dictionary in storedSections) {
            SCIActionMenuSection *section = [SCIActionMenuSection sectionFromDictionary:dictionary];
            if (section) [configuration.sections addObject:section];
        }
        [configuration.disabledActions addObjectsFromArray:SCIFilteredActionArray(stored[@"disabled_actions"], configuration.supportedActions)];
        [configuration.unassignedActions addObjectsFromArray:SCIFilteredActionArray(stored[@"unassigned_actions"], configuration.supportedActions)];
    }

    if (configuration.sections.count == 0) {
        for (SCIActionMenuSection *section in (defaultSections.count > 0 ? defaultSections : SCIActionButtonDefaultSectionsForSource(source))) {
            [configuration.sections addObject:[section copy]];
        }
    }

    [configuration normalize];
    return configuration;
}

- (NSString *)configDefaultsKey {
    return [NSString stringWithFormat:@"action_button_%@_config", SCIActionButtonTopicKeyForSource(self.source)];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *sectionDictionaries = [NSMutableArray array];
    for (SCIActionMenuSection *section in self.sections) {
        [sectionDictionaries addObject:[section dictionaryRepresentation]];
    }
    return @{
        @"sections": sectionDictionaries,
        @"disabled_actions": [self.disabledActions copy] ?: @[],
        @"unassigned_actions": [self.unassignedActions copy] ?: @[]
    };
}

- (void)save {
    [self normalize];
    [[NSUserDefaults standardUserDefaults] setObject:[self dictionaryRepresentation] forKey:[self configDefaultsKey]];
}

- (NSArray<NSString *> *)assignedActions {
    NSMutableOrderedSet<NSString *> *assigned = [NSMutableOrderedSet orderedSet];
    for (SCIActionMenuSection *section in self.sections) {
        for (NSString *identifier in section.actions) {
            if ([self.supportedActions containsObject:identifier]) {
                [assigned addObject:identifier];
            }
        }
    }
    return assigned.array;
}

- (void)normalize {
    NSArray<NSString *> *supported = self.supportedActions ?: @[];
    NSMutableOrderedSet<NSString *> *seen = [NSMutableOrderedSet orderedSet];
    NSMutableArray<SCIActionMenuSection *> *normalizedSections = [NSMutableArray array];

    for (SCIActionMenuSection *section in self.sections ?: @[]) {
        if (![section isKindOfClass:[SCIActionMenuSection class]]) continue;
        if (section.identifier.length == 0) section.identifier = NSUUID.UUID.UUIDString;
        if (section.title.length == 0) section.title = @"Section";
        if (section.iconName.length == 0) section.iconName = @"more";

        NSArray<NSString *> *filteredActions = SCIFilteredActionArray(section.actions, supported);
        NSMutableArray<NSString *> *uniqueActions = [NSMutableArray array];
        for (NSString *identifier in filteredActions) {
            if ([seen containsObject:identifier]) continue;
            [seen addObject:identifier];
            [uniqueActions addObject:identifier];
        }
        section.actions = uniqueActions;
        [normalizedSections addObject:section];
    }

    self.sections = normalizedSections;
    self.disabledActions = [SCIFilteredActionArray(self.disabledActions, supported) mutableCopy];

    NSMutableOrderedSet<NSString *> *unassigned = [NSMutableOrderedSet orderedSetWithArray:SCIFilteredActionArray(self.unassignedActions, supported)];
    for (NSString *identifier in supported) {
        if (![seen containsObject:identifier]) {
            [unassigned addObject:identifier];
        }
    }
    self.unassignedActions = unassigned.array.mutableCopy;
}

- (nullable SCIActionMenuSection *)sectionWithIdentifier:(NSString *)identifier {
    for (SCIActionMenuSection *section in self.sections) {
        if ([section.identifier isEqualToString:identifier]) return section;
    }
    return nil;
}

- (NSArray<SCIActionMenuSection *> *)visibleSections {
    NSMutableArray<SCIActionMenuSection *> *visible = [NSMutableArray array];
    for (SCIActionMenuSection *section in self.sections) {
        NSMutableArray<NSString *> *actions = [NSMutableArray array];
        for (NSString *identifier in section.actions) {
            if (![self.disabledActions containsObject:identifier] && ![self.unassignedActions containsObject:identifier]) {
                [actions addObject:identifier];
            }
        }
        if (actions.count == 0) continue;
        [visible addObject:[SCIActionMenuSection sectionWithIdentifier:section.identifier
                                                                 title:section.title
                                                              iconName:section.iconName
                                                           collapsible:section.collapsible
                                                               actions:actions]];
    }
    return visible;
}

- (nullable NSString *)sectionIdentifierForAction:(NSString *)identifier {
    for (SCIActionMenuSection *section in self.sections) {
        if ([section.actions containsObject:identifier]) {
            return section.identifier;
        }
    }
    return nil;
}

- (void)setAction:(NSString *)identifier assignedToSectionIdentifier:(NSString *)sectionIdentifier {
    if (![self.supportedActions containsObject:identifier]) return;

    for (SCIActionMenuSection *section in self.sections) {
        [section.actions removeObject:identifier];
    }
    [self.unassignedActions removeObject:identifier];

    if (sectionIdentifier.length > 0) {
        SCIActionMenuSection *section = [self sectionWithIdentifier:sectionIdentifier];
        if (section && ![section.actions containsObject:identifier]) {
            [section.actions addObject:identifier];
        }
    } else {
        if (![self.unassignedActions containsObject:identifier]) {
            [self.unassignedActions addObject:identifier];
        }
    }
    [self normalize];
}

- (void)moveSectionFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex {
    if (sourceIndex < 0 || destinationIndex < 0 || sourceIndex >= self.sections.count || destinationIndex >= self.sections.count) return;
    SCIActionMenuSection *section = self.sections[sourceIndex];
    [self.sections removeObjectAtIndex:sourceIndex];
    [self.sections insertObject:section atIndex:destinationIndex];
}

- (void)moveActionInSectionIdentifier:(NSString *)sectionIdentifier fromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex {
    SCIActionMenuSection *section = [self sectionWithIdentifier:sectionIdentifier];
    if (!section) return;
    if (sourceIndex < 0 || destinationIndex < 0 || sourceIndex >= section.actions.count || destinationIndex >= section.actions.count) return;
    NSString *identifier = section.actions[sourceIndex];
    [section.actions removeObjectAtIndex:sourceIndex];
    [section.actions insertObject:identifier atIndex:destinationIndex];
}

@end
