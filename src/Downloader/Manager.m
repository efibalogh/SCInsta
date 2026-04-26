#import "Manager.h"
#import "../Utils.h"
#import <math.h>

@interface SCIDownloadManager ()
@property (nonatomic, assign) float lastReportedProgress;
@end

@implementation SCIDownloadManager

- (instancetype)initWithDelegate:(id<SCIDownloadDelegateProtocol>)downloadDelegate {
    self = [super init];
    
    if (self) {
        self.delegate = downloadDelegate;
    }

    return self;
}

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension {
    // Properties
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    self.task = [self.session downloadTaskWithURL:url];
    self.lastReportedProgress = 0.0f;
    
    // Default to jpg if no other reasonable length extension is provided
    self.fileExtension = [fileExtension length] >= 3 ? fileExtension : @"jpg";

    [self.task resume];
    [self.delegate downloadDidStart];
}

- (void)cancelDownload {
    [self.task cancel];
    self.lastReportedProgress = 0.0f;
    [self.delegate downloadDidCancel];
    [self.session invalidateAndCancel];
    self.task = nil;
    self.session = nil;
}

- (float)normalizedProgressForBytesWritten:(int64_t)bytesWritten
                         totalBytesWritten:(int64_t)totalBytesWritten
                        expectedTotalBytes:(int64_t)expectedTotalBytes {
    if (expectedTotalBytes > 0) {
        float progress = (float)totalBytesWritten / (float)expectedTotalBytes;
        if (!isfinite(progress)) {
            return self.lastReportedProgress;
        }
        return fminf(1.0f, fmaxf(0.0f, progress));
    }

    if (totalBytesWritten <= 0) {
        return self.lastReportedProgress;
    }

    float chunkBytes = (float)MAX((int64_t)1, bytesWritten);
    float delta = fminf(0.06f, fmaxf(0.008f, chunkBytes / 524288.0f));
    return fminf(0.95f, fmaxf(self.lastReportedProgress, self.lastReportedProgress + delta));
}

// URLSession methods
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSLog(@"Task wrote %lld bytes of %lld bytes", bytesWritten, totalBytesExpectedToWrite);

    int64_t effectiveExpectedBytes = totalBytesExpectedToWrite;
    if (effectiveExpectedBytes <= 0 && downloadTask.countOfBytesExpectedToReceive > 0) {
        effectiveExpectedBytes = downloadTask.countOfBytesExpectedToReceive;
    }

    float progress = [self normalizedProgressForBytesWritten:bytesWritten
                                           totalBytesWritten:totalBytesWritten
                                          expectedTotalBytes:effectiveExpectedBytes];
    self.lastReportedProgress = progress;

    [self.delegate downloadDidProgress:progress];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {    
    self.lastReportedProgress = 1.0f;
    [self.delegate downloadDidProgress:1.0f];

    // Move downloaded file to cache directory
    NSURL *finalLocation = [self moveFileToCacheDir:location];
    if (!finalLocation) {
        [self.delegate downloadDidFinishWithError:[SCIUtils errorWithDescription:@"Failed to move downloaded file"]];
        return;
    }

    [self.delegate downloadDidFinishWithFileURL:finalLocation];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"Task completed with error: %@", error);
    if (error) {
        self.lastReportedProgress = 0.0f;
        [self.delegate downloadDidFinishWithError:error];
    }
    [self.session finishTasksAndInvalidate];
    self.task = nil;
    self.session = nil;
}

// Rename downloaded file & move from documents dir -> cache dir
- (NSURL *)moveFileToCacheDir:(NSURL *)oldPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *cacheDirectoryPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSURL *newPath = [[NSURL fileURLWithPath:cacheDirectoryPath] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, self.fileExtension]];
    
    NSLog(@"[SCInsta] Download Handler: Moving file from: %@ to: %@", oldPath.absoluteString, newPath.absoluteString);

    // Move file to cache directory
    NSError *fileMoveError;
    [fileManager moveItemAtURL:oldPath toURL:newPath error:&fileMoveError];

    if (fileMoveError) {
        NSLog(@"[SCInsta] Download Handler: Error while moving file: %@", oldPath.absoluteString);
        NSLog(@"[SCInsta] Download Handler: %@", fileMoveError);
        return nil;
    }

    return newPath;
}

@end
