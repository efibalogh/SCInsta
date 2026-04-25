#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SCIMediaItem;

NS_ASSUME_NONNULL_BEGIN

@interface SCIMediaCacheManager : NSObject

+ (instancetype)sharedManager;

- (nullable NSURL *)bestAvailableFileURLForItem:(SCIMediaItem *)item;
- (nullable NSURL *)cachedFileURLForRemoteURL:(NSURL *)url;

- (void)fetchLocalFileURLForItem:(SCIMediaItem *)item
                      completion:(void (^)(NSURL * _Nullable localURL, NSError * _Nullable error))completion;

- (void)loadImageForItem:(SCIMediaItem *)item
              completion:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion;

- (void)loadThumbnailForVideoItem:(SCIMediaItem *)item
                       completion:(void (^)(UIImage * _Nullable image))completion;

- (void)prefetchItem:(SCIMediaItem *)item;

@end

NS_ASSUME_NONNULL_END
