#import <UIKit/UIKit.h>

@class SCIGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

/// Full editor for `SCIGallerySaveMetadata` (same fields as saves from Instagram). Mutates the passed object.
@interface SCIGalleryImportMetadataFormViewController : UITableViewController

@property (nonatomic, strong) SCIGallerySaveMetadata *metadata;
@property (nonatomic, copy, nullable) NSString *footerStemExplanation;

@end

NS_ASSUME_NONNULL_END
