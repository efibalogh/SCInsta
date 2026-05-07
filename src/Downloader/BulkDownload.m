#import "BulkDownload.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "Download.h"
#import "../AssetUtils.h"
#import "../Utils.h"
#import "../Shared/Gallery/SCIGalleryFile.h"
#import "../Shared/Gallery/SCIGallerySaveMetadata.h"

@interface SCIBulkDownloadCoordinator ()

@property (nonatomic, assign) SCIBulkDownloadOperation operation;
@property (nonatomic, copy) NSArray<SCIBulkDownloadItem *> *items;
@property (nonatomic, copy) NSString *actionIdentifier;
@property (nonatomic, weak, nullable) UIViewController *presenter;
@property (nonatomic, weak, nullable) UIView *anchorView;
@property (nonatomic, strong, nullable) SCIFeedbackPillView *progressView;
@property (nonatomic, strong, nullable) SCIDownloadDelegate *currentDownloadDelegate;
@property (nonatomic, strong) NSMutableArray<NSURL *> *resolvedFileURLs;
@property (nonatomic, strong) NSMutableArray<SCIBulkDownloadItem *> *resolvedItems;
@property (nonatomic, assign) NSUInteger currentIndex;
@property (nonatomic, assign) NSUInteger successCount;
@property (nonatomic, assign) NSUInteger failureCount;
@property (nonatomic, assign) BOOL cancelled;

@end

@implementation SCIBulkDownloadItem

+ (instancetype)itemWithURL:(NSURL *)url
              fileExtension:(NSString *)fileExtension
                    isVideo:(BOOL)isVideo
                   metadata:(SCIGallerySaveMetadata *)metadata
                 linkString:(NSString *)linkString {
    SCIBulkDownloadItem *item = [[self alloc] init];
    item.fileURL = url;
    item.fileExtension = fileExtension.length > 0 ? fileExtension : url.pathExtension;
    item.video = isVideo;
    item.galleryMetadata = metadata;
    item.linkString = linkString.length > 0 ? linkString : url.absoluteString;
    return item;
}

+ (instancetype)itemWithImage:(UIImage *)image metadata:(SCIGallerySaveMetadata *)metadata {
    SCIBulkDownloadItem *item = [[self alloc] init];
    item.image = image;
    item.fileExtension = @"png";
    item.video = NO;
    item.galleryMetadata = metadata;
    return item;
}

@end

@implementation SCIBulkDownloadCoordinator

static NSMutableSet<SCIBulkDownloadCoordinator *> *SCIActiveBulkCoordinators(void) {
    static NSMutableSet<SCIBulkDownloadCoordinator *> *coordinators = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coordinators = [NSMutableSet set];
    });
    return coordinators;
}

static void SCIRetainBulkCoordinator(SCIBulkDownloadCoordinator *coordinator) {
    @synchronized (SCIActiveBulkCoordinators()) {
        [SCIActiveBulkCoordinators() addObject:coordinator];
    }
}

static void SCIReleaseBulkCoordinator(SCIBulkDownloadCoordinator *coordinator) {
    @synchronized (SCIActiveBulkCoordinators()) {
        [SCIActiveBulkCoordinators() removeObject:coordinator];
    }
}

static NSString *SCIBulkOperationProgressTitle(SCIBulkDownloadOperation operation) {
    switch (operation) {
        case SCIBulkDownloadOperationSaveToPhotos: return @"Saving to Photos";
        case SCIBulkDownloadOperationSaveToGallery: return @"Saving to Gallery";
        case SCIBulkDownloadOperationShare: return @"Preparing share";
        case SCIBulkDownloadOperationCopyMedia: return @"Copying media";
    }
}

static NSString *SCIBulkOperationCompletionTitle(SCIBulkDownloadOperation operation, NSUInteger successCount) {
    switch (operation) {
        case SCIBulkDownloadOperationSaveToPhotos:
            return [NSString stringWithFormat:@"Saved %lu item%@ to Photos", (unsigned long)successCount, successCount == 1 ? @"" : @"s"];
        case SCIBulkDownloadOperationSaveToGallery:
            return [NSString stringWithFormat:@"Saved %lu item%@ to Gallery", (unsigned long)successCount, successCount == 1 ? @"" : @"s"];
        case SCIBulkDownloadOperationShare:
            return @"Opened share sheet";
        case SCIBulkDownloadOperationCopyMedia:
            return [NSString stringWithFormat:@"Copied %lu item%@ to clipboard", (unsigned long)successCount, successCount == 1 ? @"" : @"s"];
    }
}

