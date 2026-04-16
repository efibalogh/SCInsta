#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "../InstagramHeaders.h"
#import "../Utils.h"

#import "Manager.h"
#import "../MediaPreview/SCIDownloadProgressView.h"
#import "../MediaPreview/SCIFullScreenMediaPlayer.h"

@class SCIVaultSaveMetadata;

@interface SCIDownloadDelegate : NSObject <SCIDownloadDelegateProtocol>

typedef NS_ENUM(NSUInteger, DownloadAction) {
    share,
    saveToPhotos,
    quickLook,
    preview,
    saveToVault
};
@property (nonatomic, readonly) DownloadAction action;
@property (nonatomic, readonly) BOOL showProgress;

@property (nonatomic, strong) SCIDownloadManager *downloadManager;
@property (nonatomic, strong) SCIDownloadProgressView *progressView;
/// Set immediately before `downloadFileWithURL:` when `action == saveToVault`; consumed when the download finishes.
@property (nonatomic, strong, nullable) SCIVaultSaveMetadata *pendingVaultSaveMetadata;

- (instancetype)initWithAction:(DownloadAction)action showProgress:(BOOL)showProgress;

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension hudLabel:(NSString *)hudLabel;

@end
