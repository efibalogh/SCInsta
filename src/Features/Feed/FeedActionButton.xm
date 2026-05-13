#import <objc/message.h>
#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Shared/ActionButton/ActionButtonCore.h"
#import "../../Shared/ActionButton/SCIActionButtonConfiguration.h"
#import "../../Shared/Gallery/SCIGalleryFile.h"
#import "../../Shared/Gallery/SCIGalleryOriginController.h"
#import "../../Shared/Gallery/SCIGallerySaveMetadata.h"
#import "../../Shared/MediaPreview/SCIMediaItem.h"

static NSInteger const kSCIFeedActionButtonTag = 921341;
static const void *kSCIFeedExpandLongPressMarkerAssocKey = &kSCIFeedExpandLongPressMarkerAssocKey;

@interface IGFeedItemPageVideoCell : UICollectionViewCell
@end

static BOOL SCIFeedLongPressExpandEnabled(void) {
	return [SCIUtils getBoolPref:@"enable_long_press_expand"];
}

static UIPageControl *SCIPageControlInViewHierarchy(UIView *view) {
	if (!view) return nil;
	if ([view isKindOfClass:[UIPageControl class]]) return (UIPageControl *)view;
	for (UIView *subview in view.subviews) {
		UIPageControl *pageControl = SCIPageControlInViewHierarchy(subview);
		if (pageControl) return pageControl;
	}
	return nil;
}

static NSInteger SCIIndexFromPageIndicatorObject(id indicator) {
	if (!indicator) return -1;
	if ([indicator isKindOfClass:[UIPageControl class]]) {
		return (NSInteger)((UIPageControl *)indicator).currentPage;
	}

	NSNumber *currentPageNumber = [SCIUtils numericValueForObj:indicator selectorName:@"currentPage"];
	if (currentPageNumber) return currentPageNumber.integerValue;

	id currentPage = SCIKVCObject(indicator, @"currentPage");
	NSString *pageString = SCIStringFromValue(currentPage);
	return pageString.length > 0 ? pageString.integerValue : -1;
}

static NSInteger SCIFeedCurrentIndexFromBarView(UIView *barView) {
	if (!barView) return -1;

	id delegate = SCIObjectForSelector(barView, @"delegate");
	id nestedDelegate = SCIObjectForSelector(delegate, @"delegate");
	id target = nestedDelegate ?: delegate;

	id pageCellState = [SCIUtils getIvarForObj:target name:"_pageCellState"];
	NSNumber *stateIndex = [SCIUtils numericValueForObj:pageCellState selectorName:@"currentPageIndex"];
	if (stateIndex && stateIndex.integerValue >= 0) return stateIndex.integerValue;
	stateIndex = [SCIUtils numericValueForObj:pageCellState selectorName:@"currentIndex"];
	if (stateIndex && stateIndex.integerValue >= 0) return stateIndex.integerValue;

	NSNumber *delegatePage = [SCIUtils numericValueForObj:delegate selectorName:@"pageControlCurrentPage"];
	if (delegatePage && delegatePage.integerValue >= 0) return delegatePage.integerValue;

	NSInteger pageControlIdx = SCIIndexFromPageIndicatorObject(SCIObjectForSelector(delegate, @"pageControl"));
	if (pageControlIdx >= 0) return pageControlIdx;

	for (NSString *selectorName in @[@"pageControl", @"pageIndicator", @"carouselPageControl"]) {
		NSInteger idx = SCIIndexFromPageIndicatorObject(SCIObjectForSelector(barView, selectorName));
		if (idx >= 0) return idx;
	}

	UIPageControl *localPageControl = SCIPageControlInViewHierarchy(barView);
	if (localPageControl) return (NSInteger)localPageControl.currentPage;

	UIPageControl *superPageControl = SCIPageControlInViewHierarchy(barView.superview);
	return superPageControl ? (NSInteger)superPageControl.currentPage : -1;
}

