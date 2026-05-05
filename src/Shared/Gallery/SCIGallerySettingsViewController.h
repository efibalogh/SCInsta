#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Read-only gallery settings page: storage stats, lock configuration, clear gallery,
/// delete by type / source.
@interface SCIGallerySettingsViewController : UITableViewController

/// Destination folder for imports from Settings (same as current gallery folder when opened from the gallery).
@property (nonatomic, copy, nullable) NSString *importDestinationFolderPath;

@end

NS_ASSUME_NONNULL_END
