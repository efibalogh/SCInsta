#import <objc/message.h>
#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Shared/ActionButton/ActionButtonCore.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"

static NSInteger const kSCIReelsActionButtonTag = 921342;
static const void *kSCIReelsActionBottomConstraintAssocKey = &kSCIReelsActionBottomConstraintAssocKey;
static const void *kSCIReelsActionCenterXConstraintAssocKey = &kSCIReelsActionCenterXConstraintAssocKey;
static const void *kSCIReelsActionWidthConstraintAssocKey = &kSCIReelsActionWidthConstraintAssocKey;
static const void *kSCIReelsActionHeightConstraintAssocKey = &kSCIReelsActionHeightConstraintAssocKey;

static UIView *SCIReelsFindSuperviewOfClass(UIView *view, NSString *className) {
	Class cls = NSClassFromString(className);
	if (!cls) return nil;
	UIView *current = view.superview;
	for (NSInteger depth = 0; current && depth < 20; depth++) {
		if ([current isKindOfClass:cls]) return current;
		current = current.superview;
	}
	return nil;
}

static id SCIReelsFindMediaIvar(UIView *view) {
	Class mediaClass = NSClassFromString(@"IGMedia");
	if (!view || !mediaClass) return nil;

	unsigned int count = 0;
	Ivar *ivars = class_copyIvarList([view class], &count);
	id found = nil;
	for (unsigned int i = 0; i < count; i++) {
		const char *type = ivar_getTypeEncoding(ivars[i]);
		if (!type || type[0] != '@') continue;
		@try {
			id value = object_getIvar(view, ivars[i]);
			if (value && [value isKindOfClass:mediaClass]) {
				found = value;
				break;
			}
		} @catch (__unused NSException *exception) {
		}
	}
	if (ivars) free(ivars);
	return found;
}

static id SCIReelsCurrentCarouselChildMedia(UIView *carouselCell, id parentMedia) {
	if (!carouselCell || !parentMedia) return parentMedia;

	Ivar idxIvar = class_getInstanceVariable([carouselCell class], "_currentIndex");
	NSInteger currentIdx = 0;
	if (idxIvar) {
		ptrdiff_t offset = ivar_getOffset(idxIvar);
		currentIdx = *(NSInteger *)((char *)(__bridge void *)carouselCell + offset);
	}

	if (!idxIvar || currentIdx == 0) {
		Ivar fracIvar = class_getInstanceVariable([carouselCell class], "_currentFractionalIndex");
		if (fracIvar) {
			ptrdiff_t offset = ivar_getOffset(fracIvar);
			double fractionalIndex = *(double *)((char *)(__bridge void *)carouselCell + offset);
			NSInteger roundedIdx = (NSInteger)round(fractionalIndex);
			if (roundedIdx > 0) currentIdx = roundedIdx;
		}
	}

	Ivar collectionViewIvar = class_getInstanceVariable([carouselCell class], "_collectionView");
	if (collectionViewIvar) {
		UICollectionView *cv = object_getIvar(carouselCell, collectionViewIvar);
		if (cv) {
			CGFloat pageWidth = cv.bounds.size.width;
			if (pageWidth > 0) {
				NSInteger cvIdx = (NSInteger)round(cv.contentOffset.x / pageWidth);
				if (cvIdx > currentIdx) currentIdx = cvIdx;
			}
		}
	}

	NSArray *children = SCIArrayFromCollection(SCIObjectForSelector(parentMedia, @"carouselMedia"));
	if (children.count == 0) children = SCIArrayFromCollection(SCIObjectForSelector(parentMedia, @"carouselChildren"));
	if (children.count == 0) children = SCIArrayFromCollection(SCIObjectForSelector(parentMedia, @"children"));
	if (children.count == 0) children = SCIArrayFromCollection(SCIKVCObject(parentMedia, @"carousel_media"));

	return (currentIdx >= 0 && (NSUInteger)currentIdx < children.count) ? children[currentIdx] : parentMedia;
}

static id SCIReelsMediaProvider(UIView *sourceView) {
	UIView *videoCell = SCIReelsFindSuperviewOfClass(sourceView, @"IGSundialViewerVideoCell");
	if (videoCell) {
		id media = SCIReelsFindMediaIvar(videoCell);
		if (media) return media;
	}

	UIView *photoCell = SCIReelsFindSuperviewOfClass(sourceView, @"IGSundialViewerPhotoCell");
	if (photoCell) {
		id media = SCIReelsFindMediaIvar(photoCell);
		if (media) return media;
	}

	UIView *carouselCell = SCIReelsFindSuperviewOfClass(sourceView, @"IGSundialViewerCarouselCell");
	if (carouselCell) {
		id parentMedia = SCIReelsFindMediaIvar(carouselCell);
		if (parentMedia) return SCIReelsCurrentCarouselChildMedia(carouselCell, parentMedia);
	}

	id delegate = SCIObjectForSelector(sourceView, @"delegate");
	id media = SCIObjectForSelector(delegate, @"media");
	if (!media) media = SCIKVCObject(delegate, @"media");
	return media;
}

static NSInteger SCIReelsCurrentIndexFromVerticalUFI(UIView *verticalUFIView) {
	if (!verticalUFIView) return -1;

	for (NSString *selectorName in @[@"pageIndicator", @"pagingControl"]) {
		id indicator = SCIObjectForSelector(verticalUFIView, selectorName);
		if ([indicator isKindOfClass:[UIPageControl class]]) return (NSInteger)((UIPageControl *)indicator).currentPage;
		NSNumber *currentPageNumber = [SCIUtils numericValueForObj:indicator selectorName:@"currentPage"];
		if (currentPageNumber) return currentPageNumber.integerValue;
	}

	NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:verticalUFIView];
	while (queue.count > 0) {
		UIView *candidate = queue.firstObject;
		[queue removeObjectAtIndex:0];
		if ([candidate isKindOfClass:[UIPageControl class]]) return (NSInteger)((UIPageControl *)candidate).currentPage;
		for (UIView *subview in candidate.subviews) [queue addObject:subview];
	}

	return -1;
}

