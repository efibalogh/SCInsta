#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <os/log.h>
#import <objc/message.h>

#import "InstagramHeaders.h"
#import "Shared/MediaPreview/SCIFullScreenMediaPlayer.h"
#import "Shared/UI/SCIFeedbackPillView.h"

#import "Settings/SCISettingsViewController.h"

#define SCILog(fmt, ...) \
    do { \
        NSString *tmpStr = [NSString stringWithFormat:(fmt), ##__VA_ARGS__]; \
        os_log(OS_LOG_DEFAULT, "[SCInsta Test] %{public}s", tmpStr.UTF8String); \
    } while(0)

#define SCILogId(prefix, obj) os_log(OS_LOG_DEFAULT, "[SCInsta Test] %{public}@: %{public}@", prefix, obj);

@interface SCIUtils : NSObject

// Preferences
+ (BOOL)getBoolPref:(NSString *)key;
+ (double)getDoublePref:(NSString *)key;
+ (NSString *)getStringPref:(NSString *)key;

// Misc
+ (NSString *)IGVersionString;
+ (BOOL)isNotch;

+ (BOOL)existingLongPressGestureRecognizerForView:(UIView *)view;

/// Normalizes legacy `liquid_glass` into `liquid_glass_surfaces` / `liquid_glass_buttons` (runs once).
+ (void)sci_normalizeLiquidGlassPreferences;

/// IGDSLauncherConfig hooks: when the per-key pref is set and on, returns YES; when set and off, returns `fallback` (stock). When unset, the five legacy launcher keys follow Core “Enable liquid glass surfaces” like `origin/main`’s `liquidGlassEnabledBool:`; icon bar and internal debugger unset always use `fallback`.
+ (_Bool)sci_liquidGlassLauncherPrefKey:(NSString *)key orig:(_Bool)fallback;

typedef BOOL (*SCILiquidGlassBoolMsg)(id, SEL);
/// Runtime hooks: unset uses `orig`; when the pref exists and is on, returns YES.
+ (BOOL)sci_liquidGlassHookPrefKey:(NSString *)key orig:(SCILiquidGlassBoolMsg)orig selfPtr:(id)selfPtr sel:(SEL)sel;

/// True when any liquid-glass-related preference is explicitly enabled.
+ (BOOL)sci_anyLiquidGlassEnabled;

/// Calls Instagram navigation experiment override when the helper class exists.
+ (void)applyLiquidGlassNavigationExperimentOverride;

+ (void)cleanCache;
+ (NSString *)cacheAutoClearMode;
+ (BOOL)shouldAutomaticallyClearCacheNow;
+ (void)markCacheClearedNow;
+ (void)evaluateAutomaticCacheClearIfNeeded;

// Display View Controllers
+ (void)showMediaPreview:(NSURL *)fileURL;
+ (void)showShareVC:(id)item;
+ (void)showSettingsVC:(UIWindow *)window;
+ (void)showSettingsForTopicTitle:(NSString *)title;

// Colours
+ (UIColor *)SCIColor_Primary;

// Errors
+ (NSError *)errorWithDescription:(NSString *)errorDesc;
+ (NSError *)errorWithDescription:(NSString *)errorDesc code:(NSInteger)errorCode;
+ (BOOL)openURL:(NSURL *)url;
+ (BOOL)openInstagramProfileForUsername:(NSString *)username;
+ (BOOL)openInstagramMediaURL:(NSURL *)url;
+ (BOOL)openPhotosApp;

// Media
+ (NSURL *)getPhotoUrl:(IGPhoto *)photo;
+ (NSURL *)getPhotoUrlForMedia:(IGMedia *)media;
+ (NSURL *)getBestProfilePictureURLForUser:(id)user;

+ (NSURL *)getVideoUrl:(IGVideo *)video;
+ (NSURL *)getVideoUrlForMedia:(IGMedia *)media;

// View Controller Helpers
+ (UIViewController *)viewControllerForView:(UIView *)view;
+ (UIViewController *)viewControllerForAncestralView:(UIView *)view;
+ (UIViewController *)nearestViewControllerForView:(UIView *)view;

// Alerts
+ (BOOL)showConfirmation:(void(^)(void))okHandler title:(NSString *)title;
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler title:(NSString *)title;
+ (BOOL)showConfirmation:(void(^)(void))okHandler;
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler;
+ (void)showRestartConfirmation;

// Toasts
+ (void)showToastForDuration:(double)duration title:(NSString *)title;
+ (void)showToastForDuration:(double)duration title:(NSString *)title subtitle:(NSString *)subtitle;
+ (void)showToastForDuration:(double)duration
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                iconResource:(nullable NSString *)iconResource
     fallbackSystemImageName:(nullable NSString *)fallbackSystemImageName
                        tone:(SCIFeedbackPillTone)tone;

+ (SCIFeedbackPillView *)showProgressPill;

// Math
+ (NSUInteger)decimalPlacesInDouble:(double)value;

// Dynamic selector helpers
+ (nullable NSNumber *)numericValueForObj:(id)obj selectorName:(NSString *)selectorName;

// Ivars
+ (id)getIvarForObj:(id)obj name:(const char *)name;
+ (void)setIvarForObj:(id)obj name:(const char *)name value:(id)value;

// PNGs in SCInsta.bundle (jailbreak paths, embedded bundle) and LiveContainer Documents/Tweaks/SCInsta/
+ (NSBundle *)sci_resourcesBundle;
+ (nullable UIImage *)sci_resourceImageNamed:(NSString *)name template:(BOOL)asTemplate;
/// When `maxPointSize` > 0, scales the image so its larger side is at most that many points (matches SF Symbol sizing).
+ (nullable UIImage *)sci_resourceImageNamed:(NSString *)name template:(BOOL)asTemplate maxPointSize:(CGFloat)maxPointSize;

@end
