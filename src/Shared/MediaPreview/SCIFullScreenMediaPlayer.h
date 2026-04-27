#import <UIKit/UIKit.h>

@class SCIMediaItem, SCIGalleryFile, SCIGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIFullScreenPlaybackSource) {
    SCIFullScreenPlaybackSourceUnknown = 0,
    SCIFullScreenPlaybackSourceFeed = 1,
    SCIFullScreenPlaybackSourceReels = 2,
    SCIFullScreenPlaybackSourceStories = 3,
    SCIFullScreenPlaybackSourceDirect = 4,
    SCIFullScreenPlaybackSourceProfile = 5,
};

typedef void (^SCIMediaPreviewPlaybackBlock)(void);

@protocol SCIFullScreenMediaPlayerDelegate <NSObject>
@optional
- (void)fullScreenMediaPlayerDidDismiss;
- (void)fullScreenMediaPlayerDidDeleteFileAtIndex:(NSInteger)index;
@end

@interface SCIFullScreenMediaPlayer : UIViewController

@property (nonatomic, assign) BOOL isFromGallery;
@property (nonatomic, weak, nullable) id<SCIFullScreenMediaPlayerDelegate> delegate;

- (void)playItems:(NSArray<SCIMediaItem *> *)items
  startingAtIndex:(NSInteger)index
fromViewController:(UIViewController *)presenter;

+ (void)showFileURL:(NSURL *)fileURL;
+ (void)showFileURL:(NSURL *)fileURL metadata:(nullable SCIGallerySaveMetadata *)metadata;
+ (void)showFileURL:(NSURL *)fileURL fromGallery:(BOOL)fromGallery;

+ (void)showGalleryFiles:(NSArray<SCIGalleryFile *> *)files
       startingAtIndex:(NSInteger)index
    fromViewController:(UIViewController *)presenter;

+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index;
+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index metadata:(nullable SCIGallerySaveMetadata *)metadata;

/// Ordered carousel / album: images and videos as `SCIMediaItem` (matches gallery `playItems` behavior).
+ (void)showMediaItems:(NSArray<SCIMediaItem *> *)items
       startingAtIndex:(NSInteger)index
              metadata:(nullable SCIGallerySaveMetadata *)metadata;
+ (void)showMediaItems:(NSArray<SCIMediaItem *> *)items
       startingAtIndex:(NSInteger)index
              metadata:(nullable SCIGallerySaveMetadata *)metadata
        playbackSource:(SCIFullScreenPlaybackSource)playbackSource
            sourceView:(nullable UIView *)sourceView
            controller:(nullable UIViewController *)controller
         pausePlayback:(nullable SCIMediaPreviewPlaybackBlock)pausePlayback
        resumePlayback:(nullable SCIMediaPreviewPlaybackBlock)resumePlayback;

+ (void)showImage:(UIImage *)image;
+ (void)showImage:(UIImage *)image metadata:(nullable SCIGallerySaveMetadata *)metadata;
+ (void)showImage:(UIImage *)image
         metadata:(nullable SCIGallerySaveMetadata *)metadata
   playbackSource:(SCIFullScreenPlaybackSource)playbackSource
       sourceView:(nullable UIView *)sourceView
       controller:(nullable UIViewController *)controller
    pausePlayback:(nullable SCIMediaPreviewPlaybackBlock)pausePlayback
   resumePlayback:(nullable SCIMediaPreviewPlaybackBlock)resumePlayback;
+ (void)showRemoteImageURL:(NSURL *)url;
+ (void)showRemoteImageURL:(NSURL *)url metadata:(nullable SCIGallerySaveMetadata *)metadata;
+ (void)showRemoteImageURL:(NSURL *)url
                  metadata:(nullable SCIGallerySaveMetadata *)metadata
            playbackSource:(SCIFullScreenPlaybackSource)playbackSource
                sourceView:(nullable UIView *)sourceView
                controller:(nullable UIViewController *)controller
             pausePlayback:(nullable SCIMediaPreviewPlaybackBlock)pausePlayback
            resumePlayback:(nullable SCIMediaPreviewPlaybackBlock)resumePlayback;
/// Profile / avatar long-press: sets Gallery source + optional username for “Save to Gallery”.
+ (void)showRemoteImageURL:(NSURL *)url profileUsername:(nullable NSString *)username;

@end

NS_ASSUME_NONNULL_END