static NSString *SCIReelsCaptionForContext(SCIActionButtonContext *context, id media, NSArray *entries, NSInteger currentIndex) {
	NSString *caption = SCICaptionFromMediaObject(media);
	if (caption.length > 0) return caption;
	NSInteger idx = MAX(0, MIN((NSInteger)entries.count - 1, currentIndex));
	if (entries.count > 0) {
		id entryMedia = [entries[idx] valueForKey:@"mediaObject"];
		caption = SCICaptionFromMediaObject(entryMedia);
	}
	return caption;
}

static BOOL SCIReelsTriggerRepost(SCIActionButtonContext *context) {
	if (!context.view) return NO;

	SEL noArgSelector = NSSelectorFromString(@"_didTapRepostButton");
	if ([context.view respondsToSelector:noArgSelector]) {
		((void (*)(id, SEL))objc_msgSend)(context.view, noArgSelector);
		return YES;
	}

	SEL oneArgSelector = @selector(_didTapRepostButton:);
	if ([context.view respondsToSelector:oneArgSelector]) {
		((void (*)(id, SEL, id))objc_msgSend)(context.view, oneArgSelector, nil);
		return YES;
	}

	return NO;
}

static SCIActionButtonContext *SCIReelsActionContext(UIView *verticalUFIView) {
	SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
	context.source = SCIActionButtonSourceReels;
	context.view = verticalUFIView;
	context.settingsTitle = SCIActionButtonTopicTitleForSource(SCIActionButtonSourceReels);
	context.supportedActions = SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceReels);
	context.mediaResolver = ^id (SCIActionButtonContext *resolvedContext) {
		return SCIReelsMediaProvider(resolvedContext.view);
	};
	context.currentIndexResolver = ^NSInteger (SCIActionButtonContext *resolvedContext) {
		return SCIReelsCurrentIndexFromVerticalUFI(resolvedContext.view);
	};
	context.captionResolver = ^NSString * (SCIActionButtonContext *resolvedContext, id media, NSArray *entries, NSInteger currentIndex) {
		return SCIReelsCaptionForContext(resolvedContext, media, entries, currentIndex);
	};
	context.repostHandler = ^BOOL (SCIActionButtonContext *resolvedContext) {
		return SCIReelsTriggerRepost(resolvedContext);
	};
	return context;
}

static void SCIInstallReelsActionButton(UIView *verticalUFIView) {
	if (!verticalUFIView) return;

	UIButton *button = (UIButton *)[verticalUFIView viewWithTag:kSCIReelsActionButtonTag];
	if (![SCIUtils getBoolPref:@"action_button_reels_enabled"]) {
		[button removeFromSuperview];
		return;
	}

	button = SCIActionButtonWithTag(verticalUFIView, kSCIReelsActionButtonTag);
	SCIConfigureActionButton(button, SCIReelsActionContext(verticalUFIView));
	if (button.hidden) return;

	CGFloat size = 44.0;
	button.translatesAutoresizingMaskIntoConstraints = NO;

	NSLayoutConstraint *bottomConstraint = objc_getAssociatedObject(button, kSCIReelsActionBottomConstraintAssocKey);
	NSLayoutConstraint *centerXConstraint = objc_getAssociatedObject(button, kSCIReelsActionCenterXConstraintAssocKey);
	NSLayoutConstraint *widthConstraint = objc_getAssociatedObject(button, kSCIReelsActionWidthConstraintAssocKey);
	NSLayoutConstraint *heightConstraint = objc_getAssociatedObject(button, kSCIReelsActionHeightConstraintAssocKey);

	if (!bottomConstraint || !centerXConstraint || !widthConstraint || !heightConstraint) {
		bottomConstraint = [button.bottomAnchor constraintEqualToAnchor:verticalUFIView.topAnchor constant:-5.0];
		centerXConstraint = [button.centerXAnchor constraintEqualToAnchor:verticalUFIView.centerXAnchor];
		widthConstraint = [button.widthAnchor constraintEqualToConstant:size];
		heightConstraint = [button.heightAnchor constraintEqualToConstant:size];
		[NSLayoutConstraint activateConstraints:@[bottomConstraint, centerXConstraint, widthConstraint, heightConstraint]];

		objc_setAssociatedObject(button, kSCIReelsActionBottomConstraintAssocKey, bottomConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(button, kSCIReelsActionCenterXConstraintAssocKey, centerXConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(button, kSCIReelsActionWidthConstraintAssocKey, widthConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(button, kSCIReelsActionHeightConstraintAssocKey, heightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	bottomConstraint.constant = -5.0;
	widthConstraint.constant = size;
	heightConstraint.constant = size;

	verticalUFIView.clipsToBounds = NO;
	verticalUFIView.layer.masksToBounds = NO;
	[verticalUFIView bringSubviewToFront:button];
	SCIApplyButtonStyle(button, SCIActionButtonSourceReels);
}

%group SCIReelsActionButtonHooks

%hook IGSundialViewerVerticalUFI
- (void)layoutSubviews {
	%orig;
	SCIInstallReelsActionButton((UIView *)self);
}
%end

%end

extern "C" void SCIInstallReelsActionButtonHooksIfEnabled(void) {
	if (![SCIUtils getBoolPref:@"action_button_reels_enabled"]) return;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	%init(SCIReelsActionButtonHooks);
	});
}