static id SCIFeedMediaFromBarView(UIView *barView) {
	if (!barView) return nil;

	id delegate = SCIObjectForSelector(barView, @"delegate");
	id nestedDelegate = SCIObjectForSelector(delegate, @"delegate");
	id target = nestedDelegate ?: delegate;

	id media = [SCIUtils getIvarForObj:target name:"_media"];
	if (!media) media = SCIObjectForSelector(target, @"media");
	if (!media) media = SCIKVCObject(target, @"media");
	return media;
}

static UIView *SCIFeedAnyButtonFromBarView(UIView *barView) {
	if (!barView) return nil;

	id saveIvar = [SCIUtils getIvarForObj:barView name:"_saveButton"];
	if ([saveIvar isKindOfClass:[UIView class]]) return (UIView *)saveIvar;

	for (NSString *selectorName in @[@"sendButton", @"commentButton", @"likeButton", @"saveButton"]) {
		id candidate = SCIObjectForSelector(barView, selectorName);
		if ([candidate isKindOfClass:[UIView class]]) return (UIView *)candidate;
	}

	return nil;
}

static CGRect SCIFeedAnyButtonFrameFromBarView(UIView *barView) {
	UIView *anyButton = SCIFeedAnyButtonFromBarView(barView);
	return anyButton ? anyButton.frame : CGRectMake(0.0, 0.0, 40.0, 48.0);
}

static UIView *SCIFeedFirstRightButtonFromBarView(UIView *barView) {
	if (!barView) return nil;

	for (NSString *selectorName in @[@"visualSearchButton", @"saveButton"]) {
		id candidate = SCIObjectForSelector(barView, selectorName);
		if ([candidate isKindOfClass:[UIView class]]) {
			UIView *view = (UIView *)candidate;
			if (!view.hidden && view.superview) return view;
		}
	}

	for (NSString *ivarName in @[@"_visualSearchButton", @"_saveButton"]) {
		id candidate = [SCIUtils getIvarForObj:barView name:ivarName.UTF8String];
		if ([candidate isKindOfClass:[UIView class]]) {
			UIView *view = (UIView *)candidate;
			if (!view.hidden && view.superview) return view;
		}
	}

	return nil;
}

static UIView *SCIFeedCellAncestorForView(UIView *view) {
	UIView *walker = view;
	NSInteger depth = 0;
	while (walker && depth < 16) {
		for (NSString *className in @[@"IGFeedItemMediaCell", @"IGFeedItemPageCell", @"IGModernFeedVideoCell", @"IGModernFeedVideoCell.IGModernFeedVideoCell"]) {
			Class cls = NSClassFromString(className);
			if (cls && [walker isKindOfClass:cls]) return walker;
		}
		walker = walker.superview;
		depth++;
	}
	return nil;
}

static UICollectionView *SCIFeedOuterCollectionView(UIView *view) {
	UIView *walker = view;
	NSInteger depth = 0;
	while (walker && depth < 16) {
		if ([walker isKindOfClass:[UICollectionView class]]) {
			NSString *className = NSStringFromClass([walker class]);
			if (![className containsString:@"Carousel"] && ![className containsString:@"Page"]) {
				return (UICollectionView *)walker;
			}
		}
		walker = walker.superview;
		depth++;
	}
	return nil;
}

static NSInteger SCIFeedSectionForViewInCollection(UIView *view, UICollectionView *collectionView) {
	if (!view || !collectionView) return -1;
	UIView *walker = view;
	NSInteger depth = 0;
	while (walker && depth < 16) {
		if ([walker isKindOfClass:[UICollectionViewCell class]]) {
			NSIndexPath *indexPath = [collectionView indexPathForCell:(UICollectionViewCell *)walker];
			if (indexPath) return indexPath.section;
		}
		walker = walker.superview;
		depth++;
	}
	return -1;
}

