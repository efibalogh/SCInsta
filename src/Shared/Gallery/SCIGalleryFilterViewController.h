#import <UIKit/UIKit.h>
#import "SCIGalleryFile.h"

NS_ASSUME_NONNULL_BEGIN

@class SCIGalleryFilterViewController;

@protocol SCIGalleryFilterViewControllerDelegate <NSObject>
- (void)filterController:(SCIGalleryFilterViewController *)controller
           didApplyTypes:(NSSet<NSNumber *> *)types
                 sources:(NSSet<NSNumber *> *)sources
           favoritesOnly:(BOOL)favoritesOnly
                usernames:(NSSet<NSString *> *)usernames;

- (void)filterControllerDidClear:(SCIGalleryFilterViewController *)controller;
@end

/// Sheet controller for filtering the gallery by type, source and favorites.
///
/// If `filterTypes` is empty, no type filter is applied. Same for `filterSources`.
@interface SCIGalleryFilterViewController : UIViewController

@property (nonatomic, weak) id<SCIGalleryFilterViewControllerDelegate> delegate;

@property (nonatomic, strong) NSMutableSet<NSNumber *> *filterTypes;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *filterSources;
@property (nonatomic, assign) BOOL filterFavoritesOnly;
@property (nonatomic, strong) NSMutableSet<NSString *> *filterUsernames;
@property (nonatomic, copy) NSArray<NSString *> *availableUsernames;

/// Composes an NSPredicate from the given filters, or nil if no filters are active.
+ (nullable NSPredicate *)predicateForTypes:(NSSet<NSNumber *> *)types
                                    sources:(NSSet<NSNumber *> *)sources
                              favoritesOnly:(BOOL)favoritesOnly
                                   usernames:(NSSet<NSString *> *)usernames
                                 folderPath:(nullable NSString *)folderPath;

@end

NS_ASSUME_NONNULL_END
