#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCINotificationPillView.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const kSCINotificationDownloadLibrary;
FOUNDATION_EXPORT NSString * const kSCINotificationDownloadShare;
FOUNDATION_EXPORT NSString * const kSCINotificationCopyDownloadLink;
FOUNDATION_EXPORT NSString * const kSCINotificationCopyMedia;
FOUNDATION_EXPORT NSString * const kSCINotificationDownloadGallery;
FOUNDATION_EXPORT NSString * const kSCINotificationDownloadAllLibrary;
FOUNDATION_EXPORT NSString * const kSCINotificationDownloadAllShare;
FOUNDATION_EXPORT NSString * const kSCINotificationDownloadAllGallery;
FOUNDATION_EXPORT NSString * const kSCINotificationDownloadAllClipboard;
FOUNDATION_EXPORT NSString * const kSCINotificationDownloadAllLinks;
FOUNDATION_EXPORT NSString * const kSCINotificationExpand;
FOUNDATION_EXPORT NSString * const kSCINotificationViewThumbnail;
FOUNDATION_EXPORT NSString * const kSCINotificationCopyCaption;
FOUNDATION_EXPORT NSString * const kSCINotificationOpenTopicSettings;
FOUNDATION_EXPORT NSString * const kSCINotificationRepost;

FOUNDATION_EXPORT NSString * const kSCINotificationStoryMarkSeen;
FOUNDATION_EXPORT NSString * const kSCINotificationDirectVisualMarkSeen;
FOUNDATION_EXPORT NSString * const kSCINotificationThreadMessagesMarkSeen;

FOUNDATION_EXPORT NSString * const kSCINotificationProfileCopyInfo;
FOUNDATION_EXPORT NSString * const kSCINotificationProfileViewPicture;
FOUNDATION_EXPORT NSString * const kSCINotificationProfileSharePicture;
FOUNDATION_EXPORT NSString * const kSCINotificationProfileGalleryPicture;
FOUNDATION_EXPORT NSString * const kSCINotificationProfileOpenSettings;

FOUNDATION_EXPORT NSString * const kSCINotificationMediaPreviewSavePhotos;
FOUNDATION_EXPORT NSString * const kSCINotificationMediaPreviewSaveGallery;
FOUNDATION_EXPORT NSString * const kSCINotificationMediaPreviewShare;
FOUNDATION_EXPORT NSString * const kSCINotificationMediaPreviewCopy;
FOUNDATION_EXPORT NSString * const kSCINotificationMediaPreviewDeleteGallery;
FOUNDATION_EXPORT NSString * const kSCINotificationMediaPreviewOpenGallery;

FOUNDATION_EXPORT NSString * const kSCINotificationGalleryOpenOriginal;
FOUNDATION_EXPORT NSString * const kSCINotificationGalleryOpenProfile;
FOUNDATION_EXPORT NSString * const kSCINotificationGalleryDeleteFile;
FOUNDATION_EXPORT NSString * const kSCINotificationGalleryDeleteSelected;
FOUNDATION_EXPORT NSString * const kSCINotificationGalleryBulkDelete;
FOUNDATION_EXPORT NSString * const kSCINotificationGalleryImport;

FOUNDATION_EXPORT NSString * const kSCINotificationSettingsExport;
FOUNDATION_EXPORT NSString * const kSCINotificationSettingsImport;
FOUNDATION_EXPORT NSString * const kSCINotificationSettingsClearCache;
FOUNDATION_EXPORT NSString * const kSCINotificationCopyDescription;
FOUNDATION_EXPORT NSString * const kSCINotificationShareLongPressCopyLink;
FOUNDATION_EXPORT NSString * const kSCINotificationMediaEncodingLogs;
FOUNDATION_EXPORT NSString * const kSCINotificationFlexUnavailable;
FOUNDATION_EXPORT NSString * const kSCINotificationPillDurationKey;
FOUNDATION_EXPORT NSString * const kSCINotificationPillGlowEnabledKey;

#ifdef __cplusplus
extern "C" {
#endif

NSString *SCINotificationDefaultsKey(NSString *identifier);
NSString *SCINotificationHapticDefaultsKey(NSString *identifier);
NSArray<NSDictionary *> *SCINotificationPreferenceSections(void);
NSDictionary<NSString *, id> *SCINotificationDefaultPreferences(void);
BOOL SCINotificationIsEnabled(NSString *identifier);
NSTimeInterval SCINotificationPillDuration(void);
void SCINotificationTriggerHaptic(NSString *identifier, SCINotificationTone tone);
SCINotificationTone SCINotificationToneForIconResource(NSString * _Nullable iconResource);

void SCINotify(NSString *identifier,
               NSString *title,
               NSString * _Nullable subtitle,
               NSString * _Nullable iconResource,
               SCINotificationTone tone);

SCINotificationPillView * _Nullable SCINotifyProgress(NSString *identifier,
                                                  NSString * _Nullable title,
                                                  void (^ _Nullable onCancel)(void));

#ifdef __cplusplus
}
#endif

@interface SCINotificationCenter : NSObject
+ (instancetype)shared;
- (void)notifyIdentifier:(NSString *)identifier
                   title:(NSString *)title
                subtitle:(nullable NSString *)subtitle
            iconResource:(nullable NSString *)iconResource
                    tone:(SCINotificationTone)tone;
- (nullable SCINotificationPillView *)beginProgressForIdentifier:(NSString *)identifier
                                                       title:(nullable NSString *)title
                                                    onCancel:(nullable void (^)(void))onCancel;
@end

NS_ASSUME_NONNULL_END