static id SCIFeedMediaFromCellByIntrospection(UICollectionViewCell *cell, Class mediaClass) {
	if (!cell || !mediaClass) return nil;

	unsigned int count = 0;
	Class currentClass = object_getClass(cell);
	while (currentClass && currentClass != [UICollectionViewCell class]) {
		Ivar *ivars = class_copyIvarList(currentClass, &count);
		for (unsigned int i = 0; i < count; i++) {
			const char *type = ivar_getTypeEncoding(ivars[i]);
			if (!type || type[0] != '@') continue;
			@try {
				id value = object_getIvar(cell, ivars[i]);
				if (value && [value isKindOfClass:mediaClass]) {
					if (ivars) free(ivars);
					return value;
				}
			} @catch (__unused NSException *exception) {
			}
		}
		if (ivars) free(ivars);
		currentClass = class_getSuperclass(currentClass);
	}

	if ([cell respondsToSelector:@selector(mediaCellFeedItem)]) {
		id media = ((id (*)(id, SEL))objc_msgSend)(cell, @selector(mediaCellFeedItem));
		if (media && [media isKindOfClass:mediaClass]) return media;
	}

	for (NSString *selectorName in @[@"post", @"pagePhotoPost", @"pageVideoPost", @"media"]) {
		id media = SCIObjectForSelector(cell, selectorName);
		if (media && [media isKindOfClass:mediaClass]) return media;
	}

	return nil;
}

static id SCIFeedMediaForZoomFromView(UIView *view) {
	Class mediaClass = NSClassFromString(@"IGMedia");
	if (!view || !mediaClass) return nil;

	UICollectionView *collectionView = SCIFeedOuterCollectionView(view);
	if (!collectionView) return nil;

	NSInteger section = SCIFeedSectionForViewInCollection(view, collectionView);
	if (section < 0) return nil;

	for (UICollectionViewCell *cell in collectionView.visibleCells) {
		NSIndexPath *indexPath = [collectionView indexPathForCell:cell];
		if (!indexPath || indexPath.section != section) continue;

		NSString *className = NSStringFromClass([cell class]);
		if (![className containsString:@"Photo"] &&
			![className containsString:@"Video"] &&
			![className containsString:@"Media"] &&
			![className containsString:@"Page"]) {
			continue;
		}

		id media = SCIFeedMediaFromCellByIntrospection(cell, mediaClass);
		if (media) return media;
	}

	return nil;
}

static NSInteger SCIFeedCarouselPageIndexFromView(UIView *view) {
	UICollectionView *collectionView = SCIFeedOuterCollectionView(view);
	if (!collectionView) return 0;

	NSInteger section = SCIFeedSectionForViewInCollection(view, collectionView);
	if (section < 0) return 0;

	for (UICollectionViewCell *cell in collectionView.visibleCells) {
		NSIndexPath *indexPath = [collectionView indexPathForCell:cell];
		if (!indexPath || indexPath.section != section) continue;
		if (![NSStringFromClass([cell class]) containsString:@"Page"]) continue;

		NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cell];
		NSInteger scanned = 0;
		while (queue.count > 0 && scanned < 100) {
			UIView *current = queue.firstObject;
			[queue removeObjectAtIndex:0];
			scanned++;

			if ([current isKindOfClass:[UIScrollView class]] && current != collectionView) {
				UIScrollView *scrollView = (UIScrollView *)current;
				CGFloat pageWidth = scrollView.bounds.size.width;
				if (pageWidth > 100.0 && scrollView.contentSize.width > pageWidth * 1.5) {
					return (NSInteger)llround(scrollView.contentOffset.x / pageWidth);
				}
			}

			for (UIView *subview in current.subviews) {
				[queue addObject:subview];
			}
		}
	}

	return 0;
}

static NSArray *SCIFeedCarouselChildren(id media) {
	if (!media) return @[];

	for (NSString *selectorName in @[@"carouselMedia", @"carouselChildren", @"children", @"carousel_media"]) {
		id value = SCIObjectForSelector(media, selectorName);
		if (!value) value = SCIKVCObject(media, selectorName);
		NSArray *items = SCIArrayFromCollection(value);
		if (items.count > 0) return items;
	}

	return @[];
}

