#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if STARTUP_PROFILING
#ifdef __cplusplus
extern "C" {
#endif
FOUNDATION_EXPORT void SCIStartupMark(NSString *event);
#ifdef __cplusplus
}
#endif
#else
static inline void SCIStartupMark(__unused NSString *event) {}
#endif

NS_ASSUME_NONNULL_END
