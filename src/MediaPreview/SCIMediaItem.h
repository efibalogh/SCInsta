#import <UIKit/UIKit.h>

@class SCIVaultFile, SCIVaultSaveMetadata;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIMediaItemType) {
    SCIMediaItemTypeImage = 1,
    SCIMediaItemTypeVideo = 2,
};

@interface SCIMediaItem : NSObject

@property (nonatomic) SCIMediaItemType mediaType;
@property (nonatomic, strong, nullable) NSURL *fileURL;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) UIImage *thumbnail;
@property (nonatomic, copy, nullable) NSString *title;
/// When >= 0, `SCIVaultSaveMetadata.source` uses this value (`SCIVaultSource`). Default -1 = not set.
@property (nonatomic, assign) NSInteger vaultSaveSource;
@property (nonatomic, strong, nullable) SCIVaultSaveMetadata *vaultMetadata;
@property (nonatomic, strong, nullable) SCIVaultFile *vaultFile;
@property (nonatomic, assign) BOOL isFromVault;

+ (instancetype)itemWithFileURL:(NSURL *)url;
+ (instancetype)itemWithImage:(UIImage *)image;
+ (instancetype)itemWithVaultFile:(SCIVaultFile *)file;
+ (SCIMediaItemType)mediaTypeForFileExtension:(NSString *)extension;

@end

NS_ASSUME_NONNULL_END