static NSString *SCIBulkOperationCancelTitle(SCIBulkDownloadOperation operation) {
    switch (operation) {
        case SCIBulkDownloadOperationSaveToPhotos: return @"Save to Photos cancelled";
        case SCIBulkDownloadOperationSaveToGallery: return @"Save to Gallery cancelled";
        case SCIBulkDownloadOperationShare: return @"Share cancelled";
        case SCIBulkDownloadOperationCopyMedia: return @"Copy cancelled";
    }
}

static UIViewController *SCIBulkPresenter(UIViewController *presenter) {
    if (presenter.presentedViewController) {
        return presenter.presentedViewController;
    }
    return presenter ?: topMostController();
}

static UTType *SCIBulkUTTypeForFileURL(NSURL *fileURL, BOOL isVideo) {
    UTType *type = nil;
    if (fileURL.pathExtension.length > 0) {
        type = [UTType typeWithFilenameExtension:fileURL.pathExtension];
    }
    if (type) return type;
    return isVideo ? UTTypeMPEG4Movie : UTTypePNG;
}

static NSURL *SCIBulkPreparedFileURLForItem(SCIBulkDownloadItem *item, NSURL *fileURL) {
    if (!fileURL.isFileURL) return fileURL;

    SCIGalleryMediaType mediaType = item.video ? SCIGalleryMediaTypeVideo : SCIGalleryMediaTypeImage;
    NSString *fileName = SCIFileNameForMedia(fileURL, mediaType, item.galleryMetadata);
    if ([fileURL.lastPathComponent isEqualToString:fileName]) {
        return fileURL;
    }

    NSURL *targetURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtURL:targetURL error:nil];
    NSError *copyError = nil;
    if ([fm copyItemAtURL:fileURL toURL:targetURL error:&copyError]) {
        return targetURL;
    }
    NSLog(@"[SCInsta BulkDownload] Failed preparing named file %@: %@", targetURL.path, copyError);
    return fileURL;
}

+ (void)performOperation:(SCIBulkDownloadOperation)operation
                   items:(NSArray<SCIBulkDownloadItem *> *)items
        actionIdentifier:(NSString *)actionIdentifier
               presenter:(UIViewController *)presenter
              anchorView:(UIView *)anchorView {
    NSMutableArray<SCIBulkDownloadItem *> *validItems = [NSMutableArray array];
    for (SCIBulkDownloadItem *item in items) {
        if (![item isKindOfClass:[SCIBulkDownloadItem class]]) continue;
        if (item.image || item.fileURL) {
            [validItems addObject:item];
        }
    }
    if (validItems.count == 0) {
        [SCIUtils showToastForActionIdentifier:actionIdentifier
                                      duration:2.0
                                         title:@"No downloadable media"
                                      subtitle:nil
                                  iconResource:@"error_filled"
                                          tone:SCIFeedbackPillToneError];
        return;
    }

    SCIBulkDownloadCoordinator *coordinator = [[self alloc] init];
    coordinator.operation = operation;
    coordinator.items = [validItems copy];
    coordinator.actionIdentifier = actionIdentifier.length > 0 ? actionIdentifier : @"download";
    coordinator.presenter = presenter;
    coordinator.anchorView = anchorView;
    coordinator.resolvedFileURLs = [NSMutableArray array];
    coordinator.resolvedItems = [NSMutableArray array];
    SCIRetainBulkCoordinator(coordinator);
    [coordinator start];
}

- (void)start {
    if ([SCIUtils shouldShowFeedbackPillForActionIdentifier:self.actionIdentifier]) {
        self.progressView = [SCIUtils showProgressPill];
        __weak typeof(self) weakSelf = self;
        self.progressView.onCancel = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.cancelled = YES;
            [strongSelf.currentDownloadDelegate.downloadManager cancelDownload];
        };
        [self updateProgress];
    }
    [self processNextItem];
}

