#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs optional feature hooks after SCInsta defaults have been registered.
/// Installers must be idempotent and avoid constructing feature UI or opening persistent stores.
FOUNDATION_EXPORT void SCIInstallEnabledFeatureHooks(void);

NS_ASSUME_NONNULL_END
