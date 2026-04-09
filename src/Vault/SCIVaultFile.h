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

+ (nullable SCIVaultFile *)saveFileToVault:(NSURL *)fileURL
                                    source:(SCIVaultSource)source
                                 mediaType:(SCIVaultMediaType)mediaType
                                     error:(NSError **)error;

- (BOOL)removeWithError:(NSError *_Nullable *_Nullable)error;

- (NSString *)filePath;
- (NSURL *)fileURL;
- (BOOL)fileExists;
- (NSString *)thumbnailPath;
- (BOOL)thumbnailExists;

+ (void)generateThumbnailForFile:(SCIVaultFile *)file
                      completion:(void(^_Nullable)(BOOL success))completion;

+ (nullable UIImage *)loadThumbnailForFile:(SCIVaultFile *)file;

@end

NS_ASSUME_NONNULL_END
