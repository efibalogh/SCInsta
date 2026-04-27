#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const kSCIFeedbackActionDownloadLibrary;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionDownloadShare;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionCopyDownloadLink;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionDownloadGallery;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionExpand;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionViewThumbnail;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionCopyCaption;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionOpenTopicSettings;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionRepost;

FOUNDATION_EXPORT NSString * const kSCIFeedbackActionStoryMarkSeen;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionDirectVisualMarkSeen;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionThreadMessagesMarkSeen;

FOUNDATION_EXPORT NSString * const kSCIFeedbackActionProfileCopyInfo;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionProfileViewPicture;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionProfileSharePicture;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionProfileGalleryPicture;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionProfileOpenSettings;

FOUNDATION_EXPORT NSString * const kSCIFeedbackActionMediaPreviewSavePhotos;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionMediaPreviewSaveGallery;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionMediaPreviewShare;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionMediaPreviewCopy;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionMediaPreviewDeleteGallery;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionMediaPreviewOpenGallery;

FOUNDATION_EXPORT NSString * const kSCIFeedbackActionGalleryOpenOriginal;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionGalleryOpenProfile;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionGalleryDeleteFile;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionGalleryDeleteSelected;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionGalleryBulkDelete;

FOUNDATION_EXPORT NSString * const kSCIFeedbackActionSettingsExport;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionSettingsImport;
FOUNDATION_EXPORT NSString * const kSCIFeedbackActionSettingsClearCache;

FOUNDATION_EXPORT NSString * const kSCIFeedbackActionCopyDescription;

FOUNDATION_EXPORT NSString *SCIFeedbackPillDefaultsKey(NSString *identifier);
FOUNDATION_EXPORT NSArray<NSDictionary *> *SCIFeedbackPillPreferenceSections(void);

NS_ASSUME_NONNULL_END
