#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Optional context when saving to the vault (e.g. from the action button). Drives list UI like Regram.
/// `source` uses the same values as `SCIVaultSource` in SCIVaultFile.
@interface SCIVaultSaveMetadata : NSObject

@property (nonatomic, copy, nullable) NSString *sourceUsername;
@property (nonatomic, assign) int16_t source;

/// If > 0, overrides probed dimensions from the file.
@property (nonatomic, assign) int32_t pixelWidth;
@property (nonatomic, assign) int32_t pixelHeight;

/// If > 0 for video, overrides probed duration (seconds).
@property (nonatomic, assign) double durationSeconds;

@end

NS_ASSUME_NONNULL_END
