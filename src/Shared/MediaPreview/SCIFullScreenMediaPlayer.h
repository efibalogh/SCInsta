#import <UIKit/UIKit.h>

@class SCIMediaItem, SCIVaultFile, SCIVaultSaveMetadata;

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

@property (nonatomic, assign) BOOL isFromVault;
@property (nonatomic, weak, nullable) id<SCIFullScreenMediaPlayerDelegate> delegate;

- (void)playItems:(NSArray<SCIMediaItem *> *)items
  startingAtIndex:(NSInteger)index
fromViewController:(UIViewController *)presenter;

+ (void)showFileURL:(NSURL *)fileURL;
+ (void)showFileURL:(NSURL *)fileURL metadata:(nullable SCIVaultSaveMetadata *)metadata;
+ (void)showFileURL:(NSURL *)fileURL fromVault:(BOOL)fromVault;

+ (void)showVaultFiles:(NSArray<SCIVaultFile *> *)files
       startingAtIndex:(NSInteger)index
    fromViewController:(UIViewController *)presenter;

+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index;
+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index metadata:(nullable SCIVaultSaveMetadata *)metadata;

/// Ordered carousel / album: images and videos as `SCIMediaItem` (matches vault `playItems` behavior).
+ (void)showMediaItems:(NSArray<SCIMediaItem *> *)items
       startingAtIndex:(NSInteger)index
              metadata:(nullable SCIVaultSaveMetadata *)metadata;
+ (void)showMediaItems:(NSArray<SCIMediaItem *> *)items
       startingAtIndex:(NSInteger)index
              metadata:(nullable SCIVaultSaveMetadata *)metadata
        playbackSource:(SCIFullScreenPlaybackSource)playbackSource
            sourceView:(nullable UIView *)sourceView
            controller:(nullable UIViewController *)controller
         pausePlayback:(nullable SCIMediaPreviewPlaybackBlock)pausePlayback
        resumePlayback:(nullable SCIMediaPreviewPlaybackBlock)resumePlayback;

+ (void)showImage:(UIImage *)image;
+ (void)showImage:(UIImage *)image metadata:(nullable SCIVaultSaveMetadata *)metadata;
+ (void)showImage:(UIImage *)image
         metadata:(nullable SCIVaultSaveMetadata *)metadata
   playbackSource:(SCIFullScreenPlaybackSource)playbackSource
       sourceView:(nullable UIView *)sourceView
       controller:(nullable UIViewController *)controller
    pausePlayback:(nullable SCIMediaPreviewPlaybackBlock)pausePlayback
   resumePlayback:(nullable SCIMediaPreviewPlaybackBlock)resumePlayback;
+ (void)showRemoteImageURL:(NSURL *)url;
+ (void)showRemoteImageURL:(NSURL *)url metadata:(nullable SCIVaultSaveMetadata *)metadata;
+ (void)showRemoteImageURL:(NSURL *)url
                  metadata:(nullable SCIVaultSaveMetadata *)metadata
            playbackSource:(SCIFullScreenPlaybackSource)playbackSource
                sourceView:(nullable UIView *)sourceView
                controller:(nullable UIViewController *)controller
             pausePlayback:(nullable SCIMediaPreviewPlaybackBlock)pausePlayback
            resumePlayback:(nullable SCIMediaPreviewPlaybackBlock)resumePlayback;
/// Profile / avatar long-press: sets vault source + optional username for “Save to Vault”.
+ (void)showRemoteImageURL:(NSURL *)url profileUsername:(nullable NSString *)username;

@end

NS_ASSUME_NONNULL_END
