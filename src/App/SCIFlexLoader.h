#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

FOUNDATION_EXPORT BOOL SCIFlexIsBundled(void);
FOUNDATION_EXPORT BOOL SCIFlexIsLoaded(void);
FOUNDATION_EXPORT BOOL SCIFlexLoadIfNeeded(void);
FOUNDATION_EXPORT void SCIFlexShowExplorer(NSString *trigger);
FOUNDATION_EXPORT Class _Nullable SCIFlexWindowClass(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
