#import "SCIGallerySettingsProvider.h"
#import "../../Utils.h"

#import "../SCISetting.h"
#import "../SCITopicSettingsSupport.h"
#import "../../Shared/Gallery/SCIGalleryViewController.h"

@implementation SCIGallerySettingsProvider

+ (SCISetting *)rootSetting {
    return [SCISetting buttonCellWithTitle:@"Gallery"
                                  subtitle:@""
                                      icon:SCISettingsInstagramIcon(@"photo_gallery", 24.0)
                                    action:^(void) {
        [SCIGalleryViewController presentGallery];
    }];
}

@end
