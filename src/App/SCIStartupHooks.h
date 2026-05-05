#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs optional feature hooks after SCInsta defaults have been registered.
/// Installers must be idempotent and avoid constructing feature UI or opening persistent stores.
FOUNDATION_EXPORT void SCIInstallEnabledFeatureHooks(void);
FOUNDATION_EXPORT void SCIInstallLaunchCriticalHooks(void);
FOUNDATION_EXPORT void SCIInstallFeedSurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallStorySurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallReelsSurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallMessagesSurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallProfileSurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallGeneralUIHooksIfNeeded(void);

NS_ASSUME_NONNULL_END
