#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int16_t, SCIVaultMediaType) {
    SCIVaultMediaTypeImage = 0,
    SCIVaultMediaTypeVideo = 1
};

typedef NS_ENUM(int16_t, SCIVaultSource) {
    SCIVaultSourceOther   = 0,
    SCIVaultSourceFeed    = 1,
    SCIVaultSourceStories = 2,
    SCIVaultSourceReels   = 3,
    SCIVaultSourceProfile = 4,
    SCIVaultSourceDMs     = 5
};

@interface SCIVaultFile : NSManagedObject

@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *relativePath;
@property (nonatomic) int16_t mediaType;
@property (nonatomic) int16_t source;
@property (nonatomic, strong) NSDate *dateAdded;
@property (nonatomic) int64_t fileSize;
@property (nonatomic) BOOL isFavorite;
@property (nonatomic, copy, nullable) NSString *folderPath;
@property (nonatomic, copy, nullable) NSString *customName;

+ (nullable SCIVaultFile *)saveFileToVault:(NSURL *)fileURL
                                    source:(SCIVaultSource)source
                                 mediaType:(SCIVaultMediaType)mediaType
                                     error:(NSError **)error;

/// Convenience: adds to vault inside the given folder.
+ (nullable SCIVaultFile *)saveFileToVault:(NSURL *)fileURL
                                    source:(SCIVaultSource)source
                                 mediaType:(SCIVaultMediaType)mediaType
                                folderPath:(nullable NSString *)folderPath
                                     error:(NSError **)error;

- (BOOL)removeWithError:(NSError *_Nullable *_Nullable)error;

- (NSString *)filePath;
- (NSURL *)fileURL;
- (BOOL)fileExists;
- (NSString *)thumbnailPath;
- (BOOL)thumbnailExists;

/// User-facing display name — customName if set, else the portion of relativePath after the timestamp prefix.
- (NSString *)displayName;

/// Human-readable label for the source type.
- (NSString *)sourceLabel;

+ (void)generateThumbnailForFile:(SCIVaultFile *)file
                      completion:(void(^_Nullable)(BOOL success))completion;

+ (nullable UIImage *)loadThumbnailForFile:(SCIVaultFile *)file;

/// Returns a human-readable label for the given source.
+ (NSString *)labelForSource:(SCIVaultSource)source;

/// Returns the symbol name for the given source.
+ (NSString *)symbolNameForSource:(SCIVaultSource)source;

@end

NS_ASSUME_NONNULL_END
