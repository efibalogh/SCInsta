#import <UIKit/UIKit.h>

@class SCIMediaItem, SCIVaultFile, SCIVaultSaveMetadata;

NS_ASSUME_NONNULL_BEGIN

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

+ (void)showImage:(UIImage *)image;
+ (void)showRemoteImageURL:(NSURL *)url;
/// Profile / avatar long-press: sets vault source + optional username for “Save to Vault”.
+ (void)showRemoteImageURL:(NSURL *)url profileUsername:(nullable NSString *)username;

@end

NS_ASSUME_NONNULL_END
