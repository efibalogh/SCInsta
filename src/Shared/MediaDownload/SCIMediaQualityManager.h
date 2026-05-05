#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../../Downloader/Download.h"

@class SCIGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

@interface SCIMediaQualityManager : NSObject

+ (BOOL)handleDownloadAction:(DownloadAction)action
                  identifier:(NSString *)identifier
                   presenter:(nullable UIViewController *)presenter
                  sourceView:(nullable UIView *)sourceView
                   mediaObject:(nullable id)mediaObject
                     photoURL:(nullable NSURL *)photoURL
                     videoURL:(nullable NSURL *)videoURL
              galleryMetadata:(nullable SCIGallerySaveMetadata *)galleryMetadata
                showProgress:(BOOL)showProgress;

+ (BOOL)handleCopyActionWithIdentifier:(NSString *)identifier
                             presenter:(nullable UIViewController *)presenter
                            sourceView:(nullable UIView *)sourceView
                             mediaObject:(nullable id)mediaObject
                               photoURL:(nullable NSURL *)photoURL
                               videoURL:(nullable NSURL *)videoURL
                          showProgress:(BOOL)showProgress;

+ (UIViewController *)encodingSettingsViewController;

@end

NS_ASSUME_NONNULL_END
