#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Queue media from the Files picker, edit full `SCIGallerySaveMetadata` per file or via shared defaults, then import into the gallery folder `destinationFolderPath` (nil = root).
@interface SCIGalleryImportViewController : UITableViewController

- (instancetype)initWithDestinationFolderPath:(nullable NSString *)folderPath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStyle:(UITableViewStyle)style NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
