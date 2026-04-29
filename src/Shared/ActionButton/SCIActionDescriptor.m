#import "SCIActionDescriptor.h"
#import "ActionButtonCore.h"

@implementation SCIActionDescriptor

+ (instancetype)descriptorWithIdentifier:(NSString *)identifier
                                   title:(NSString *)title
                                iconName:(NSString *)iconName
{
    SCIActionDescriptor *descriptor = [[self alloc] init];
    descriptor.identifier = identifier;
    descriptor.title = title;
    descriptor.iconName = iconName;
    return descriptor;
}

+ (NSArray<SCIActionDescriptor *> *)descriptors {
    static NSArray<SCIActionDescriptor *> *descriptors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        descriptors = @[
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionDownloadLibrary title:@"Save to Photos" iconName:@"download"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionDownloadShare title:@"Share" iconName:@"share"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionCopyDownloadLink title:@"Copy Link" iconName:@"link"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionCopyMedia title:@"Copy Media" iconName:@"copy"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionDownloadGallery title:@"Save to Gallery" iconName:@"media"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionDownloadAllLibrary title:@"Save All to Photos" iconName:@"download"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionDownloadAllShare title:@"Share All" iconName:@"share"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionDownloadAllGallery title:@"Save All to Gallery" iconName:@"media"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionDownloadAllClipboard title:@"Copy All Media" iconName:@"copy"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionDownloadAllLinks title:@"Copy All Links" iconName:@"link"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionExpand title:@"Expand" iconName:@"expand"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionViewThumbnail title:@"View Thumbnail" iconName:@"photo_gallery"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionCopyCaption title:@"Copy Caption" iconName:@"caption"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionOpenTopicSettings title:@"Settings" iconName:@"settings"],
            [SCIActionDescriptor descriptorWithIdentifier:kSCIActionRepost title:@"Repost" iconName:@"repost"],
            [SCIActionDescriptor descriptorWithIdentifier:@"more" title:@"More" iconName:@"more"],
            [SCIActionDescriptor descriptorWithIdentifier:@"action" title:@"Actions" iconName:@"action"]
        ];
    });
    return descriptors;
}

+ (nullable instancetype)descriptorForIdentifier:(NSString *)identifier {
    for (SCIActionDescriptor *descriptor in [self descriptors]) {
        if ([descriptor.identifier isEqualToString:identifier]) {
            return descriptor;
        }
    }
    return nil;
}

+ (NSArray<SCIActionDescriptor *> *)availableSectionIconDescriptors {
    return @[
        [SCIActionDescriptor descriptorWithIdentifier:@"action" title:@"Actions" iconName:@"action"],
        [SCIActionDescriptor descriptorWithIdentifier:@"copy" title:@"Copy" iconName:@"copy"],
        [SCIActionDescriptor descriptorWithIdentifier:@"caption" title:@"Caption" iconName:@"caption"],
        [SCIActionDescriptor descriptorWithIdentifier:@"download" title:@"Download" iconName:@"download"],
        [SCIActionDescriptor descriptorWithIdentifier:@"share" title:@"Share" iconName:@"share"],
        [SCIActionDescriptor descriptorWithIdentifier:@"link" title:@"Link" iconName:@"link"],
        [SCIActionDescriptor descriptorWithIdentifier:@"media" title:@"Gallery" iconName:@"media"],
        [SCIActionDescriptor descriptorWithIdentifier:@"expand" title:@"Expand" iconName:@"expand"],
        [SCIActionDescriptor descriptorWithIdentifier:@"photo_gallery" title:@"Thumbnail" iconName:@"photo_gallery"],
        [SCIActionDescriptor descriptorWithIdentifier:@"repost" title:@"Repost" iconName:@"repost"],
        [SCIActionDescriptor descriptorWithIdentifier:@"feed" title:@"Feed" iconName:@"feed"],
        [SCIActionDescriptor descriptorWithIdentifier:@"reels" title:@"Reels" iconName:@"reels"],
        [SCIActionDescriptor descriptorWithIdentifier:@"story" title:@"Stories" iconName:@"story"],
        [SCIActionDescriptor descriptorWithIdentifier:@"messages" title:@"Messages" iconName:@"messages"],
        [SCIActionDescriptor descriptorWithIdentifier:@"profile" title:@"Profile" iconName:@"profile"],
        [SCIActionDescriptor descriptorWithIdentifier:@"settings" title:@"Settings" iconName:@"settings"],
        [SCIActionDescriptor descriptorWithIdentifier:@"more" title:@"More" iconName:@"more"]
    ];
}

+ (NSArray<SCIActionDescriptor *> *)feedbackPillConfigurableDescriptors {
    NSMutableArray<SCIActionDescriptor *> *descriptors = [NSMutableArray array];
    NSArray<NSString *> *identifiers = @[
        kSCIActionDownloadLibrary,
        kSCIActionDownloadShare,
        kSCIActionCopyDownloadLink,
        kSCIActionCopyMedia,
        kSCIActionDownloadGallery,
        kSCIActionDownloadAllLibrary,
        kSCIActionDownloadAllShare,
        kSCIActionDownloadAllGallery,
        kSCIActionDownloadAllClipboard,
        kSCIActionDownloadAllLinks,
        kSCIActionExpand,
        kSCIActionViewThumbnail,
        kSCIActionCopyCaption,
        kSCIActionOpenTopicSettings,
        kSCIActionRepost
    ];

    for (NSString *identifier in identifiers) {
        SCIActionDescriptor *descriptor = [self descriptorForIdentifier:identifier];
        if (descriptor) {
            [descriptors addObject:descriptor];
        }
    }

    return [descriptors copy];
}

@end

NSString *SCIActionDescriptorDisplayTitle(NSString *identifier, NSString *topicTitle) {
    if ([identifier isEqualToString:kSCIActionOpenTopicSettings] && topicTitle.length > 0) {
        return [NSString stringWithFormat:@"%@ Settings", topicTitle];
    }
    SCIActionDescriptor *descriptor = [SCIActionDescriptor descriptorForIdentifier:identifier];
    return descriptor.title ?: @"Action";
}

NSString *SCIActionDescriptorIconName(NSString *identifier) {
    SCIActionDescriptor *descriptor = [SCIActionDescriptor descriptorForIdentifier:identifier];
    return descriptor.iconName ?: @"action";
}

NSString *SCIActionDescriptorFeedbackPillDefaultsKey(NSString *identifier) {
    if (identifier.length == 0) return @"feedback_pill_action";
    return [NSString stringWithFormat:@"feedback_pill_action_%@", identifier];
}