static BOOL SCIFeedIsCarouselMedia(id media) {
	if (!media) return NO;

	if ([media respondsToSelector:@selector(isCarousel)]) {
		@try {
			if (((BOOL (*)(id, SEL))objc_msgSend)(media, @selector(isCarousel))) {
				return YES;
			}
		} @catch (__unused NSException *exception) {
		}
	}

	if ([media respondsToSelector:@selector(mediaType)]) {
		@try {
			if (((NSInteger (*)(id, SEL))objc_msgSend)(media, @selector(mediaType)) == 8) {
				return YES;
			}
		} @catch (__unused NSException *exception) {
		}
	}

	return SCIFeedCarouselChildren(media).count > 0;
}

static SCIGallerySaveMetadata *SCIFeedMetadataForMedia(id media) {
	SCIGallerySaveMetadata *metadata = [[SCIGallerySaveMetadata alloc] init];
	metadata.source = (int16_t)SCIGallerySourceFeed;
	[SCIGalleryOriginController populateMetadata:metadata fromMedia:media];
	return metadata;
}

static SCIGallerySaveMetadata *SCIFeedMetadataForMediaWithUsernameFallback(id media, NSString *username) {
	SCIGallerySaveMetadata *metadata = SCIFeedMetadataForMedia(media);
	if (metadata.sourceUsername.length == 0 && username.length > 0) {
		metadata.sourceUsername = username;
		[SCIGalleryOriginController populateProfileMetadata:metadata username:username user:nil];
	}
	return metadata;
}

static id SCIFeedPostObjectFromFeedCell(UIView *feedCell) {
	if (!feedCell) return nil;
	id post = SCIObjectForSelector(feedCell, @"post");
	if (post) return post;
	post = SCIObjectForSelector(feedCell, @"mediaCellFeedItem");
	if (post) return post;
	post = SCIObjectForSelector(feedCell, @"media");
	if (post) return post;
	return [SCIUtils getIvarForObj:feedCell name:"_post"];
}

static BOOL SCIFeedPostAndCellFromScrollContainers(UIView *view, UILongPressGestureRecognizer *sender, id *outPost, UIView **outCell) {
	if (outPost) *outPost = nil;
	if (outCell) *outCell = nil;
	if (!view || !sender) return NO;

	NSMutableArray<UIView *> *hosts = [NSMutableArray array];
	for (UIView *walker = view; walker; walker = walker.superview) {
		if ([walker isKindOfClass:[UICollectionView class]] || [walker isKindOfClass:[UITableView class]]) {
			[hosts addObject:walker];
		}
	}

	for (UIView *host in [hosts reverseObjectEnumerator]) {
		CGPoint pt = [sender locationInView:host];
		if (!CGRectContainsPoint(host.bounds, pt)) continue;

		UIView *cell = nil;
		if ([host isKindOfClass:[UICollectionView class]]) {
			UICollectionView *cv = (UICollectionView *)host;
			NSIndexPath *ip = [cv indexPathForItemAtPoint:pt];
			if (!ip) continue;
			cell = [cv cellForItemAtIndexPath:ip];
		} else {
			UITableView *tv = (UITableView *)host;
			NSIndexPath *ip = [tv indexPathForRowAtPoint:pt];
			if (!ip) continue;
			cell = [tv cellForRowAtIndexPath:ip];
		}

		id post = SCIFeedPostObjectFromFeedCell(cell);
		if (!post) continue;
		if (outPost) *outPost = post;
		if (outCell) *outCell = cell;
		return YES;
	}

	return NO;
}

static UIView *SCIRecursiveSubviewMatchingClassNames(UIView *root, NSArray<NSString *> *classNames) {
	if (!root) return nil;
	for (NSString *className in classNames) {
		Class cls = NSClassFromString(className);
		if (cls && [root isKindOfClass:cls]) return root;
	}
	for (UIView *subview in root.subviews) {
		UIView *match = SCIRecursiveSubviewMatchingClassNames(subview, classNames);
		if (match) return match;
	}
	return nil;
}

