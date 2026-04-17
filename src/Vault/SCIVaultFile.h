#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

#import "SCIVaultSaveMetadata.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int16_t, SCIVaultMediaType) {
    SCIVaultMediaTypeImage = 0,
    SCIVaultMediaTypeVideo = 1
};

FOUNDATION_EXPORT NSString *SCIFileNameForMedia(NSURL *originalURL, SCIVaultMediaType mediaType, SCIVaultSaveMetadata * _Nullable metadata);


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
@property (nonatomic, copy, nullable) NSString *sourceUsername;
@property (nonatomic) int32_t pixelWidth;
@property (nonatomic) int32_t pixelHeight;
@property (nonatomic) double durationSeconds;

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

/// When `metadata` is non-nil, its fields override `source` and populate list UI (Regram-style). File is probed for any missing dimensions/duration.
+ (nullable SCIVaultFile *)saveFileToVault:(NSURL *)fileURL
                                    source:(SCIVaultSource)source
                                 mediaType:(SCIVaultMediaType)mediaType
                                folderPath:(nullable NSString *)folderPath
                                  metadata:(nullable SCIVaultSaveMetadata *)metadata
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

/// Short label for origin pill (e.g. Reel, Feed).
- (NSString *)shortSourceLabel;

/// Primary line in list mode: username when known, else `displayName`.
- (NSString *)listPrimaryTitle;

/// Second line: duration · size · resolution · bitrate (video), or size · resolution (image).
- (NSString *)listTechnicalLine;

/// Third line: human-readable download date (e.g. Apr 17 at 2:04 AM).
- (NSString *)listDownloadDateString;

+ (NSString *)shortLabelForSource:(SCIVaultSource)source;

+ (void)generateThumbnailForFile:(SCIVaultFile *)file
                      completion:(void(^_Nullable)(BOOL success))completion;

+ (nullable UIImage *)loadThumbnailForFile:(SCIVaultFile *)file;

/// Returns a human-readable label for the given source.
+ (NSString *)labelForSource:(SCIVaultSource)source;

/// Returns the symbol name for the given source.
+ (NSString *)symbolNameForSource:(SCIVaultSource)source;

@end

NS_ASSUME_NONNULL_END
