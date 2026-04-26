#import <Foundation/Foundation.h>

@class SCISetting;

@interface SCIInterfaceSettingsProvider : NSObject
+ (SCISetting *)rootSetting;
+ (SCISetting *)experimentalLiquidGlassSetting;
@end
