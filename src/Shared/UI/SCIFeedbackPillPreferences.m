#import "SCIFeedbackPillPreferences.h"

NSString * const kSCIFeedbackActionDownloadLibrary = @"download_library";
NSString * const kSCIFeedbackActionDownloadShare = @"download_share";
NSString * const kSCIFeedbackActionCopyDownloadLink = @"copy_download_link";
NSString * const kSCIFeedbackActionDownloadGallery = @"download_gallery";
NSString * const kSCIFeedbackActionExpand = @"expand";
NSString * const kSCIFeedbackActionViewThumbnail = @"view_thumbnail";
NSString * const kSCIFeedbackActionCopyCaption = @"copy_caption";
NSString * const kSCIFeedbackActionOpenTopicSettings = @"open_topic_settings";
NSString * const kSCIFeedbackActionRepost = @"repost";

NSString * const kSCIFeedbackActionStoryMarkSeen = @"story_mark_seen";
NSString * const kSCIFeedbackActionDirectVisualMarkSeen = @"direct_visual_mark_seen";
NSString * const kSCIFeedbackActionThreadMessagesMarkSeen = @"thread_messages_mark_seen";

NSString * const kSCIFeedbackActionProfileCopyInfo = @"profile_copy_info";
NSString * const kSCIFeedbackActionProfileViewPicture = @"profile_view_picture";
NSString * const kSCIFeedbackActionProfileSharePicture = @"profile_share_picture";
NSString * const kSCIFeedbackActionProfileGalleryPicture = @"profile_gallery_picture";
NSString * const kSCIFeedbackActionProfileOpenSettings = @"profile_open_settings";

NSString * const kSCIFeedbackActionMediaPreviewSavePhotos = @"media_preview_save_photos";
NSString * const kSCIFeedbackActionMediaPreviewSaveGallery = @"media_preview_save_gallery";
NSString * const kSCIFeedbackActionMediaPreviewShare = @"media_preview_share";
NSString * const kSCIFeedbackActionMediaPreviewCopy = @"media_preview_copy";
NSString * const kSCIFeedbackActionMediaPreviewDeleteGallery = @"media_preview_delete_gallery";
NSString * const kSCIFeedbackActionMediaPreviewOpenGallery = @"media_preview_open_gallery";

NSString * const kSCIFeedbackActionGalleryOpenOriginal = @"gallery_open_original";
NSString * const kSCIFeedbackActionGalleryOpenProfile = @"gallery_open_profile";
NSString * const kSCIFeedbackActionGalleryDeleteFile = @"gallery_delete_file";
NSString * const kSCIFeedbackActionGalleryDeleteSelected = @"gallery_delete_selected";
NSString * const kSCIFeedbackActionGalleryBulkDelete = @"gallery_bulk_delete";

NSString * const kSCIFeedbackActionSettingsExport = @"settings_export";
NSString * const kSCIFeedbackActionSettingsImport = @"settings_import";
NSString * const kSCIFeedbackActionSettingsClearCache = @"settings_clear_cache";

NSString * const kSCIFeedbackActionCopyDescription = @"copy_description";

static NSDictionary *SCIFeedbackPillItem(NSString *identifier, NSString *title, NSString *iconName) {
    return @{
        @"identifier": identifier,
        @"title": title,
        @"iconName": iconName
    };
}

NSString *SCIFeedbackPillDefaultsKey(NSString *identifier) {
    if (identifier.length == 0) return @"feedback_pill_action";
    return [NSString stringWithFormat:@"feedback_pill_action_%@", identifier];
}

