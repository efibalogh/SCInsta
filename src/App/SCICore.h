#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SCISurface) {
    SCISurfaceGeneralUI = 0,
    SCISurfaceFeed,
    SCISurfaceStories,
    SCISurfaceReels,
    SCISurfaceMessages,
    SCISurfaceProfile,
};

#ifdef __cplusplus
extern "C" {
#endif

FOUNDATION_EXPORT void SCICoreRegisterBootstrapDefaults(void);
FOUNDATION_EXPORT void SCICoreRegisterDefaults(void);
FOUNDATION_EXPORT void SCICoreInstallLaunchCriticalHooks(void);
FOUNDATION_EXPORT void SCICoreInstallEnabledFeatureHooks(void);
FOUNDATION_EXPORT void SCICoreInstallSurfaceHooks(SCISurface surface);
FOUNDATION_EXPORT void SCICoreShowSettingsIfNeeded(UIWindow *window);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
