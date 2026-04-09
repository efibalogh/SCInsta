#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

typedef NS_ENUM(NSUInteger, SCIMediaType) {
    SCIMediaTypePhoto,
    SCIMediaTypeVideo
};

/**
 * SCIMediaPreviewController
 *
 * A fullscreen media viewer presented modally with:
 * - Photo: zoomable UIImageView with pinch-to-zoom and double-tap
 * - Video: AVPlayer with custom play/pause and scrubber
 * - Dark blurred background
 * - Bottom action bar: Save to Photos / Share / Copy (photos only)
 * - Swipe-down to dismiss
 * - Close (×) button at top-left
 */
@interface SCIMediaPreviewController : UIViewController

- (instancetype)initWithFileURL:(NSURL *)fileURL mediaType:(SCIMediaType)type;

/// Convenience: auto-detect media type from file extension.
+ (instancetype)previewWithFileURL:(NSURL *)fileURL;

/// Convenience: present a photo carousel in the same preview controller.
+ (instancetype)previewWithPhotoURLs:(NSArray<NSURL *> *)photoURLs initialIndex:(NSInteger)initialIndex;

/// Present the preview from the top-most view controller.
+ (void)showPreviewForFileURL:(NSURL *)fileURL;

/// Present a photo carousel from the top-most view controller.
+ (void)showPreviewForPhotoURLs:(NSArray<NSURL *> *)photoURLs initialIndex:(NSInteger)initialIndex;

@end