static UIView *SCIFeedActionContextViewFromMediaView(UIView *view) {
	NSArray<NSString *> *candidateClassNames = @[@"IGUFIButtonBarView", @"IGUFIInteractionCountsView", @"IGSocialUFIView.IGSocialUFIView"];
	UIView *walker = view;
	NSInteger depth = 0;
	while (walker && depth < 8) {
		UIView *match = SCIRecursiveSubviewMatchingClassNames(walker, candidateClassNames);
		if (match) return match;
		walker = walker.superview;
		depth++;
	}
	return nil;
}

static NSString *SCIFeedCaptionForContext(SCIActionButtonContext *context, id media, NSArray *entries, NSInteger currentIndex) {
	NSString *caption = SCICaptionFromMediaObject(media);
	if (caption.length > 0) return caption;
	NSInteger idx = MAX(0, MIN((NSInteger)entries.count - 1, currentIndex));
	if (entries.count > 0) {
		id entryMedia = [entries[idx] valueForKey:@"mediaObject"];
		caption = SCICaptionFromMediaObject(entryMedia);
	}
	return caption;
}

static BOOL SCIFeedTriggerRepost(SCIActionButtonContext *context) {
	UIView *barView = context.view;
	UIResponder *responder = barView;
	Class feedCellClass = NSClassFromString(@"IGFeedItemUFICell");
	while (responder && !(feedCellClass && [responder isKindOfClass:feedCellClass])) {
		responder = [responder nextResponder];
	}
	if (!responder || ![responder respondsToSelector:@selector(UFIButtonBarDidTapOnRepost:)]) {
		return NO;
	}
	((void (*)(id, SEL, id))objc_msgSend)(responder, @selector(UFIButtonBarDidTapOnRepost:), barView);
	return YES;
}

static SCIActionButtonContext *SCIFeedActionContext(UIView *barView) {
	SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
	context.source = SCIActionButtonSourceFeed;
	context.view = barView;
	context.settingsTitle = SCIActionButtonTopicTitleForSource(SCIActionButtonSourceFeed);
	context.supportedActions = SCIActionButtonSupportedActionsForSource(SCIActionButtonSourceFeed);
	context.mediaResolver = ^id (SCIActionButtonContext *resolvedContext) {
		return SCIFeedMediaFromBarView(resolvedContext.view);
	};
    context.bulkMediaResolver = ^id (SCIActionButtonContext *resolvedContext) {
        return SCIFeedMediaFromBarView(resolvedContext.view);
    };
	context.currentIndexResolver = ^NSInteger (SCIActionButtonContext *resolvedContext) {
		return SCIFeedCurrentIndexFromBarView(resolvedContext.view);
	};
	context.captionResolver = ^NSString * (SCIActionButtonContext *resolvedContext, id media, NSArray *entries, NSInteger currentIndex) {
		return SCIFeedCaptionForContext(resolvedContext, media, entries, currentIndex);
	};
	context.repostHandler = ^BOOL (SCIActionButtonContext *resolvedContext) {
		return SCIFeedTriggerRepost(resolvedContext);
	};
	return context;
}

static void SCIInstallFeedActionButton(UIView *barView) {
	if (!barView) return;

	UIButton *button = (UIButton *)[barView viewWithTag:kSCIFeedActionButtonTag];
	if (![SCIUtils getBoolPref:@"action_button_feed_enabled"]) {
		[button removeFromSuperview];
		return;
	}

	button = SCIActionButtonWithTag(barView, kSCIFeedActionButtonTag);
	SCIConfigureActionButton(button, SCIFeedActionContext(barView));
	if (button.hidden) return;

	CGRect anyFrame = SCIFeedAnyButtonFrameFromBarView(barView);
	UIView *firstRightButton = SCIFeedFirstRightButtonFromBarView(barView);
	if (!firstRightButton) {
		[button removeFromSuperview];
		return;
	}

	CGFloat width = CGRectGetWidth(anyFrame) > 0.0 ? CGRectGetWidth(anyFrame) : 40.0;
	button.frame = CGRectMake(CGRectGetMinX(firstRightButton.frame) - width,
							  CGRectGetMinY(anyFrame) + 2.0,
							  width,
							  CGRectGetHeight(anyFrame));
	SCIApplyButtonStyle(button, SCIActionButtonSourceFeed);
}

