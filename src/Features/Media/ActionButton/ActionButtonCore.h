#pragma once

#import <UIKit/UIKit.h>

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
@end

id SCIObjectForSelector(id target, NSString *selectorName);
id SCIKVCObject(id target, NSString *key);
NSArray *SCIArrayFromCollection(id collection);

UIImage *SCIActionButtonImage(NSString *resourceName, NSString *systemFallback, CGFloat maxPointSize);

id SCIDirectCurrentMessageFromController(UIViewController *controller);
void SCIHandleFeedExpandLongPress(UIView *view, UILongPressGestureRecognizer *sender);
UIButton *SCIActionButtonWithTag(UIView *container, NSInteger tag);
void SCIApplyButtonStyle(UIButton *button, SCIActionButtonSource source);
BOOL SCIIsDirectVisualViewerAncestor(UIView *view);
void SCIConfigureActionButton(UIButton *button, SCIActionButtonContext *context);
CGRect SCIFeedAnyButtonFrameFromBarView(UIView *barView);
UIView *SCIFeedFirstRightButtonFromBarView(UIView *barView);
