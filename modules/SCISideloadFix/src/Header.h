#import <Foundation/Foundation.h>

extern NSString *accessGroupId;
extern NSString *bundleId;

extern void rebindSecFuncs();

extern BOOL createDirectoryIfNotExists(NSString *path);
extern NSURL *getAppGroupPathIfExists();

@interface LSBundleProxy: NSObject
@property(nonatomic, assign, readonly) NSDictionary *entitlements;
@property(nonatomic, assign, readonly) NSDictionary *groupContainerURLs;
+ (instancetype)bundleProxyForCurrentProcess;
@end
