#import "Download.h"
#import "../Shared/Gallery/SCIGalleryFile.h"
#import "../Shared/Gallery/SCIGallerySaveMetadata.h"
#import "../Shared/Gallery/SCIGalleryViewController.h"
#import <Photos/Photos.h>

@implementation SCIDownloadDelegate

static NSTimeInterval const kSCIDownloadCompletionPillDuration = 1.8;

static NSCountedSet *SCIActiveDownloadDelegates(void) {
    static NSCountedSet *delegates = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        delegates = [NSCountedSet set];
    });
    return delegates;
}

static void SCIRetainActiveDownloadDelegate(SCIDownloadDelegate *delegate) {
    @synchronized (SCIActiveDownloadDelegates()) {
        [SCIActiveDownloadDelegates() addObject:delegate];
    }
}

static void SCIReleaseActiveDownloadDelegate(SCIDownloadDelegate *delegate) {
    if (!delegate) {
        return;
    }
    @synchronized (SCIActiveDownloadDelegates()) {
        [SCIActiveDownloadDelegates() removeObject:delegate];
    }
}

static void SCIInvokeDownloadCompletion(SCIDownloadDelegate *delegate, NSURL *fileURL, NSError *error) {
    SCIDownloadCompletionBlock completion = [delegate.completionBlock copy];
    delegate.completionBlock = nil;
    if (completion) {
        completion(fileURL, error);
    }
}

static NSError *SCIDownloadErrorWithDescription(NSString *description, NSInteger code) {
    return [NSError errorWithDomain:@"SCInsta.Download"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description ?: @"Download failed"}];
}

+ (BOOL)isVideoFileAtURL:(NSURL *)fileURL {
    NSString *ext = fileURL.pathExtension.lowercaseString;
    NSSet<NSString *> *videoExtensions = [NSSet setWithArray:@[@"mp4", @"mov", @"m4v", @"avi", @"webm", @"mkv", @"3gp"]];
    return [videoExtensions containsObject:ext];
}

static BOOL SCIIsAudioFileAtURL(NSURL *fileURL) {
    NSString *ext = fileURL.pathExtension.lowercaseString;
    NSSet<NSString *> *audioExtensions = [NSSet setWithArray:@[@"m4a", @"aac", @"mp3", @"wav", @"caf", @"aiff", @"flac", @"opus", @"ogg"]];
    return [audioExtensions containsObject:ext];
}

+ (void)saveFileURLToPhotos:(NSURL *)fileURL completion:(void(^)(BOOL success, NSError *error))completion {
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

+ (SCIGalleryFile *)saveFileURLToGallery:(NSURL *)fileURL
                                metadata:(SCIGallerySaveMetadata *)metadata
                                   error:(NSError **)error {
    SCIGalleryMediaType galleryType = [self isVideoFileAtURL:fileURL] ? SCIGalleryMediaTypeVideo : SCIGalleryMediaTypeImage;
    return [SCIGalleryFile saveFileToGallery:fileURL
                                      source:SCIGallerySourceOther
                                   mediaType:galleryType
                                  folderPath:nil
                                    metadata:metadata
                                       error:error];
}

- (void)showCompletionPillWithSubtitle:(NSString *)subtitle
                    completionImmediately:(BOOL)completionImmediately
                              completion:(void(^)(void))completion {
    if (!self.progressView) {
        if (completion) {
            completion();
        }
        return;
    }

    [self.progressView showSuccessWithTitle:@"Download complete" subtitle:subtitle icon:nil];
    self.progressView.onTapWhenCompleted = nil;
    self.progressView.onCancel = nil;

    if (completionImmediately && completion) {
        completion();
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSCIDownloadCompletionPillDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.progressView dismiss];
        if (!completionImmediately && completion) {
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
    SCIRetainActiveDownloadDelegate(self);
    self.customCancelHandler = nil;

    if (self.showProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView = [SCIUtils showProgressPill];
            
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
    }

    NSLog(@"[SCInsta] Download: Will start download for url \"%@\" with file extension: \".%@\"", url, fileExtension);

    // Start download using manager
    [self.downloadManager downloadFileWithURL:url fileExtension:fileExtension];
}

- (void)beginCustomProgressWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    SCIRetainActiveDownloadDelegate(self);

    if (!self.showProgress) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.progressView) {
            self.progressView = [SCIUtils showProgressPill];
        }
        __weak typeof(self) weakSelf = self;
        self.progressView.onCancel = ^{
            [weakSelf cancelCustomOperation];
        };
        self.progressView.onRetry = nil;
        [self.progressView updateProgressTitle:title subtitle:subtitle];
        [self.progressView setProgress:0.02f animated:NO];
    });
}

