#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCISettingsTransferManager : NSObject

+ (instancetype)sharedManager;
- (void)exportSettingsAndGalleryFromController:(UIViewController *)controller;
- (void)importSettingsAndGalleryFromController:(UIViewController *)controller;
- (void)presentExportOptionsFromController:(UIViewController *)controller;
- (void)presentImportOptionsFromController:(UIViewController *)controller;
- (void)exportFromController:(UIViewController *)controller includeSettings:(BOOL)includeSettings includeGallery:(BOOL)includeGallery;
- (void)importFromController:(UIViewController *)controller includeSettings:(BOOL)includeSettings includeGallery:(BOOL)includeGallery;

@end

NS_ASSUME_NONNULL_END
