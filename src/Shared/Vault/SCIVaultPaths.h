#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIVaultPaths : NSObject

+ (NSString *)vaultDirectory;
+ (NSString *)vaultMediaDirectory;
+ (NSString *)vaultThumbnailsDirectory;

@end

NS_ASSUME_NONNULL_END