- (void)updateCustomProgress:(float)progress title:(NSString *)title subtitle:(NSString *)subtitle {
    if (!self.showProgress) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.progressView) {
            self.progressView = [SCIUtils showProgressPill];
        }
        [self.progressView updateProgressTitle:title subtitle:subtitle];
        [self.progressView setProgress:progress animated:YES];
    });
}

- (void)showCustomErrorWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.showProgress && self.progressView) {
            [self.progressView showErrorWithTitle:title subtitle:subtitle icon:nil];
        }
        SCIInvokeDownloadCompletion(self, nil, SCIDownloadErrorWithDescription(subtitle.length > 0 ? subtitle : title, 50));
        SCIReleaseActiveDownloadDelegate(self);
    });
}

- (void)finishWithLocalFileURL:(NSURL *)fileURL {
    [self downloadDidFinishWithFileURL:fileURL];
}

- (void)cancelCustomOperation {
    dispatch_block_t cancelHandler = [self.customCancelHandler copy];
    self.customCancelHandler = nil;
    if (cancelHandler) {
        cancelHandler();
    }
    self.pendingGallerySaveMetadata = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView dismiss];
    });
    SCIInvokeDownloadCompletion(self, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]);
    SCIReleaseActiveDownloadDelegate(self);
}

// Delegate methods
- (void)downloadDidStart {
    NSLog(@"[SCInsta] Download: Download started");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView setProgress:0.02f animated:NO];
    });
}

- (void)downloadDidCancel {
    self.pendingGallerySaveMetadata = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView dismiss];
    });
    SCIInvokeDownloadCompletion(self, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]);
    SCIReleaseActiveDownloadDelegate(self);

    NSLog(@"[SCInsta] Download: Download cancelled");
}

- (void)downloadDidProgress:(float)progress {
    NSLog(@"[SCInsta] Download: Download progress: %f", progress);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView setProgress:progress animated:YES];
    });
}

- (void)downloadDidFinishWithError:(NSError *)error {
    self.pendingGallerySaveMetadata = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error && error.code != NSURLErrorCancelled) {
            NSLog(@"[SCInsta] Download: Download failed with error: \"%@\"", error);
            if (self.showProgress && self.progressView) {
                void (^existingDismissHandler)(void) = [self.progressView.onDidDismiss copy];
                __weak typeof(self) weakSelf = self;
                self.progressView.onDidDismiss = ^{
                    if (existingDismissHandler) {
                        existingDismissHandler();
                    }
                    SCIReleaseActiveDownloadDelegate(weakSelf);
                };
                [self.progressView showError:@"Download failed"];
                SCIInvokeDownloadCompletion(self, nil, error);
                return;
            }
        }

        if (error) {
            SCIInvokeDownloadCompletion(self, nil, error);
        }
        SCIReleaseActiveDownloadDelegate(self);
    });
}

