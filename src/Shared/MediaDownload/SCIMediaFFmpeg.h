#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SCIMediaFFmpegProgressBlock)(double progress, NSString *stage);
typedef void (^SCIMediaFFmpegCompletionBlock)(NSURL * _Nullable outputURL, NSError * _Nullable error);
typedef void (^SCIMediaFFmpegCancelBlockPublisher)(dispatch_block_t cancelBlock);

@interface SCIMediaFFmpeg : NSObject

+ (BOOL)isAvailable;
+ (void)cancelAll;
+ (void)shareLogsFromViewController:(nullable UIViewController *)controller;
+ (UIViewController *)logsViewController;

+ (void)mergeVideoFileURL:(NSURL *)videoFileURL
             audioFileURL:(nullable NSURL *)audioFileURL
          preferredBasename:(NSString *)preferredBasename
           estimatedDuration:(NSTimeInterval)estimatedDuration
                     width:(NSInteger)width
                    height:(NSInteger)height
             sourceBitrate:(NSInteger)sourceBitrate
                  progress:(nullable SCIMediaFFmpegProgressBlock)progress
                completion:(SCIMediaFFmpegCompletionBlock)completion
                 cancelOut:(nullable SCIMediaFFmpegCancelBlockPublisher)cancelOut;

+ (void)extractAudioFileURL:(NSURL *)audioFileURL
          preferredBasename:(NSString *)preferredBasename
                   progress:(nullable SCIMediaFFmpegProgressBlock)progress
                 completion:(SCIMediaFFmpegCompletionBlock)completion
                  cancelOut:(nullable SCIMediaFFmpegCancelBlockPublisher)cancelOut;

@end

NS_ASSUME_NONNULL_END