- (void)updateProgress {
    if (!self.progressView) return;
    NSUInteger total = self.items.count;
    NSUInteger completed = MIN(self.currentIndex, total);
    float progress = total > 0 ? (float)completed / (float)total : 0.0f;
    [self.progressView setProgress:progress animated:YES];
    NSString *title = [NSString stringWithFormat:@"%@ %lu of %lu",
                       SCIBulkOperationProgressTitle(self.operation),
                       (unsigned long)MIN(completed + 1, total),
                       (unsigned long)total];
    [self.progressView showInfoWithTitle:title subtitle:@"Tap to cancel" icon:[SCIAssetUtils instagramIconNamed:@"download_all" pointSize:18.0]];
}

- (void)processNextItem {
    if (self.cancelled) {
        [self finishCancelled];
        return;
    }

    if (self.currentIndex >= self.items.count) {
        [self finalizeOperation];
        return;
    }

    [self updateProgress];
    SCIBulkDownloadItem *item = self.items[self.currentIndex];
    [self resolveLocalFileForItem:item completion:^(NSURL *fileURL, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentDownloadDelegate = nil;
            if (self.cancelled) {
                [self finishCancelled];
                return;
            }

            if (fileURL) {
                [self handleResolvedLocalFile:fileURL forItem:item];
            } else {
                self.failureCount += 1;
                self.currentIndex += 1;
                [self processNextItem];
            }
            (void)error;
        });
    }];
}

- (void)resolveLocalFileForItem:(SCIBulkDownloadItem *)item completion:(void(^)(NSURL * _Nullable fileURL, NSError * _Nullable error))completion {
    if (item.image && !item.fileURL) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSData *data = UIImagePNGRepresentation(item.image);
            if (!data) {
                completion(nil, [NSError errorWithDomain:@"SCInsta.BulkDownload" code:10 userInfo:@{NSLocalizedDescriptionKey: @"Unable to encode image"}]);
                return;
            }

            NSString *filename = SCIFileNameForMedia([NSURL fileURLWithPath:@"bulk.png"], SCIGalleryMediaTypeImage, item.galleryMetadata);
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
            NSURL *url = [NSURL fileURLWithPath:path];
            NSError *writeError = nil;
            if (![data writeToURL:url options:NSDataWritingAtomic error:&writeError]) {
                completion(nil, writeError);
                return;
            }
            completion(url, nil);
        });
        return;
    }

    NSURL *url = item.fileURL;
    if (url.isFileURL) {
        completion(url, nil);
        return;
    }

    NSString *extension = item.fileExtension.length > 0 ? item.fileExtension : (item.video ? @"mp4" : @"jpg");
    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:downloadOnly showProgress:NO];
    self.currentDownloadDelegate = delegate;
    delegate.pendingGallerySaveMetadata = item.galleryMetadata;
    delegate.completionBlock = ^(NSURL *fileURL, NSError *error) {
        completion(fileURL, error);
    };
    [delegate downloadFileWithURL:url fileExtension:extension hudLabel:nil];
}

- (void)handleResolvedLocalFile:(NSURL *)fileURL forItem:(SCIBulkDownloadItem *)item {
    NSURL *preparedURL = SCIBulkPreparedFileURLForItem(item, fileURL);
    if (self.operation == SCIBulkDownloadOperationSaveToPhotos) {
        [SCIDownloadDelegate saveFileURLToPhotos:preparedURL completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) self.successCount += 1;
                else self.failureCount += 1;
                self.currentIndex += 1;
                [self processNextItem];
                (void)error;
            });
        }];
        return;
    }

    if (self.operation == SCIBulkDownloadOperationSaveToGallery) {
        NSError *saveError = nil;
        SCIGalleryFile *file = [SCIDownloadDelegate saveFileURLToGallery:preparedURL metadata:item.galleryMetadata error:&saveError];
        if (file) self.successCount += 1;
        else self.failureCount += 1;
        self.currentIndex += 1;
        [self processNextItem];
        return;
    }

    [self.resolvedFileURLs addObject:preparedURL];
    [self.resolvedItems addObject:item];
    self.successCount += 1;
    self.currentIndex += 1;
    [self processNextItem];
}

- (void)finalizeOperation {
    if (self.operation == SCIBulkDownloadOperationShare) {
        [self finalizeShareOperation];
        return;
    }

    if (self.operation == SCIBulkDownloadOperationCopyMedia) {
        [self finalizeCopyMediaOperation];
        return;
    }

    if (self.successCount == 0) {
        [self finishWithError:@"No items were processed"];
        return;
    }

    NSString *subtitle = self.failureCount > 0
        ? [NSString stringWithFormat:@"%lu failed", (unsigned long)self.failureCount]
        : nil;
    [self finishWithSuccessTitle:SCIBulkOperationCompletionTitle(self.operation, self.successCount) subtitle:subtitle];
}

