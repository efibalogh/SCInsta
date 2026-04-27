#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "../InstagramHeaders.h"
#import "../Utils.h"

#import "Manager.h"
#import "../Shared/UI/SCIFeedbackPillView.h"
#import "../Shared/MediaPreview/SCIFullScreenMediaPlayer.h"

@class SCIGallerySaveMetadata;

@interface SCIDownloadDelegate : NSObject <SCIDownloadDelegateProtocol>

typedef NS_ENUM(NSUInteger, DownloadAction) {
    share,
    saveToPhotos,
    saveToGallery
};
@property (nonatomic, readonly) DownloadAction action;
@property (nonatomic, readonly) BOOL showProgress;

@property (nonatomic, strong) SCIDownloadManager *downloadManager;
@property (nonatomic, strong) SCIFeedbackPillView *progressView;
/// Set immediately before `downloadFileWithURL:` when `action == saveToGallery`; consumed when the download finishes.
@property (nonatomic, strong, nullable) SCIGallerySaveMetadata *pendingGallerySaveMetadata;

- (instancetype)initWithAction:(DownloadAction)action showProgress:(BOOL)showProgress;

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension hudLabel:(NSString *)hudLabel;

@end
