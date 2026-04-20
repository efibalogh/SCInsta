#pragma once

#import <UIKit/UIKit.h>
#import "ActionButtonLookupUtils.h"

typedef NS_ENUM(NSInteger, SCIActionButtonSource) {
	SCIActionButtonSourceFeed = 1,
	SCIActionButtonSourceReels = 2,
	SCIActionButtonSourceStories = 3,
	SCIActionButtonSourceDirect = 4
};

@interface SCIActionButtonContext : NSObject
@property (nonatomic, assign) SCIActionButtonSource source;
@property (nonatomic, weak, nullable) UIView *view;
@property (nonatomic, weak, nullable) UIViewController *controller;
@property (nonatomic, assign) NSInteger currentIndexOverride;
@property (nonatomic, strong, nullable) id mediaOverride;
@end

UIImage *SCIActionButtonImage(NSString *resourceName, NSString *systemFallback, CGFloat maxPointSize);
void SCIHandleFeedExpandLongPress(UIView *view, UILongPressGestureRecognizer *sender);
UIButton *SCIActionButtonWithTag(UIView *container, NSInteger tag);
void SCIApplyButtonStyle(UIButton *button, SCIActionButtonSource source);
BOOL SCIIsDirectVisualViewerAncestor(UIView *view);
void SCIConfigureActionButton(UIButton *button, SCIActionButtonContext *context);
CGRect SCIFeedAnyButtonFrameFromBarView(UIView *barView);
UIView *SCIFeedFirstRightButtonFromBarView(UIView *barView);