static void SCIAddFeedExpandLongPressIfNeeded(UIView *view, SEL action) {
	if (!SCIFeedLongPressExpandEnabled() || !view || !action) return;

	for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
		if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]] &&
			objc_getAssociatedObject(gesture, kSCIFeedExpandLongPressMarkerAssocKey)) {
			return;
		}
	}

	UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:view action:action];
	longPress.minimumPressDuration = 0.3;
	longPress.cancelsTouchesInView = NO;
	[view addGestureRecognizer:longPress];
	objc_setAssociatedObject(longPress, kSCIFeedExpandLongPressMarkerAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SCIHandleFeedExpandLongPress(UIView *view, UILongPressGestureRecognizer *sender) {
	if (!SCIFeedLongPressExpandEnabled() || !view || !sender || sender.state != UIGestureRecognizerStateBegan || !view.window) return;

	id media = SCIFeedMediaForZoomFromView(view);
	if (!media) return;

	NSString *username = SCIUsernameFromMediaObject(media);
	SCIGallerySaveMetadata *metadata = SCIFeedMetadataForMediaWithUsernameFallback(media, username);

	if (SCIFeedIsCarouselMedia(media)) {
		NSArray *children = SCIFeedCarouselChildren(media);
		NSMutableArray<SCIMediaItem *> *items = [NSMutableArray array];
		for (id child in children) {
			NSURL *videoURL = [SCIUtils getVideoUrlForMedia:(IGMedia *)child];
			NSURL *photoURL = [SCIUtils getPhotoUrlForMedia:(IGMedia *)child];
			if (!videoURL && !photoURL) continue;

			SCIMediaItem *item = [SCIMediaItem itemWithFileURL:(videoURL ?: photoURL)];
			item.mediaType = videoURL ? SCIMediaItemTypeVideo : SCIMediaItemTypeImage;
			item.gallerySaveSource = SCIGallerySourceFeed;
			item.galleryMetadata = SCIFeedMetadataForMediaWithUsernameFallback(child, username);
			item.sourceMediaObject = child;
			if (username.length > 0) item.title = username;
			[items addObject:item];
		}

		if (items.count > 0) {
			NSInteger index = SCIFeedCarouselPageIndexFromView(view);
			if (index < 0 || index >= (NSInteger)items.count) index = 0;
			SCINotify(kSCIActionExpand, @"Opened media viewer", nil, @"expand", SCINotificationToneForIconResource(@"expand"));
			[SCIFullScreenMediaPlayer showMediaItems:items
								startingAtIndex:index
									   metadata:metadata
								 playbackSource:SCIFullScreenPlaybackSourceFeed
									 sourceView:view
									 controller:[SCIUtils viewControllerForAncestralView:view]
								  pausePlayback:nil
								 resumePlayback:nil];
			return;
		}
	}

	NSURL *videoURL = [SCIUtils getVideoUrlForMedia:(IGMedia *)media];
	NSURL *photoURL = [SCIUtils getPhotoUrlForMedia:(IGMedia *)media];
	if (!videoURL && !photoURL) return;

	SCIMediaItem *item = [SCIMediaItem itemWithFileURL:(videoURL ?: photoURL)];
	item.mediaType = videoURL ? SCIMediaItemTypeVideo : SCIMediaItemTypeImage;
	item.gallerySaveSource = SCIGallerySourceFeed;
	item.galleryMetadata = metadata;
	item.sourceMediaObject = media;
	if (username.length > 0) item.title = username;

	SCINotify(kSCIActionExpand, @"Opened media viewer", nil, @"expand", SCINotificationToneForIconResource(@"expand"));
	[SCIFullScreenMediaPlayer showMediaItems:@[item]
						startingAtIndex:0
							   metadata:metadata
						 playbackSource:SCIFullScreenPlaybackSourceFeed
							 sourceView:view
							 controller:[SCIUtils viewControllerForAncestralView:view]
						  pausePlayback:nil
						 resumePlayback:nil];
}

static void SCIExpandFeedLongPressAction(id self, SEL _cmd, UILongPressGestureRecognizer *sender) {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}

static void (*orig_swiftModernFeedVideo_didMove)(id, SEL);
static void (*orig_swiftModernFeedVideo_layout)(id, SEL);

static void SCIHookSwiftModernFeedVideoDidMove(id self, SEL _cmd) {
	if (orig_swiftModernFeedVideo_didMove) orig_swiftModernFeedVideo_didMove(self, _cmd);
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

static void SCIHookSwiftModernFeedVideoLayout(id self, SEL _cmd) {
	if (orig_swiftModernFeedVideo_layout) orig_swiftModernFeedVideo_layout(self, _cmd);
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%group SCIFeedActionButtonHooks

%hook IGFeedPhotoView
- (void)didMoveToSuperview {
	%orig;
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGFeedItemVideoView
- (void)didMoveToSuperview {
	%orig;
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGFeedItemMediaCell
- (void)didMoveToSuperview {
	%orig;
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_mediaCell_handleExpandLongPress:));
}

- (void)layoutSubviews {
	%orig;
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_mediaCell_handleExpandLongPress:));
}

%new - (void)sci_mediaCell_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGModernFeedVideoCell
- (void)didMoveToSuperview {
	%orig;
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

- (void)layoutSubviews {
	%orig;
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGPageMediaView
- (void)didMoveToSuperview {
	%orig;
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGFeedItemPagePhotoCell
- (void)didMoveToSuperview {
	%orig;
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGFeedItemPageVideoCell
- (void)didMoveToSuperview {
	%orig;
	SCIAddFeedExpandLongPressIfNeeded((UIView *)self, @selector(sci_handleExpandLongPress:));
}

%new - (void)sci_handleExpandLongPress:(UILongPressGestureRecognizer *)sender {
	SCIHandleFeedExpandLongPress((UIView *)self, sender);
}
%end

%hook IGUFIButtonBarView
- (void)layoutSubviews {
	%orig;
	SCIInstallFeedActionButton((UIView *)self);
}
%end

%hook IGUFIInteractionCountsView
- (void)layoutSubviews {
	%orig;
	SCIInstallFeedActionButton((UIView *)self);
}
%end

%end

extern "C" void SCIInstallFeedActionButtonHooksIfEnabled(void) {
	if (![SCIUtils getBoolPref:@"action_button_feed_enabled"] &&
		![SCIUtils getBoolPref:@"enable_long_press_expand"]) {
		return;
	}

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	%init(SCIFeedActionButtonHooks);

	Class modernObjCName = objc_getClass("IGModernFeedVideoCell");
	Class modernSwiftRuntime = objc_getClass("IGModernFeedVideoCell.IGModernFeedVideoCell");
	if (modernSwiftRuntime && modernSwiftRuntime != modernObjCName) {
		class_addMethod(modernSwiftRuntime, @selector(sci_handleExpandLongPress:), (IMP)SCIExpandFeedLongPressAction, "v@:@");
		MSHookMessageEx(modernSwiftRuntime, @selector(didMoveToSuperview), (IMP)SCIHookSwiftModernFeedVideoDidMove, (IMP *)&orig_swiftModernFeedVideo_didMove);
		MSHookMessageEx(modernSwiftRuntime, @selector(layoutSubviews), (IMP)SCIHookSwiftModernFeedVideoLayout, (IMP *)&orig_swiftModernFeedVideo_layout);
	}
	});
}
