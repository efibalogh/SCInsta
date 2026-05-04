#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Optional context when saving to the gallery (e.g. from the action button).
/// `source` uses the same values as `SCIGallerySource` in SCIGalleryFile.
@interface SCIGallerySaveMetadata : NSObject

@property (nonatomic, copy, nullable) NSString *sourceUsername;
@property (nonatomic, copy, nullable) NSString *sourceUserPK;
@property (nonatomic, copy, nullable) NSString *sourceProfileURLString;
@property (nonatomic, copy, nullable) NSString *sourceMediaPK;
@property (nonatomic, copy, nullable) NSString *sourceMediaCode;
@property (nonatomic, copy, nullable) NSString *sourceMediaURLString;
@property (nonatomic, assign) int16_t source;

/// If > 0, overrides probed dimensions from the file.
@property (nonatomic, assign) int32_t pixelWidth;
@property (nonatomic, assign) int32_t pixelHeight;

/// If > 0 for video, overrides probed duration (seconds).
@property (nonatomic, assign) double durationSeconds;

/// When set (and `sourceUsername` is empty), used as the basename segment for `SCIFileNameForMedia` instead of the picked file’s name — useful for imports whose URL name does not match the usual save pattern.
@property (nonatomic, copy, nullable) NSString *importFileNameStem;

/// Stored on `SCIGalleryFile.customName` for list/grid display.
@property (nonatomic, copy, nullable) NSString *customName;

@end

NS_ASSUME_NONNULL_END
