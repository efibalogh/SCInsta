#import <UIKit/UIKit.h>

@class SCIGalleryFile;

NS_ASSUME_NONNULL_BEGIN

/// List-style row for use inside a collection view (do not use UITableViewCell here).
@interface SCIGalleryListCollectionCell : UICollectionViewCell

- (void)configureWithGalleryFile:(SCIGalleryFile *)file
                 selectionMode:(BOOL)selectionMode
                      selected:(BOOL)selected;

- (void)setSelectionMode:(BOOL)selectionMode selected:(BOOL)selected animated:(BOOL)animated;

/// Same actions as long-press context menu on the row. Pass `nil` to clear (e.g. in `prepareForReuse`).
- (void)setMoreActionsMenu:(nullable UIMenu *)menu;

@end

NS_ASSUME_NONNULL_END
