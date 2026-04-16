#import "Download.h"
#import "../Vault/SCIVaultFile.h"
#import "../Vault/SCIVaultSaveMetadata.h"
#import <Photos/Photos.h>

@implementation SCIDownloadDelegate

- (BOOL)isVideoFileAtURL:(NSURL *)fileURL {
    NSString *ext = fileURL.pathExtension.lowercaseString;
    NSSet<NSString *> *videoExtensions = [NSSet setWithArray:@[@"mp4", @"mov", @"m4v", @"avi", @"webm", @"mkv", @"3gp"]];
    return [videoExtensions containsObject:ext];
}

- (void)saveDownloadedFileToPhotos:(NSURL *)fileURL completion:(void(^)(BOOL success, NSError *error))completion {
    BOOL isVideo = [self isVideoFileAtURL:fileURL];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        if (isVideo) {
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
        } else {
            [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:fileURL];
        }
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(success, error);
            }
        });
    }];
}

- (void)showCompletionPillAndDismissAfter:(NSTimeInterval)delay completion:(void(^)(void))completion {
    [self.progressView showSuccess];
    self.progressView.onTapWhenCompleted = nil;
    self.progressView.onCancel = nil;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.progressView dismiss];
        if (completion) {
            completion();
        }
    });
}

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
        NSURL *retryURL = [url copy];
        NSString *retryExtension = [fileExtension copy];
        NSString *retryHudLabel = [hudLabel copy];
        self.progressView.onCancel = ^{
            [weakSelf.downloadManager cancelDownload];
        };
        self.progressView.onRetry = ^{
            [weakSelf downloadFileWithURL:retryURL fileExtension:retryExtension hudLabel:retryHudLabel];
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
    self.pendingVaultSaveMetadata = nil;
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
    self.pendingVaultSaveMetadata = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error && error.code != NSURLErrorCancelled) {
            NSLog(@"[SCInsta] Download: Download failed with error: \"%@\"", error);
            [self.progressView showError:@"Download failed"];
        }
    });
}

- (void)downloadDidFinishWithFileURL:(NSURL *)fileURL {
    SCIVaultSaveMetadata *vaultMeta = self.pendingVaultSaveMetadata;
    self.pendingVaultSaveMetadata = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[SCInsta] Download: Download finished with url: \"%@\"", [fileURL absoluteString]);
        NSLog(@"[SCInsta] Download: Completed with action %d", (int)self.action);

        if (self.action == share) {
            [self showCompletionPillAndDismissAfter:0.25 completion:^{
                [SCIUtils showShareVC:fileURL];
            }];
            return;
        }

        if (self.action == saveToPhotos) {
            [self saveDownloadedFileToPhotos:fileURL completion:^(BOOL success, NSError *error) {
                if (success) {
                    [self showCompletionPillAndDismissAfter:0.45 completion:^{
                        [SCIUtils showToastForDuration:2.0 title:@"Saved to Photos"];
                    }];
                } else {
                    [self.progressView showError:@"Failed to save"];
                    [SCIUtils showToastForDuration:3.0 title:@"Failed to save" subtitle:error.localizedDescription ?: @""];
                }
            }];
            return;
        }

        if (self.action == saveToVault) {
            BOOL isVideo = [self isVideoFileAtURL:fileURL];
            SCIVaultMediaType vaultType = isVideo ? SCIVaultMediaTypeVideo : SCIVaultMediaTypeImage;
            NSError *error;
            SCIVaultFile *file = [SCIVaultFile saveFileToVault:fileURL
                                                        source:SCIVaultSourceOther
                                                     mediaType:vaultType
                                                    folderPath:nil
                                                      metadata:vaultMeta
                                                         error:&error];
            if (file) {
                [self showCompletionPillAndDismissAfter:0.45 completion:^{
                    [SCIUtils showToastForDuration:2.0 title:@"Saved to Vault"];
                }];
            } else {
                [self.progressView showError:@"Failed to save to vault"];
            }
            return;
        }

        [self showCompletionPillAndDismissAfter:0.25 completion:^{
            [SCIFullScreenMediaPlayer showFileURL:fileURL];
        }];
    });
}

@end
