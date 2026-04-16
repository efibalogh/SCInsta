#import <UIKit/UIKit.h>

@class SCIMediaItem, SCIVaultFile;

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
+ (void)showFileURL:(NSURL *)fileURL fromVault:(BOOL)fromVault;

+ (void)showVaultFiles:(NSArray<SCIVaultFile *> *)files
       startingAtIndex:(NSInteger)index
    fromViewController:(UIViewController *)presenter;

+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index;

+ (void)showImage:(UIImage *)image;
+ (void)showRemoteImageURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