- (void)downloadDidFinishWithFileURL:(NSURL *)fileURL {
    SCIGallerySaveMetadata *galleryMeta = self.pendingGallerySaveMetadata;
    self.pendingGallerySaveMetadata = nil;
    if (!galleryMeta) {
        galleryMeta = [[SCIGallerySaveMetadata alloc] init];
        galleryMeta.source = (int16_t)SCIGallerySourceOther;
    }

    BOOL isVideo = [[self class] isVideoFileAtURL:fileURL];
    BOOL isAudio = SCIIsAudioFileAtURL(fileURL);
    SCIGalleryMediaType galleryType = isVideo ? SCIGalleryMediaTypeVideo : SCIGalleryMediaTypeImage;
    NSString *fileName = SCIFileNameForMedia(fileURL, galleryType, galleryMeta);
    if (isAudio) {
        NSString *audioExtension = fileURL.pathExtension.length > 0 ? fileURL.pathExtension.lowercaseString : @"m4a";
        fileName = [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:audioExtension];
    }
    NSString *newPath = [[fileURL.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:fileName];
    NSURL *newURL = [NSURL fileURLWithPath:newPath];

    if (![newURL isEqual:fileURL]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *removeError = nil;
        if ([fileManager fileExistsAtPath:newURL.path] && ![fileManager removeItemAtURL:newURL error:&removeError]) {
            NSLog(@"[SCInsta] Download: Failed removing existing file at \"%@\": %@", newURL.path, removeError);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.showProgress) {
                    [self.progressView showError:@"Failed to prepare file"];
                }
                SCIInvokeDownloadCompletion(self, nil, SCIDownloadErrorWithDescription(@"Failed to prepare file", 1));
            });
            SCIReleaseActiveDownloadDelegate(self);
            return;
        }

        NSError *moveError = nil;
        if (![fileManager moveItemAtURL:fileURL toURL:newURL error:&moveError]) {
            NSLog(@"[SCInsta] Download: Failed renaming downloaded file to \"%@\": %@", newURL.path, moveError);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.showProgress) {
                    [self.progressView showError:@"Failed to finalize file"];
                }
                SCIInvokeDownloadCompletion(self, nil, SCIDownloadErrorWithDescription(@"Failed to finalize file", 2));
            });
            SCIReleaseActiveDownloadDelegate(self);
            return;
        }
    } else {
        newURL = fileURL;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[SCInsta] Download: Download finished with url: \"%@\"", [newURL absoluteString]);
        NSLog(@"[SCInsta] Download: Completed with action %d", (int)self.action);

        if (self.action == downloadOnly) {
            SCIInvokeDownloadCompletion(self, newURL, nil);
            SCIReleaseActiveDownloadDelegate(self);
            return;
        }

        if (self.action == share) {
            [self.progressView updateProgressTitle:@"Preparing share" subtitle:nil];
            [self.progressView setProgress:0.98f animated:YES];
            [self showCompletionPillWithSubtitle:@"Shared successfully" completionImmediately:YES completion:^{
                [SCIUtils showShareVC:newURL];
                SCIInvokeDownloadCompletion(self, newURL, nil);
                SCIReleaseActiveDownloadDelegate(self);
            }];
            return;
        }

        if (self.action == saveToPhotos) {
            [self.progressView updateProgressTitle:@"Saving to Photos" subtitle:nil];
            [self.progressView setProgress:0.98f animated:YES];
            [[self class] saveFileURLToPhotos:newURL completion:^(BOOL success, NSError *error) {
                if (success) {
                    [self showCompletionPillWithSubtitle:@"Saved to Photos successfully" completionImmediately:NO completion:^{
                        SCIInvokeDownloadCompletion(self, newURL, nil);
                        SCIReleaseActiveDownloadDelegate(self);
                    }];
                    if (self.progressView) {
                        self.progressView.onTapWhenCompleted = ^{
                            [SCIUtils openPhotosApp];
                        };
                    }
                } else {
                    if (self.progressView) {
                        [self.progressView showError:@"Failed to save"];
                    }
                    SCIInvokeDownloadCompletion(self, nil, error ?: SCIDownloadErrorWithDescription(@"Failed to save", 3));
                    SCIReleaseActiveDownloadDelegate(self);
                }
            }];
            return;
        }

        if (self.action == saveToGallery) {
            [self.progressView updateProgressTitle:@"Saving to Gallery" subtitle:nil];
            [self.progressView setProgress:0.98f animated:YES];
            NSError *error;
            SCIGalleryFile *file = [[self class] saveFileURLToGallery:newURL metadata:galleryMeta error:&error];
            if (file) {
                [self showCompletionPillWithSubtitle:@"Saved to Gallery successfully" completionImmediately:NO completion:^{
                    SCIInvokeDownloadCompletion(self, newURL, nil);
                    SCIReleaseActiveDownloadDelegate(self);
                }];
                if (self.progressView) {
                    self.progressView.onTapWhenCompleted = ^{
                        [SCIGalleryViewController presentGallery];
                    };
                }
            } else {
                if (self.progressView) {
                    [self.progressView showError:@"Failed to save to Gallery"];
                }
                SCIInvokeDownloadCompletion(self, nil, error ?: SCIDownloadErrorWithDescription(@"Failed to save to Gallery", 4));
                SCIReleaseActiveDownloadDelegate(self);
            }
            return;
        }

        [self showCompletionPillWithSubtitle:@"Opened successfully" completionImmediately:YES completion:^{
            [SCIFullScreenMediaPlayer showFileURL:newURL];
            SCIInvokeDownloadCompletion(self, newURL, nil);
        }];
        SCIReleaseActiveDownloadDelegate(self);
    });
}

@end