- (void)finalizeShareOperation {
    if (self.resolvedFileURLs.count == 0) {
        [self finishWithError:@"No items available to share"];
        return;
    }

    UIViewController *presenter = SCIBulkPresenter(self.presenter);
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:self.resolvedFileURLs applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIView *sourceView = self.anchorView ?: presenter.view;
        activityController.popoverPresentationController.sourceView = sourceView;
        activityController.popoverPresentationController.sourceRect = sourceView.bounds;
    }
    [presenter presentViewController:activityController animated:YES completion:nil];

    NSString *subtitle = self.failureCount > 0
        ? [NSString stringWithFormat:@"%lu failed", (unsigned long)self.failureCount]
        : nil;
    [self finishWithSuccessTitle:SCIBulkOperationCompletionTitle(self.operation, self.successCount) subtitle:subtitle];
}

- (void)finalizeCopyMediaOperation {
    if (self.resolvedFileURLs.count == 0) {
        [self finishWithError:@"No items available to copy"];
        return;
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *pasteboardItems = [NSMutableArray array];
    [self.resolvedFileURLs enumerateObjectsUsingBlock:^(NSURL *fileURL, NSUInteger idx, BOOL *stop) {
        NSData *data = [NSData dataWithContentsOfURL:fileURL];
        if (!data) return;

        BOOL isVideo = idx < self.resolvedItems.count ? self.resolvedItems[idx].video : [SCIDownloadDelegate isVideoFileAtURL:fileURL];
        UTType *type = SCIBulkUTTypeForFileURL(fileURL, isVideo);
        if (!type.identifier.length) return;
        [pasteboardItems addObject:@{ type.identifier: data }];
    }];

    if (pasteboardItems.count == 0) {
        [self finishWithError:@"No items available to copy"];
        return;
    }

    [UIPasteboard generalPasteboard].items = pasteboardItems;
    NSString *subtitle = self.failureCount > 0
        ? [NSString stringWithFormat:@"%lu failed", (unsigned long)self.failureCount]
        : nil;
    [self finishWithSuccessTitle:SCIBulkOperationCompletionTitle(self.operation, pasteboardItems.count) subtitle:subtitle];
}

- (void)finishCancelled {
    if (self.progressView) {
        [self.progressView showErrorWithTitle:SCIBulkOperationCancelTitle(self.operation) subtitle:nil icon:[SCIAssetUtils instagramIconNamed:@"error_filled" pointSize:18.0]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.progressView dismiss];
        });
    }
    SCIReleaseBulkCoordinator(self);
}

- (void)finishWithSuccessTitle:(NSString *)title subtitle:(NSString *)subtitle {
    if (self.progressView) {
        [self.progressView showSuccessWithTitle:title subtitle:subtitle icon:[SCIAssetUtils instagramIconNamed:@"circle_check_filled" pointSize:18.0 renderingMode:UIImageRenderingModeAlwaysOriginal]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.progressView dismiss];
        });
    } else {
        [SCIUtils showToastForActionIdentifier:self.actionIdentifier
                                      duration:1.8
                                         title:title
                                      subtitle:subtitle
                                  iconResource:@"circle_check_filled"
                                          tone:SCIFeedbackPillToneSuccess];
    }
    SCIReleaseBulkCoordinator(self);
}

- (void)finishWithError:(NSString *)message {
    if (self.progressView) {
        [self.progressView showErrorWithTitle:@"Bulk action failed" subtitle:message icon:[SCIAssetUtils instagramIconNamed:@"error_filled" pointSize:18.0 renderingMode:UIImageRenderingModeAlwaysOriginal]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.progressView dismiss];
        });
    } else {
        [SCIUtils showToastForActionIdentifier:self.actionIdentifier
                                      duration:2.0
                                         title:@"Bulk action failed"
                                      subtitle:message
                                  iconResource:@"error_filled"
                                          tone:SCIFeedbackPillToneError];
    }
    SCIReleaseBulkCoordinator(self);
}

@end
