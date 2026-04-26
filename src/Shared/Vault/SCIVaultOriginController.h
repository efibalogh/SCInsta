#import <Foundation/Foundation.h>

@class SCIVaultFile;
@class SCIVaultSaveMetadata;

NS_ASSUME_NONNULL_BEGIN

@interface SCIVaultOriginController : NSObject

+ (void)populateMetadata:(SCIVaultSaveMetadata *)metadata fromMedia:(id _Nullable)media;
+ (void)populateProfileMetadata:(SCIVaultSaveMetadata *)metadata username:(nullable NSString *)username user:(id _Nullable)user;
+ (BOOL)openOriginalPostForVaultFile:(SCIVaultFile *)file;
+ (BOOL)openProfileForVaultFile:(SCIVaultFile *)file;

@end

NS_ASSUME_NONNULL_END
