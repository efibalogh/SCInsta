// Reusable wrapper for Instagram private API calls.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^SCIAPICompletion)(NSDictionary * _Nullable response, NSError * _Nullable error);
typedef void(^SCIAPIStatusesCompletion)(NSDictionary * _Nullable statuses, NSError * _Nullable error);

@interface SCIInstagramAPI : NSObject

// `path` is the part after /api/v1/, e.g. "friendships/show/123/".
// `body` is form-encoded if non-nil. `completion` runs on the main queue.
+ (void)sendRequestWithMethod:(NSString *)method
                         path:(NSString *)path
                         body:(nullable NSDictionary *)body
                   completion:(nullable SCIAPICompletion)completion;

+ (void)followUserPK:(NSString *)pk completion:(nullable SCIAPICompletion)completion;
+ (void)unfollowUserPK:(NSString *)pk completion:(nullable SCIAPICompletion)completion;

+ (void)fetchFriendshipStatusesForPKs:(NSArray<NSString *> *)pks
                           completion:(nullable SCIAPIStatusesCompletion)completion;

@end

NS_ASSUME_NONNULL_END
