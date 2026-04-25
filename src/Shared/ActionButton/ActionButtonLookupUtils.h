#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

id SCIObjectForSelector(id target, NSString *selectorName);
id SCIKVCObject(id target, NSString *key);
NSArray *SCIArrayFromCollection(id collection);
NSURL *SCIURLFromValue(id value);
NSString *SCIStringFromValue(id value);
NSString *SCIClassName(id object);

NSString *SCIUsernameFromMediaObject(id media);
NSString *SCISessionUsernameFromController(UIViewController *controller);

id SCIDirectCurrentMessageFromController(UIViewController *controller);
id SCIDirectResolvedMediaFromController(UIViewController *controller);
NSInteger SCIDirectCurrentIndexFromController(UIViewController *controller);
NSString *SCIDirectUsernameFromController(UIViewController *controller);

#ifdef __cplusplus
}
#endif
