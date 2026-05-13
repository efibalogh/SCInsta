#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "../InstagramHeaders.h"
#import "../Utils.h"

#import "Manager.h"
#import "../Shared/UI/SCINotificationCenter.h"
#import "../Shared/MediaPreview/SCIFullScreenMediaPlayer.h"

@class SCIGallerySaveMetadata;
@class SCIGalleryFile;

typedef void (^SCIDownloadCompletionBlock)(NSURL * _Nullable fileURL, NSError * _Nullable error);

@interface SCIDownloadDelegate : NSObject <SCIDownloadDelegateProtocol>

typedef NS_ENUM(NSUInteger, DownloadAction) {
    share,
    saveToPhotos,
    saveToGallery,
    downloadOnly
};
@property (nonatomic, readonly) DownloadAction action;
@property (nonatomic, readonly) BOOL showProgress;

@property (nonatomic, strong) SCIDownloadManager *downloadManager;
@property (nonatomic, strong) SCINotificationPillView *progressView;
@property (nonatomic, copy, nullable) NSString *notificationIdentifier;
/// Set immediately before `downloadFileWithURL:` to name and annotate the completed file; consumed when the download finishes.
@property (nonatomic, strong, nullable) SCIGallerySaveMetadata *pendingGallerySaveMetadata;
@property (nonatomic, copy, nullable) SCIDownloadCompletionBlock completionBlock;
@property (nonatomic, copy, nullable) dispatch_block_t customCancelHandler;

- (instancetype)initWithAction:(DownloadAction)action showProgress:(BOOL)showProgress;

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension hudLabel:(NSString *)hudLabel;
- (void)beginCustomProgressWithTitle:(nullable NSString *)title subtitle:(nullable NSString *)subtitle;
- (void)updateCustomProgress:(float)progress title:(nullable NSString *)title subtitle:(nullable NSString *)subtitle;
- (void)showCustomErrorWithTitle:(NSString *)title subtitle:(nullable NSString *)subtitle;
- (void)finishWithLocalFileURL:(NSURL *)fileURL;
- (void)cancelCustomOperation;

+ (BOOL)isVideoFileAtURL:(NSURL *)fileURL;
+ (void)saveFileURLToPhotos:(NSURL *)fileURL completion:(void(^)(BOOL success, NSError * _Nullable error))completion;
+ (nullable SCIGalleryFile *)saveFileURLToGallery:(NSURL *)fileURL
                                         metadata:(nullable SCIGallerySaveMetadata *)metadata
                                            error:(NSError **)error;

@end
