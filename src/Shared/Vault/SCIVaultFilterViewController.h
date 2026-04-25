#import <UIKit/UIKit.h>
#import "SCIVaultFile.h"

NS_ASSUME_NONNULL_BEGIN

@class SCIVaultFilterViewController;

@protocol SCIVaultFilterViewControllerDelegate <NSObject>
- (void)filterController:(SCIVaultFilterViewController *)controller
           didApplyTypes:(NSSet<NSNumber *> *)types
                 sources:(NSSet<NSNumber *> *)sources
           favoritesOnly:(BOOL)favoritesOnly;

- (void)filterControllerDidClear:(SCIVaultFilterViewController *)controller;
@end

/// Sheet controller for filtering the vault by type, source and favorites.
///
/// If `filterTypes` is empty, no type filter is applied. Same for `filterSources`.
@interface SCIVaultFilterViewController : UIViewController

@property (nonatomic, weak) id<SCIVaultFilterViewControllerDelegate> delegate;

@property (nonatomic, strong) NSMutableSet<NSNumber *> *filterTypes;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *filterSources;
@property (nonatomic, assign) BOOL filterFavoritesOnly;

/// Composes an NSPredicate from the given filters, or nil if no filters are active.
+ (nullable NSPredicate *)predicateForTypes:(NSSet<NSNumber *> *)types
                                    sources:(NSSet<NSNumber *> *)sources
                              favoritesOnly:(BOOL)favoritesOnly
                                 folderPath:(nullable NSString *)folderPath;

@end

NS_ASSUME_NONNULL_END
