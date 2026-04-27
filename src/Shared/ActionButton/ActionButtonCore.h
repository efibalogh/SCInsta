#pragma once

#import <UIKit/UIKit.h>
#import "ActionButtonLookupUtils.h"

typedef NS_ENUM(NSInteger, SCIActionButtonSource) {
	SCIActionButtonSourceFeed = 1,
	SCIActionButtonSourceReels = 2,
	SCIActionButtonSourceStories = 3,
	SCIActionButtonSourceDirect = 4,
    SCIActionButtonSourceProfile = 5
};

FOUNDATION_EXPORT NSString * const kSCIActionNone;
FOUNDATION_EXPORT NSString * const kSCIActionDownloadLibrary;
FOUNDATION_EXPORT NSString * const kSCIActionDownloadShare;
FOUNDATION_EXPORT NSString * const kSCIActionCopyDownloadLink;
FOUNDATION_EXPORT NSString * const kSCIActionDownloadGallery;
FOUNDATION_EXPORT NSString * const kSCIActionExpand;
FOUNDATION_EXPORT NSString * const kSCIActionViewThumbnail;
FOUNDATION_EXPORT NSString * const kSCIActionCopyCaption;
FOUNDATION_EXPORT NSString * const kSCIActionOpenTopicSettings;
FOUNDATION_EXPORT NSString * const kSCIActionRepost;

typedef id _Nullable (^SCIActionButtonMediaResolver)(id context);
typedef NSInteger (^SCIActionButtonIndexResolver)(id context);
typedef NSString * _Nullable (^SCIActionButtonCaptionResolver)(id context, id _Nullable media, NSArray *entries, NSInteger currentIndex);
typedef BOOL (^SCIActionButtonRepostHandler)(id context);
typedef BOOL (^SCIActionButtonVisibilityResolver)(id context, NSString *identifier, id _Nullable media, NSArray *entries, NSInteger currentIndex);

@interface SCIActionButtonContext : NSObject
@property (nonatomic, assign) SCIActionButtonSource source;
@property (nonatomic, weak, nullable) UIView *view;
@property (nonatomic, weak, nullable) UIViewController *controller;
@property (nonatomic, assign) NSInteger currentIndexOverride;
@property (nonatomic, strong, nullable) id mediaOverride;
@property (nonatomic, copy, nullable) NSString *settingsTitle;
@property (nonatomic, copy, nullable) NSArray<NSString *> *supportedActions;
@property (nonatomic, copy, nullable) SCIActionButtonMediaResolver mediaResolver;
@property (nonatomic, copy, nullable) SCIActionButtonIndexResolver currentIndexResolver;
@property (nonatomic, copy, nullable) SCIActionButtonCaptionResolver captionResolver;
@property (nonatomic, copy, nullable) SCIActionButtonRepostHandler repostHandler;
@property (nonatomic, copy, nullable) SCIActionButtonVisibilityResolver visibilityResolver;
@end

#ifdef __cplusplus
extern "C" {
#endif
UIButton *SCIActionButtonWithTag(UIView *container, NSInteger tag);
void SCIApplyButtonStyle(UIButton *button, SCIActionButtonSource source);
BOOL SCIIsDirectVisualViewerAncestor(UIView *view);
void SCIConfigureActionButton(UIButton *button, SCIActionButtonContext *context);
SCIActionButtonContext *SCIActionButtonContextFromButton(UIButton *button);
NSString *SCIActionButtonTitleForIdentifier(NSString *identifier);
UIImage *SCIActionButtonMenuIconForIdentifier(NSString *identifier, CGFloat size);
BOOL SCIExecuteActionIdentifier(NSString *identifier, SCIActionButtonContext *context, BOOL isDefaultTap);
void SCIArmPendingRepostFeedback(SCIActionButtonContext *context);
NSDictionary<NSString *, NSString *> * _Nullable SCIConsumePendingRepostFeedback(SCIActionButtonSource source);
void SCIPauseStoryPlaybackFromOverlaySubview(UIView *overlayView);
void SCIResumeStoryPlaybackFromOverlaySubview(UIView *overlayView);
#ifdef __cplusplus
}
#endif