NSArray<NSDictionary *> *SCIFeedbackPillPreferenceSections(void) {
    return @[
        @{
            @"title": @"Action Buttons",
            @"items": @[
                SCIFeedbackPillItem(kSCIFeedbackActionDownloadLibrary, @"Download", @"download"),
                SCIFeedbackPillItem(kSCIFeedbackActionDownloadShare, @"Share", @"share"),
                SCIFeedbackPillItem(kSCIFeedbackActionCopyDownloadLink, @"Copy Download Link", @"link"),
                SCIFeedbackPillItem(kSCIFeedbackActionDownloadGallery, @"Download to Gallery", @"photo_gallery"),
                SCIFeedbackPillItem(kSCIFeedbackActionExpand, @"Expand", @"expand"),
                SCIFeedbackPillItem(kSCIFeedbackActionViewThumbnail, @"View Thumbnail", @"photo"),
                SCIFeedbackPillItem(kSCIFeedbackActionCopyCaption, @"Copy Caption", @"caption"),
                SCIFeedbackPillItem(kSCIFeedbackActionOpenTopicSettings, @"Open Topic Settings", @"settings"),
                SCIFeedbackPillItem(kSCIFeedbackActionRepost, @"Repost", @"repost")
            ]
        },
        @{
            @"title": @"Stories & Messages",
            @"items": @[
                SCIFeedbackPillItem(kSCIFeedbackActionStoryMarkSeen, @"Mark Story as Seen", @"story"),
                SCIFeedbackPillItem(kSCIFeedbackActionDirectVisualMarkSeen, @"Mark Visual Message as Seen", @"messages"),
                SCIFeedbackPillItem(kSCIFeedbackActionThreadMessagesMarkSeen, @"Mark Messages as Seen", @"messages")
            ]
        },
        @{
            @"title": @"Profile",
            @"items": @[
                SCIFeedbackPillItem(kSCIFeedbackActionProfileCopyInfo, @"Copy Profile Info", @"copy"),
                SCIFeedbackPillItem(kSCIFeedbackActionProfileViewPicture, @"View Profile Picture", @"photo"),
                SCIFeedbackPillItem(kSCIFeedbackActionProfileSharePicture, @"Share Profile Picture", @"share"),
                SCIFeedbackPillItem(kSCIFeedbackActionProfileGalleryPicture, @"Save Profile Picture to Gallery", @"photo_gallery"),
                SCIFeedbackPillItem(kSCIFeedbackActionProfileOpenSettings, @"Open Profile Settings", @"settings")
            ]
        },
        @{
            @"title": @"Media Preview",
            @"items": @[
                SCIFeedbackPillItem(kSCIFeedbackActionMediaPreviewSavePhotos, @"Save to Photos", @"download"),
                SCIFeedbackPillItem(kSCIFeedbackActionMediaPreviewSaveGallery, @"Save to Gallery", @"photo_gallery"),
                SCIFeedbackPillItem(kSCIFeedbackActionMediaPreviewShare, @"Share Media", @"share"),
                SCIFeedbackPillItem(kSCIFeedbackActionMediaPreviewCopy, @"Copy Media", @"copy"),
                SCIFeedbackPillItem(kSCIFeedbackActionMediaPreviewDeleteGallery, @"Delete Gallery Media", @"trash"),
                SCIFeedbackPillItem(kSCIFeedbackActionMediaPreviewOpenGallery, @"Open Gallery Media", @"photo_gallery")
            ]
        },
        @{
            @"title": @"Gallery",
            @"items": @[
                SCIFeedbackPillItem(kSCIFeedbackActionGalleryOpenOriginal, @"Open Original Post", @"external_link"),
                SCIFeedbackPillItem(kSCIFeedbackActionGalleryOpenProfile, @"Open Profile", @"profile"),
                SCIFeedbackPillItem(kSCIFeedbackActionGalleryDeleteFile, @"Delete Gallery File", @"trash"),
                SCIFeedbackPillItem(kSCIFeedbackActionGalleryDeleteSelected, @"Delete Selected Files", @"trash"),
                SCIFeedbackPillItem(kSCIFeedbackActionGalleryBulkDelete, @"Bulk Delete Tool", @"trash")
            ]
        },
        @{
            @"title": @"Settings & General",
            @"items": @[
                SCIFeedbackPillItem(kSCIFeedbackActionSettingsExport, @"Export Settings", @"share"),
                SCIFeedbackPillItem(kSCIFeedbackActionSettingsImport, @"Import Settings", @"download"),
                SCIFeedbackPillItem(kSCIFeedbackActionSettingsClearCache, @"Clear Cache", @"circle_check_filled"),
                SCIFeedbackPillItem(kSCIFeedbackActionCopyDescription, @"Copy Description", @"copy_filled")
            ]
        }
    ];
}
