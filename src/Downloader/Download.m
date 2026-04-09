#import "Download.h"

@implementation SCIDownloadDelegate

- (instancetype)initWithAction:(DownloadAction)action showProgress:(BOOL)showProgress {
    self = [super init];
    
    if (self) {
        _action = action;
        _showProgress = showProgress;

        self.downloadManager = [[SCIDownloadManager alloc] initWithDelegate:self];
    }

    return self;
}

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension hudLabel:(NSString *)hudLabel {
    // Show progress pill
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView = [SCIDownloadProgressView showInView:topMostController().view];
        
        // Allow cancelling
        __weak typeof(self) weakSelf = self;
        self.progressView.onCancel = ^{
            [weakSelf.downloadManager cancelDownload];
        };
    });

    NSLog(@"[SCInsta] Download: Will start download for url \"%@\" with file extension: \".%@\"", url, fileExtension);

    // Start download using manager
    [self.downloadManager downloadFileWithURL:url fileExtension:fileExtension];
}

// Delegate methods
- (void)downloadDidStart {
    NSLog(@"[SCInsta] Download: Download started");
}

- (void)downloadDidCancel {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView dismiss];
    });

    NSLog(@"[SCInsta] Download: Download cancelled");
}

- (void)downloadDidProgress:(float)progress {
    NSLog(@"[SCInsta] Download: Download progress: %f", progress);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView setProgress:progress animated:YES];
    });
}

- (void)downloadDidFinishWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error && error.code != NSURLErrorCancelled) {
            NSLog(@"[SCInsta] Download: Download failed with error: \"%@\"", error);
            [self.progressView showError:@"Download failed"];
        }
    });
}

- (void)downloadDidFinishWithFileURL:(NSURL *)fileURL {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[SCInsta] Download: Download finished with url: \"%@\"", [fileURL absoluteString]);
        NSLog(@"[SCInsta] Download: Completed with action %d", (int)self.action);

        [self.progressView showSuccess];

        __weak typeof(self) weakSelf = self;
        self.progressView.onTapWhenCompleted = ^{
            switch (weakSelf.action) {
                case preview:
                case quickLook:
                case share:
                default:
                    [SCIMediaPreviewController showPreviewForFileURL:fileURL];
                    break;
            }
        };
    });
}

@end
