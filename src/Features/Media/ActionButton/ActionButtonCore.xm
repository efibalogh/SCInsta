// ActionButtonCore.xm
//
// Action button for media surfaces:
// - Feed
// - Reels
// - Stories
// - Visual DMs
//
// Tap executes a configurable default action.
// Long-press opens the action menu.

#import <objc/runtime.h>
#import <objc/message.h>
#import <AVFoundation/AVFoundation.h>
#import <os/log.h>
#import <stdarg.h>

#import "ActionButtonCore.h"
#import "ActionButtonLookupUtils.h"
#import "../../../InstagramHeaders.h"
#import "../../../Utils.h"
#import "../../../Downloader/Download.h"
#import "../../../MediaPreview/SCIMediaItem.h"
#import "../../../MediaPreview/SCIFullScreenMediaPlayer.h"
#import "../../../Vault/SCIVaultFile.h"
#import "../../../Vault/SCIVaultSaveMetadata.h"

static NSString * const kSCIDefaultActionPrefKey = @"action_button_default_action";
static NSString * const kSCIViewThumbnailPrefKey = @"view_thumbnail";

static NSString * const kSCIActionNone = @"none";
static NSString * const kSCIActionDownloadLibrary = @"download_library";
static NSString * const kSCIActionDownloadShare = @"download_share";
static NSString * const kSCIActionCopyDownloadLink = @"copy_download_link";
static NSString * const kSCIActionDownloadVault = @"download_vault";
static NSString * const kSCIActionExpand = @"expand";
static NSString * const kSCIActionViewThumbnail = @"view_thumbnail";
static NSInteger const kSCIFeedActionButtonTag = 921341;

static const void *kSCIActionButtonContextAssocKey = &kSCIActionButtonContextAssocKey;
static const void *kSCIActionButtonTapActionAssocKey = &kSCIActionButtonTapActionAssocKey;
static const void *kSCIActionButtonHapticActionAssocKey = &kSCIActionButtonHapticActionAssocKey;

@interface SCIResolvedMediaEntry : NSObject
@property (nonatomic, strong, nullable) id mediaObject;
@property (nonatomic, strong, nullable) NSURL *photoURL;
@property (nonatomic, strong, nullable) NSURL *videoURL;
@end

@implementation SCIResolvedMediaEntry
@end

@implementation SCIActionButtonContext
- (instancetype)init {
	if ((self = [super init])) {
		_currentIndexOverride = -1;
	}
	return self;
}
@end

static void SCIDMTrace(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[SCInsta][DMTrace] %{public}@", message ?: @"(nil)");
}

static BOOL SCIIsVideoExtension(NSString *ext) {
	if (ext.length == 0) return NO;

	NSString *lower = ext.lowercaseString;
	static NSSet<NSString *> *videoExts;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		videoExts = [NSSet setWithArray:@[@"mp4", @"mov", @"m4v", @"avi", @"webm", @"hevc"]];
	});

	return [videoExts containsObject:lower];
}

static NSString *SCIExtensionForURL(NSURL *url, BOOL isVideo) {
	NSString *ext = url.pathExtension;
	if (ext.length > 0) return ext;
	return isVideo ? @"mp4" : @"jpg";
}

static UIViewController *SCIViewControllerForAncestorView(UIView *view) {
	if (!view) return nil;

	id candidate = SCIObjectForSelector(view, @"_viewControllerForAncestor");
	if ([candidate isKindOfClass:[UIViewController class]]) {
		return (UIViewController *)candidate;
	}

	return [SCIUtils viewControllerForAncestralView:view];
}

UIImage *SCIActionButtonImage(NSString *resourceName, NSString *systemFallback, CGFloat maxPointSize) {
	UIImage *image = [SCIUtils sci_resourceImageNamed:resourceName template:YES maxPointSize:maxPointSize];
	if (image) return image;

	UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:maxPointSize weight:UIImageSymbolWeightRegular];
	return [UIImage systemImageNamed:systemFallback withConfiguration:config];
}

static void SCIPlayActionButtonTapHaptic(void) {
	UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
	[feedback selectionChanged];
}

static UIColor *SCIActionButtonTintForSource(SCIActionButtonSource source) {
	switch (source) {
		case SCIActionButtonSourceFeed:
			return [UIColor labelColor];
		case SCIActionButtonSourceReels:
		case SCIActionButtonSourceStories:
		case SCIActionButtonSourceDirect:
		default:
			return [UIColor whiteColor];
	}
}

static UIImage *SCIIconForActionIdentifier(NSString *identifier, CGFloat size) {
	if ([identifier isEqualToString:kSCIActionDownloadLibrary]) {
		return SCIActionButtonImage(@"download", @"arrow.down.to.line", size);
	}
	if ([identifier isEqualToString:kSCIActionDownloadShare]) {
		return SCIActionButtonImage(@"share", @"square.and.arrow.up", size);
	}
	if ([identifier isEqualToString:kSCIActionCopyDownloadLink]) {
		return SCIActionButtonImage(@"link", @"link", size);
	}
	if ([identifier isEqualToString:kSCIActionDownloadVault]) {
		return SCIActionButtonImage(@"chest", @"tray.and.arrow.down", size);
	}
	if ([identifier isEqualToString:kSCIActionExpand]) {
		return SCIActionButtonImage(@"expand", @"arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", size);
	}
	if ([identifier isEqualToString:kSCIActionViewThumbnail]) {
		return SCIActionButtonImage(@"photo_gallery", @"photo.on.rectangle", size);
	}

	return SCIActionButtonImage(@"action", @"option", size);
}

static NSString *SCITitleForActionIdentifier(NSString *identifier) {
	if ([identifier isEqualToString:kSCIActionDownloadLibrary]) return @"Download";
	if ([identifier isEqualToString:kSCIActionDownloadShare]) return @"Share";
	if ([identifier isEqualToString:kSCIActionCopyDownloadLink]) return @"Copy Link";
	if ([identifier isEqualToString:kSCIActionDownloadVault]) return @"Download to Vault";
	if ([identifier isEqualToString:kSCIActionExpand]) return @"Expand";
	if ([identifier isEqualToString:kSCIActionViewThumbnail]) return @"View Thumbnail";
	return @"Action";
}

static NSArray<NSString *> *SCIConfiguredActionOrder(void) {
	return @[
		kSCIActionDownloadLibrary,
		kSCIActionDownloadShare,
		kSCIActionCopyDownloadLink,
		kSCIActionDownloadVault,
		kSCIActionExpand,
		kSCIActionViewThumbnail
	];
}

static SCIVaultSource SCIVaultSourceForActionSource(SCIActionButtonSource source) {
	switch (source) {
		case SCIActionButtonSourceFeed:
			return SCIVaultSourceFeed;
		case SCIActionButtonSourceReels:
			return SCIVaultSourceReels;
		case SCIActionButtonSourceStories:
			return SCIVaultSourceStories;
		case SCIActionButtonSourceDirect:
			return SCIVaultSourceDMs;
		default:
			return SCIVaultSourceOther;
	}
}

static SCIVaultSaveMetadata *SCIVaultMetadata(SCIActionButtonSource source, NSString *username) {
	SCIVaultSaveMetadata *meta = [[SCIVaultSaveMetadata alloc] init];
	meta.source = (int16_t)SCIVaultSourceForActionSource(source);
	if (username.length > 0) {
		meta.sourceUsername = username;
	}
	return meta;
}

static SCIDownloadDelegate *SCIDelegateForAction(DownloadAction action) {
	static SCIDownloadDelegate *savePhotosDelegate = nil;
	static SCIDownloadDelegate *shareDelegate = nil;
	static SCIDownloadDelegate *saveVaultDelegate = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		savePhotosDelegate = [[SCIDownloadDelegate alloc] initWithAction:saveToPhotos showProgress:YES];
		shareDelegate = [[SCIDownloadDelegate alloc] initWithAction:share showProgress:YES];
		saveVaultDelegate = [[SCIDownloadDelegate alloc] initWithAction:saveToVault showProgress:YES];
	});

	switch (action) {
		case saveToPhotos:
			return savePhotosDelegate;
		case share:
			return shareDelegate;
		case saveToVault:
			return saveVaultDelegate;
		default:
			return savePhotosDelegate;
	}
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
	if (pageString.length > 0) return pageString.integerValue;

	return -1;
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

	NSInteger delegatePageControlIdx = SCIIndexFromPageIndicatorObject(SCIObjectForSelector(delegate, @"pageControl"));
	if (delegatePageControlIdx >= 0) return delegatePageControlIdx;

	NSArray<NSString *> *indicatorSelectors = @[@"pageControl", @"pageIndicator", @"carouselPageControl"];
	for (NSString *selectorName in indicatorSelectors) {
		NSInteger idx = SCIIndexFromPageIndicatorObject(SCIObjectForSelector(barView, selectorName));
		if (idx >= 0) return idx;
	}

	UIPageControl *localPageControl = SCIPageControlInViewHierarchy(barView);
	if (localPageControl) return (NSInteger)localPageControl.currentPage;

	UIPageControl *superPageControl = SCIPageControlInViewHierarchy(barView.superview);
	if (superPageControl) return (NSInteger)superPageControl.currentPage;

	return -1;
}

static NSInteger SCIReelsCurrentIndexFromVerticalUFI(UIView *verticalUFIView) {
	if (!verticalUFIView) return -1;

	id pageIndicator = SCIObjectForSelector(verticalUFIView, @"pageIndicator");
	NSInteger idx = SCIIndexFromPageIndicatorObject(pageIndicator);
	if (idx >= 0) return idx;

	id resolvedPageIndicator = SCIObjectForSelector(verticalUFIView, @"pagingControl");
	idx = SCIIndexFromPageIndicatorObject(resolvedPageIndicator);
	if (idx >= 0) return idx;

	UIPageControl *hierarchyPageControl = SCIPageControlInViewHierarchy(verticalUFIView);
	if (hierarchyPageControl) return (NSInteger)hierarchyPageControl.currentPage;

	return -1;
}

static id SCIFeedMediaFromBarView(UIView *barView) {
	if (!barView) return nil;

	id delegate = SCIObjectForSelector(barView, @"delegate");
	if (!delegate) return nil;

	id nestedDelegate = SCIObjectForSelector(delegate, @"delegate");
	id target = nestedDelegate ?: delegate;

	id media = [SCIUtils getIvarForObj:target name:"_media"];
	if (!media) media = SCIObjectForSelector(target, @"media");
	if (!media) media = SCIKVCObject(target, @"media");

	return media;
}

static id SCIReelsMediaFromVerticalUFI(UIView *verticalUFIView) {
	if (!verticalUFIView) return nil;

	id delegate = SCIObjectForSelector(verticalUFIView, @"delegate");
	if (!delegate) return nil;

	id media = SCIObjectForSelector(delegate, @"media");
	if (!media) media = SCIKVCObject(delegate, @"media");
	return media;
}

static id SCIStorySectionControllerFromOverlay(UIView *overlayView) {
	if (!overlayView) return nil;

	NSArray<NSString *> *delegateSelectors = @[@"mediaOverlayDelegate", @"retryDelegate", @"tappableOverlayDelegate", @"buttonDelegate"];
	Class sectionControllerClass = NSClassFromString(@"IGStoryFullscreenSectionController");

	for (NSString *selectorName in delegateSelectors) {
		id delegate = SCIObjectForSelector(overlayView, selectorName);
		if (!delegate) continue;

		if (!sectionControllerClass || [delegate isKindOfClass:sectionControllerClass]) {
			return delegate;
		}
	}

	return nil;
}

static BOOL SCIViewIsFeedCell(UIView *view) {
	if (!view) return NO;

	// Do not match generic UICollectionViewCell — nested carousel/page cells can be mistaken for the feed row.
	for (NSString *className in @[
		@"IGFeedItemMediaCell",
		@"IGFeedItemPageCell",
		@"IGModernFeedVideoCell",
		@"IGModernFeedVideoCell.IGModernFeedVideoCell",
	]) {
		Class cls = NSClassFromString(className);
		if (cls && [view isKindOfClass:cls]) {
			return YES;
		}
	}

	return NO;
}

/// Resolve the post/media object from the feed row that owns the gesture, not from a UFI delegate chain.
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

static UIView *SCIFeedCellAncestorForView(UIView *view) {
	UIView *walker = view;
	NSInteger depth = 0;
	while (walker && depth < 16) {
		if (SCIViewIsFeedCell(walker)) return walker;
		walker = walker.superview;
		depth++;
	}
	return nil;
}

/// Resolves which scroll-hosted row actually contains the touch. Profile / user-media viewers nest collection views;
/// walking only the view chain can pair the gesture with a sibling row’s `post` (often “one above”). Prefer outer hosts first.
static BOOL SCIFeedPostAndCellFromScrollContainers(UIView *view, UILongPressGestureRecognizer *sender, id *outPost, UIView **outCell) {
	if (outPost) *outPost = nil;
	if (outCell) *outCell = nil;
	if (!view || !sender) return NO;

	NSMutableArray<UIView *> *hosts = [NSMutableArray array];
	UIView *walker = view;
	while (walker) {
		if ([walker isKindOfClass:[UICollectionView class]] || [walker isKindOfClass:[UITableView class]]) {
			[hosts addObject:walker];
		}
		walker = walker.superview;
	}

	for (UIView *host in [hosts reverseObjectEnumerator]) {
		CGPoint pt = [sender locationInView:host];
		if (!CGRectContainsPoint(host.bounds, pt)) continue;

		if ([host isKindOfClass:[UICollectionView class]]) {
			UICollectionView *cv = (UICollectionView *)host;
			NSIndexPath *ip = [cv indexPathForItemAtPoint:pt];
			if (!ip) continue;
			UICollectionViewCell *cell = [cv cellForItemAtIndexPath:ip];
			if (!cell) continue;
			id post = SCIFeedPostObjectFromFeedCell(cell);
			if (post) {
				if (outPost) *outPost = post;
				if (outCell) *outCell = cell;
				return YES;
			}
		} else {
			UITableView *tv = (UITableView *)host;
			NSIndexPath *ip = [tv indexPathForRowAtPoint:pt];
			if (!ip) continue;
			UITableViewCell *cell = [tv cellForRowAtIndexPath:ip];
			if (!cell) continue;
			id post = SCIFeedPostObjectFromFeedCell(cell);
			if (post) {
				if (outPost) *outPost = post;
				if (outCell) *outCell = cell;
				return YES;
			}
		}
	}

	return NO;
}

static id SCIStoryMediaFromOverlay(UIView *overlayView) {
	id sectionController = SCIStorySectionControllerFromOverlay(overlayView);
	id media = SCIObjectForSelector(sectionController, @"currentStoryItem");
	if (media) return media;

	UIViewController *ancestorController = SCIViewControllerForAncestorView(overlayView);
	media = SCIObjectForSelector(ancestorController, @"currentStoryItem");
	if (media) return media;

	return nil;
}

static UIView *SCIDirectMediaView(UIViewController *controller) {
	if (!controller) return nil;

	id viewerContainer = [SCIUtils getIvarForObj:controller name:"_viewerContainerView"];
	if (!viewerContainer) viewerContainer = SCIKVCObject(controller, @"viewerContainerView");

	id mediaView = SCIObjectForSelector(viewerContainer, @"mediaView");
	return [mediaView isKindOfClass:[UIView class]] ? (UIView *)mediaView : nil;
}

static void SCIPauseStoryPlaybackFromOverlaySubview(UIView *overlayView) {
	UIViewController *ancestorController = SCIViewControllerForAncestorView(overlayView);
	if (!ancestorController) return;

	SEL pauseSelector = NSSelectorFromString(@"pauseWithReason:");
	if ([ancestorController respondsToSelector:pauseSelector]) {
		((void (*)(id, SEL, NSInteger))objc_msgSend)(ancestorController, pauseSelector, 1);
	}
}

static void SCIResumeStoryPlaybackFromOverlaySubview(UIView *overlayView) {
	UIViewController *ancestorController = SCIViewControllerForAncestorView(overlayView);
	if (!ancestorController) return;

	SEL resumeSelector = NSSelectorFromString(@"tryResumePlayback");
	if ([ancestorController respondsToSelector:resumeSelector]) {
		((void (*)(id, SEL))objc_msgSend)(ancestorController, resumeSelector);
	}
}

static void SCIPauseDirectPlaybackFromController(UIViewController *controller) {
	UIView *mediaView = SCIDirectMediaView(controller);
	if (!mediaView) return;

	SEL pauseSelector = NSSelectorFromString(@"pauseWithReason:");
	if ([mediaView respondsToSelector:pauseSelector]) {
		((void (*)(id, SEL, NSInteger))objc_msgSend)(mediaView, pauseSelector, 0);
	}
}

static void SCIResumeDirectPlaybackFromController(UIViewController *controller) {
	UIView *mediaView = SCIDirectMediaView(controller);
	if (!mediaView) return;

	SEL playSelector = NSSelectorFromString(@"play");
	if ([mediaView respondsToSelector:playSelector]) {
		((void (*)(id, SEL))objc_msgSend)(mediaView, playSelector);
	}
}

static NSURL *SCIURLFromURLCollectionValue(id collection) {
	if (!collection) return nil;

	NSArray *items = SCIArrayFromCollection(collection);
	if (!items) return SCIURLFromValue(collection);

	for (id item in items) {
		NSURL *url = nil;
		if ([item isKindOfClass:[NSDictionary class]]) {
			NSDictionary *dict = (NSDictionary *)item;
			url = SCIURLFromValue(dict[@"url"] ?: dict[@"urlString"]);
		} else {
			url = SCIURLFromValue(SCIObjectForSelector(item, @"url"));
			if (!url) url = SCIURLFromValue(SCIObjectForSelector(item, @"urlString"));
			if (!url) url = SCIURLFromValue(item);
		}
		if (url) return url;
	}

	return nil;
}

static NSURL *SCIURLFromAssetLikeObject(id object, BOOL videoHint) {
	if (!object) return nil;

	NSArray<NSString *> *primarySelectors = videoHint
		? @[@"videoURL", @"videoUrl", @"downloadURL", @"url", @"urlString"]
		: @[@"imageURL", @"imageUrl", @"displayURL", @"thumbnailURL", @"url", @"urlString"];

	for (NSString *selectorName in primarySelectors) {
		NSURL *url = SCIURLFromValue(SCIObjectForSelector(object, selectorName));
		if (!url) url = SCIURLFromValue(SCIKVCObject(object, selectorName));
		if (url) return url;
	}

	if (videoHint) {
		for (NSString *selectorName in @[@"allVideoURLs", @"sortedVideoURLsBySize", @"videoURLs", @"videoUrls"]) {
			NSURL *url = SCIURLFromURLCollectionValue(SCIObjectForSelector(object, selectorName));
			if (!url) url = SCIURLFromURLCollectionValue(SCIKVCObject(object, selectorName));
			if (url) return url;
		}
	} else {
		SEL imageURLForWidth = NSSelectorFromString(@"imageURLForWidth:");
		if ([object respondsToSelector:imageURLForWidth]) {
			NSURL *url = ((id (*)(id, SEL, CGFloat))objc_msgSend)(object, imageURLForWidth, 100000.0);
			if ([url isKindOfClass:[NSURL class]]) return url;
		}
	}

	return nil;
}

static SCIResolvedMediaEntry *SCIEntryFromMediaObject(id mediaObject) {
	if (!mediaObject) return nil;

	SCIResolvedMediaEntry *entry = [[SCIResolvedMediaEntry alloc] init];
	entry.mediaObject = mediaObject;

	id photoObject = SCIObjectForSelector(mediaObject, @"photo");
	if (photoObject) {
		entry.photoURL = [SCIUtils getPhotoUrl:photoObject];
		if (!entry.photoURL) {
			entry.photoURL = SCIURLFromAssetLikeObject(photoObject, NO);
		}
	}

	if (!entry.photoURL) {
		entry.photoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"imageURL"));
	}
	if (!entry.photoURL) {
		entry.photoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"imageUrl"));
	}
	if (!entry.photoURL) {
		id imageSpecifier = SCIObjectForSelector(mediaObject, @"imageSpecifier");
		entry.photoURL = SCIURLFromValue(SCIObjectForSelector(imageSpecifier, @"url"));
	}
	if (!entry.photoURL) {
		entry.photoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"displayURL"));
	}
	if (!entry.photoURL) {
		entry.photoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"thumbnailURL"));
	}

	id videoObject = SCIObjectForSelector(mediaObject, @"video");
	if (!videoObject) {
		videoObject = SCIObjectForSelector(mediaObject, @"rawVideo");
	}
	if (videoObject) {
		entry.videoURL = [SCIUtils getVideoUrl:videoObject];
		if (!entry.videoURL) {
			entry.videoURL = SCIURLFromAssetLikeObject(videoObject, YES);
		}
	}

	if (!entry.videoURL) {
		entry.videoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"videoURL"));
	}
	if (!entry.videoURL) {
		entry.videoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"videoUrl"));
	}

	NSURL *genericURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"url"));
	if (genericURL) {
		if (!entry.videoURL && SCIIsVideoExtension(genericURL.pathExtension)) {
			entry.videoURL = genericURL;
		} else if (!entry.photoURL && !SCIIsVideoExtension(genericURL.pathExtension)) {
			entry.photoURL = genericURL;
		}
	}

	if (!entry.photoURL && !entry.videoURL) {
		return nil;
	}

	return entry;
}

static NSArray<SCIResolvedMediaEntry *> *SCIEntriesFromMedia(id media) {
	if (!media) return @[];

	NSMutableArray<SCIResolvedMediaEntry *> *entries = [NSMutableArray array];

	NSArray *items = SCIArrayFromCollection(SCIObjectForSelector(media, @"items"));
	if (items.count == 0) {
		items = SCIArrayFromCollection(SCIKVCObject(media, @"items"));
	}

	if (items.count > 0) {
		for (id item in items) {
			SCIResolvedMediaEntry *entry = SCIEntryFromMediaObject(item);
			if (!entry) {
				id nested = SCIObjectForSelector(item, @"media");
				if (!nested) nested = SCIKVCObject(item, @"media");
				entry = SCIEntryFromMediaObject(nested);
			}
			if (!entry) {
				id nested = SCIObjectForSelector(item, @"visualMessage");
				if (!nested) nested = SCIKVCObject(item, @"visualMessage");
				entry = SCIEntryFromMediaObject(nested);
			}
			if (!entry) {
				id nested = SCIObjectForSelector(item, @"item");
				if (!nested) nested = SCIKVCObject(item, @"item");
				entry = SCIEntryFromMediaObject(nested);
			}
			if (entry) {
				// Keep the wrapper item as identity (contains sender/user in direct-message paths).
				entry.mediaObject = item;
			}
			if (entry) [entries addObject:entry];
		}
	} else {
		SCIResolvedMediaEntry *singleEntry = SCIEntryFromMediaObject(media);
		if (!singleEntry) {
			id nested = SCIObjectForSelector(media, @"media");
			if (!nested) nested = SCIKVCObject(media, @"media");
			singleEntry = SCIEntryFromMediaObject(nested);
		}
		if (singleEntry) {
			[entries addObject:singleEntry];
		}
	}

	return entries;
}

static NSInteger SCIClampedIndex(NSInteger index, NSInteger count) {
	if (count <= 0) return 0;
	if (index < 0) return 0;
	if (index >= count) return count - 1;
	return index;
}

static NSString *SCIResolvedDefaultActionIdentifier(NSArray<NSString *> *visibleIdentifiers) {
	if (visibleIdentifiers.count == 0) return nil;

	NSString *saved = [SCIUtils getStringPref:kSCIDefaultActionPrefKey];
	if ([saved isEqualToString:kSCIActionNone]) {
		return kSCIActionNone;
	}
	if (saved.length > 0 && [visibleIdentifiers containsObject:saved]) {
		return saved;
	}

	if ([visibleIdentifiers containsObject:kSCIActionDownloadLibrary]) {
		return kSCIActionDownloadLibrary;
	}

	return visibleIdentifiers.firstObject;
}

static UIImage *SCIButtonDefaultImage(NSString *identifier, SCIActionButtonSource source) {
	if ([identifier isEqualToString:kSCIActionNone]) {
		return SCIActionButtonImage(@"action", @"option", 22.0);
	}

	if (identifier.length > 0) {
		return SCIIconForActionIdentifier(identifier, 22.0);
	}

	if (source == SCIActionButtonSourceFeed) {
		return SCIActionButtonImage(@"action", @"option", 22.0);
	}

	return SCIActionButtonImage(@"action", @"option", 22.0);
}

static id SCIResolveMediaForContext(SCIActionButtonContext *context) {
	if (!context) return nil;
	if (context.mediaOverride) return context.mediaOverride;

	switch (context.source) {
		case SCIActionButtonSourceFeed:
			return SCIFeedMediaFromBarView(context.view);
		case SCIActionButtonSourceReels:
			return SCIReelsMediaFromVerticalUFI(context.view);
		case SCIActionButtonSourceStories:
			return SCIStoryMediaFromOverlay(context.view);
		case SCIActionButtonSourceDirect:
			return SCIDirectResolvedMediaFromController(context.controller);
	}

	return nil;
}

static NSInteger SCIResolveCurrentIndexForContext(SCIActionButtonContext *context) {
	if (!context) return 0;
	if (context.currentIndexOverride >= 0) return context.currentIndexOverride;

	switch (context.source) {
		case SCIActionButtonSourceFeed:
			return SCIFeedCurrentIndexFromBarView(context.view);
		case SCIActionButtonSourceReels:
			return SCIReelsCurrentIndexFromVerticalUFI(context.view);
		case SCIActionButtonSourceStories:
			return 0;
		case SCIActionButtonSourceDirect:
			return SCIDirectCurrentIndexFromController(context.controller);
	}

	return 0;
}

static NSArray<NSString *> *SCIVisibleActionsForEntries(NSArray<SCIResolvedMediaEntry *> *entries, NSInteger currentIndex) {
	if (entries.count == 0) return @[];

	NSInteger idx = SCIClampedIndex(currentIndex, (NSInteger)entries.count);
	SCIResolvedMediaEntry *currentEntry = entries[idx];
	NSURL *currentURL = currentEntry.videoURL ?: currentEntry.photoURL;

	NSMutableArray<NSString *> *visibleActions = [NSMutableArray array];
	for (NSString *identifier in SCIConfiguredActionOrder()) {
		BOOL visible = YES;

		if ([identifier isEqualToString:kSCIActionViewThumbnail]) {
			visible = [SCIUtils getBoolPref:kSCIViewThumbnailPrefKey];
		}

		if ([identifier isEqualToString:kSCIActionExpand]) {
			visible = entries.count > 0;
		}

		if ([identifier isEqualToString:kSCIActionDownloadLibrary] ||
			[identifier isEqualToString:kSCIActionDownloadShare] ||
			[identifier isEqualToString:kSCIActionCopyDownloadLink] ||
			[identifier isEqualToString:kSCIActionDownloadVault]) {
			visible = (currentURL != nil);
		}

		if (visible) {
			[visibleActions addObject:identifier];
		}
	}

	return visibleActions;
}

static NSArray<SCIMediaItem *> *SCIPlayerItemsFromEntries(NSArray<SCIResolvedMediaEntry *> *entries, SCIActionButtonSource source, NSString *username) {
	NSMutableArray<SCIMediaItem *> *items = [NSMutableArray array];
	SCIVaultSaveMetadata *meta = SCIVaultMetadata(source, username);

	for (SCIResolvedMediaEntry *entry in entries) {
		NSURL *url = entry.videoURL ?: entry.photoURL;
		if (!url) continue;

		SCIMediaItem *item = [SCIMediaItem itemWithFileURL:url];
		item.mediaType = entry.videoURL ? SCIMediaItemTypeVideo : SCIMediaItemTypeImage;
		item.vaultSaveSource = SCIVaultSourceForActionSource(source);
		item.vaultMetadata = meta;
		if (username.length > 0) {
			item.title = username;
		}

		[items addObject:item];
	}

	return items;
}

static void SCIShowExtractedVideoCover(NSURL *videoURL, SCIVaultSaveMetadata *metadata) {
	if (!videoURL) {
		[SCIUtils showToastForDuration:2.0 title:@"Cover unavailable"];
		return;
	}

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
		AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
		generator.appliesPreferredTrackTransform = YES;
		generator.maximumSize = CGSizeMake(2160, 2160);

		NSError *error = nil;
		CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.0, 600)
												actualTime:NULL
													 error:&error];
		if (!imageRef) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[SCIUtils showToastForDuration:2.0 title:@"Cover unavailable" subtitle:error.localizedDescription ?: @""];
			});
			return;
		}

		UIImage *image = [UIImage imageWithCGImage:imageRef];
		CGImageRelease(imageRef);

		dispatch_async(dispatch_get_main_queue(), ^{
			[SCIFullScreenMediaPlayer showImage:image metadata:metadata];
		});
	});
}

static void SCIExecuteActionIdentifier(NSString *identifier, SCIActionButtonContext *context, BOOL isDefaultTap) {
	if (identifier.length == 0 || !context) return;

	id media = SCIResolveMediaForContext(context);
	NSArray<SCIResolvedMediaEntry *> *entries = SCIEntriesFromMedia(media);
	if (context.source == SCIActionButtonSourceDirect) {
		SCIDMTrace(@"action=%@ mediaClass=%@ entries=%lu", identifier, SCIClassName(media), (unsigned long)entries.count);
	}

	if (entries.count == 0) {
		[SCIUtils showToastForDuration:2.0 title:@"Media not found"];
		if (context.source == SCIActionButtonSourceDirect) {
			SCIDMTrace(@"no entries resolved; aborting");
		}
		return;
	}

	NSInteger resolvedIndex = SCIClampedIndex(SCIResolveCurrentIndexForContext(context), (NSInteger)entries.count);
	SCIResolvedMediaEntry *currentEntry = entries[resolvedIndex];
	NSURL *currentURL = currentEntry.videoURL ?: currentEntry.photoURL;

	NSString *username = (context.source == SCIActionButtonSourceDirect)
		? SCIDirectUsernameFromController(context.controller)
		: SCIUsernameFromMediaObject(media);
	if (username.length == 0) {
		username = SCIUsernameFromMediaObject(currentEntry.mediaObject);
	}
	if (username.length == 0) {
		for (SCIResolvedMediaEntry *entry in entries) {
			username = SCIUsernameFromMediaObject(entry.mediaObject);
			if (username.length > 0) break;
		}
	}
	if (context.source == SCIActionButtonSourceDirect && username.length > 0) {
		NSString *sessionUsername = SCISessionUsernameFromController(context.controller);
		if (sessionUsername.length > 0 &&
			[username caseInsensitiveCompare:sessionUsername] == NSOrderedSame) {
			SCIDMTrace(@"dropping username because it matches session user: %@", username);
			username = nil;
		}
	}
	SCIVaultSaveMetadata *meta = SCIVaultMetadata(context.source, username);
	if (context.source == SCIActionButtonSourceDirect) {
		SCIDMTrace(@"resolvedIndex=%ld currentURL=%@ username=%@ sourceUsername=%@", (long)resolvedIndex, currentURL.absoluteString ?: @"(nil)", username ?: @"(nil)", meta.sourceUsername ?: @"(nil)");
	}

	if (context.source == SCIActionButtonSourceStories && isDefaultTap) {
		SCIPauseStoryPlaybackFromOverlaySubview(context.view);
	}
	if (context.source == SCIActionButtonSourceDirect && isDefaultTap) {
		SCIPauseDirectPlaybackFromController(context.controller);
	}

	if ([identifier isEqualToString:kSCIActionDownloadLibrary]) {
		if (!currentURL) {
			[SCIUtils showToastForDuration:2.0 title:@"No downloadable media"];
			return;
		}

		BOOL isVideo = (currentEntry.videoURL != nil);
		SCIDownloadDelegate *delegate = SCIDelegateForAction(saveToPhotos);
		delegate.pendingVaultSaveMetadata = meta;
		[delegate downloadFileWithURL:currentURL fileExtension:SCIExtensionForURL(currentURL, isVideo) hudLabel:nil];
		return;
	}

	if ([identifier isEqualToString:kSCIActionDownloadShare]) {
		if (!currentURL) {
			[SCIUtils showToastForDuration:2.0 title:@"No downloadable media"];
			return;
		}

		BOOL isVideo = (currentEntry.videoURL != nil);
		SCIDownloadDelegate *delegate = SCIDelegateForAction(share);
		delegate.pendingVaultSaveMetadata = meta;
		[delegate downloadFileWithURL:currentURL fileExtension:SCIExtensionForURL(currentURL, isVideo) hudLabel:nil];
		return;
	}

	if ([identifier isEqualToString:kSCIActionCopyDownloadLink]) {
		if (!currentURL) {
			[SCIUtils showToastForDuration:2.0 title:@"No link available"];
			return;
		}

		NSURL *normalized = currentURL;
		if ([normalized respondsToSelector:@selector(normalizedURL)]) {
			NSURL *resolved = [normalized normalizedURL];
			if (resolved) normalized = resolved;
		}

		[UIPasteboard generalPasteboard].string = normalized.absoluteString ?: @"";
		[SCIUtils showToastForDuration:1.5 title:@"Link copied"];
		return;
	}

	if ([identifier isEqualToString:kSCIActionDownloadVault]) {
		if (!currentURL) {
			[SCIUtils showToastForDuration:2.0 title:@"No downloadable media"];
			return;
		}

		BOOL isVideo = (currentEntry.videoURL != nil);
		SCIDownloadDelegate *delegate = SCIDelegateForAction(saveToVault);
		delegate.pendingVaultSaveMetadata = meta;
		[delegate downloadFileWithURL:currentURL fileExtension:SCIExtensionForURL(currentURL, isVideo) hudLabel:nil];
		return;
	}

	if ([identifier isEqualToString:kSCIActionExpand]) {
		NSArray<SCIMediaItem *> *playerItems = SCIPlayerItemsFromEntries(entries, context.source, username);
		if (playerItems.count == 0) {
			[SCIUtils showToastForDuration:2.0 title:@"No media to expand"];
			return;
		}

		NSInteger clampedIndex = SCIClampedIndex(resolvedIndex, (NSInteger)playerItems.count);
		[SCIFullScreenMediaPlayer showMediaItems:playerItems startingAtIndex:clampedIndex metadata:meta];
		return;
	}

	if ([identifier isEqualToString:kSCIActionViewThumbnail]) {
		if (![SCIUtils getBoolPref:kSCIViewThumbnailPrefKey]) {
			[SCIUtils showToastForDuration:2.0 title:@"View thumbnail is disabled in settings"];
			return;
		}

		if (currentEntry.photoURL) {
			SCIVaultSaveMetadata *thumbnailMeta = [[SCIVaultSaveMetadata alloc] init];
			thumbnailMeta.source = (int16_t)SCIVaultSourceThumbnail;
			thumbnailMeta.sourceUsername = meta.sourceUsername;
			[SCIFullScreenMediaPlayer showRemoteImageURL:currentEntry.photoURL metadata:thumbnailMeta];
			return;
		}

		if (currentEntry.videoURL) {
			SCIVaultSaveMetadata *thumbnailMeta = [[SCIVaultSaveMetadata alloc] init];
			thumbnailMeta.source = (int16_t)SCIVaultSourceThumbnail;
			thumbnailMeta.sourceUsername = meta.sourceUsername;
			SCIShowExtractedVideoCover(currentEntry.videoURL, thumbnailMeta);
			return;
		}

		[SCIUtils showToastForDuration:2.0 title:@"Cover unavailable"];
		return;
	}
}

static BOOL SCIViewMatchesAnyClassName(UIView *view, NSArray<NSString *> *classNames) {
	if (!view || classNames.count == 0) return NO;

	for (NSString *className in classNames) {
		Class cls = NSClassFromString(className);
		if (cls && [view isKindOfClass:cls]) {
			return YES;
		}
	}

	return NO;
}

static UIView *SCIRecursiveSubviewMatchingClassNames(UIView *root, NSArray<NSString *> *classNames, id targetMedia) {
	if (!root) return nil;

	if (SCIViewMatchesAnyClassName(root, classNames)) {
		if (!targetMedia) return root;
		id media = SCIFeedMediaFromBarView(root);
		if (!media || media == targetMedia) return root;
		
		NSString *mediaPk = SCIStringFromValue(SCIKVCObject(media, @"pk"));
		NSString *targetPk = SCIStringFromValue(SCIKVCObject(targetMedia, @"pk"));
		if (mediaPk && [mediaPk isEqualToString:targetPk]) return root;
	}

	for (UIView *subview in root.subviews) {
		UIView *match = SCIRecursiveSubviewMatchingClassNames(subview, classNames, targetMedia);
		if (match) return match;
	}

	return nil;
}

static UIView *SCIFeedActionContextViewFromMediaView(UIView *view, id targetMedia) {
	if (!view) return nil;

	NSArray<NSString *> *candidateClassNames = @[
		@"IGUFIButtonBarView",
		@"IGUFIInteractionCountsView",
		@"IGSocialUFIView.IGSocialUFIView"
	];

	UIView *walker = view;
	NSInteger depth = 0;
	while (walker && depth < 8) {
		UIView *match = SCIRecursiveSubviewMatchingClassNames(walker, candidateClassNames, targetMedia);
		if (match) return match;

		walker = walker.superview;
		depth++;
	}

	return nil;
}

void SCIHandleFeedExpandLongPress(UIView *view, UILongPressGestureRecognizer *sender) {
	if (!view || !sender || sender.state != UIGestureRecognizerStateBegan) return;
	if (!view.window) return;

	id postObject = nil;
	UIView *feedCell = nil;
	// Tie to the scroll view row under the finger (fixes profile / user-media stacks where hierarchy-only resolution lags the visible row).
	if (!SCIFeedPostAndCellFromScrollContainers(view, sender, &postObject, &feedCell)) {
		feedCell = SCIFeedCellAncestorForView(view);
		if (!feedCell) return;
		postObject = SCIFeedPostObjectFromFeedCell(feedCell);
	}
	if (!feedCell) return;

	UIView *contextView = SCIFeedActionContextViewFromMediaView(feedCell, postObject);
	if (!contextView) {
		contextView = SCIFeedActionContextViewFromMediaView(feedCell, nil);
	}
	if (!contextView) return;

	SCIActionButtonContext *context = nil;
	UIButton *actionButton = (UIButton *)[contextView viewWithTag:kSCIFeedActionButtonTag];
	if ([actionButton isKindOfClass:[UIButton class]]) {
		id associatedContext = objc_getAssociatedObject(actionButton, kSCIActionButtonContextAssocKey);
		if ([associatedContext isKindOfClass:[SCIActionButtonContext class]]) {
			context = (SCIActionButtonContext *)associatedContext;
		}
	}

	if (!context) {
		context = [[SCIActionButtonContext alloc] init];
		context.source = SCIActionButtonSourceFeed;
		context.view = contextView;
	}

	if (postObject) {
		context.mediaOverride = postObject;
	}

	id media = SCIResolveMediaForContext(context);
	NSArray<SCIResolvedMediaEntry *> *entries = SCIEntriesFromMedia(media);
	if (entries.count == 0) return;

	SCIExecuteActionIdentifier(kSCIActionExpand, context, YES);
}

UIButton *SCIActionButtonWithTag(UIView *container, NSInteger tag) {
	UIView *existing = [container viewWithTag:tag];
	if ([existing isKindOfClass:[UIButton class]]) {
		return (UIButton *)existing;
	}

	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	button.tag = tag;
	button.adjustsImageWhenHighlighted = YES;
	button.showsMenuAsPrimaryAction = NO;
	button.clipsToBounds = NO;
	[container addSubview:button];
	return button;
}

void SCIApplyButtonStyle(UIButton *button, SCIActionButtonSource source) {
	if (!button) return;

	button.tintColor = SCIActionButtonTintForSource(source);
	button.backgroundColor = UIColor.clearColor;
	button.layer.cornerRadius = 0.0;
	button.layer.shadowOpacity = 0.0;
	button.layer.shadowRadius = 0.0;
	button.layer.shadowOffset = CGSizeZero;

	if (source == SCIActionButtonSourceReels) {
		button.backgroundColor = UIColor.clearColor;
		button.layer.cornerRadius = CGRectGetHeight(button.bounds) / 2.0;
		button.layer.shadowColor = [UIColor blackColor].CGColor;
		button.layer.shadowOpacity = 0.24;
		button.layer.shadowRadius = 1.8;
		button.layer.shadowOffset = CGSizeMake(0.0, 0.0);
	} else if (source == SCIActionButtonSourceStories || source == SCIActionButtonSourceDirect) {
		// button.layer.shadowColor = [UIColor blackColor].CGColor;
		// button.layer.shadowOpacity = 0.40;
		// button.layer.shadowRadius = 2.0;
		// button.layer.shadowOffset = CGSizeMake(0.0, 2.0);
	}
}

BOOL SCIIsDirectVisualViewerAncestor(UIView *view) {
	UIViewController *ancestorController = SCIViewControllerForAncestorView(view);
	return [ancestorController isKindOfClass:NSClassFromString(@"IGDirectVisualMessageViewerController")];
}

void SCIConfigureActionButton(UIButton *button, SCIActionButtonContext *context) {
	if (!button || !context) return;

	id media = SCIResolveMediaForContext(context);
	NSArray<SCIResolvedMediaEntry *> *entries = SCIEntriesFromMedia(media);
	NSInteger index = SCIResolveCurrentIndexForContext(context);
	NSArray<NSString *> *visibleActions = SCIVisibleActionsForEntries(entries, index);

	if (visibleActions.count == 0) {
		button.hidden = YES;
		button.menu = nil;
		return;
	}

	button.hidden = NO;

	NSString *defaultIdentifier = SCIResolvedDefaultActionIdentifier(visibleActions);
	UIImage *defaultImage = SCIButtonDefaultImage(defaultIdentifier, context.source);
	[button setImage:[defaultImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
	BOOL shouldOpenMenuOnTap = [defaultIdentifier isEqualToString:kSCIActionNone];

	__weak UIButton *weakButton = button;
	UIAction *oldHapticAction = objc_getAssociatedObject(button, kSCIActionButtonHapticActionAssocKey);
	if (oldHapticAction) {
		[button removeAction:oldHapticAction forControlEvents:UIControlEventTouchDown];
	}
	UIAction *newHapticAction = [UIAction actionWithHandler:^(__unused UIAction *action) {
		SCIPlayActionButtonTapHaptic();
	}];
	[button addAction:newHapticAction forControlEvents:UIControlEventTouchDown];
	objc_setAssociatedObject(button, kSCIActionButtonHapticActionAssocKey, newHapticAction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	UIAction *oldTapAction = objc_getAssociatedObject(button, kSCIActionButtonTapActionAssocKey);
	if (oldTapAction) {
		[button removeAction:oldTapAction forControlEvents:UIControlEventTouchUpInside];
	}
	if (shouldOpenMenuOnTap) {
		objc_setAssociatedObject(button, kSCIActionButtonTapActionAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	} else {
		UIAction *newTapAction = [UIAction actionWithHandler:^(__unused UIAction *action) {
			UIButton *strongButton = weakButton;
			SCIActionButtonContext *strongContext = objc_getAssociatedObject(strongButton, kSCIActionButtonContextAssocKey);
			if (!strongContext) return;

			NSString *tapIdentifier = SCIResolvedDefaultActionIdentifier(SCIVisibleActionsForEntries(SCIEntriesFromMedia(SCIResolveMediaForContext(strongContext)), SCIResolveCurrentIndexForContext(strongContext)));
			SCIExecuteActionIdentifier(tapIdentifier, strongContext, YES);
		}];
		[button addAction:newTapAction forControlEvents:UIControlEventTouchUpInside];
		objc_setAssociatedObject(button, kSCIActionButtonTapActionAssocKey, newTapAction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	NSMutableArray<UIMenuElement *> *menuElements = [NSMutableArray arrayWithCapacity:visibleActions.count];
	for (NSString *identifier in visibleActions) {
		UIAction *menuAction = [UIAction actionWithTitle:SCITitleForActionIdentifier(identifier)
												   image:SCIIconForActionIdentifier(identifier, 18.0)
											  identifier:nil
												 handler:^(__unused UIAction *action) {
			SCIExecuteActionIdentifier(identifier, context, NO);

			if (context.source == SCIActionButtonSourceStories) {
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					SCIResumeStoryPlaybackFromOverlaySubview(context.view);
				});
			} else if (context.source == SCIActionButtonSourceDirect) {
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					SCIResumeDirectPlaybackFromController(context.controller);
				});
			}
		}];
		[menuElements addObject:menuAction];
	}

	button.menu = [UIMenu menuWithTitle:@"" children:menuElements];
	button.showsMenuAsPrimaryAction = shouldOpenMenuOnTap;

	objc_setAssociatedObject(button, kSCIActionButtonContextAssocKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIView *SCIFeedAnyButtonFromBarView(UIView *barView) {
	if (!barView) return nil;

	id saveIvar = [SCIUtils getIvarForObj:barView name:"_saveButton"];
	if ([saveIvar isKindOfClass:[UIView class]]) {
		return (UIView *)saveIvar;
	}

	for (NSString *selectorName in @[@"sendButton", @"commentButton", @"likeButton", @"saveButton"]) {
		id candidate = SCIObjectForSelector(barView, selectorName);
		if ([candidate isKindOfClass:[UIView class]]) {
			return (UIView *)candidate;
		}
	}

	return nil;
}

CGRect SCIFeedAnyButtonFrameFromBarView(UIView *barView) {
	UIView *anyButton = SCIFeedAnyButtonFromBarView(barView);
	if (anyButton) {
		return anyButton.frame;
	}

	return CGRectMake(0.0, 0.0, 40.0, 48.0);
}

UIView *SCIFeedFirstRightButtonFromBarView(UIView *barView) {
	if (!barView) return nil;

	id visualSearch = SCIObjectForSelector(barView, @"visualSearchButton");
	if ([visualSearch isKindOfClass:[UIView class]]) {
		UIView *view = (UIView *)visualSearch;
		if (!view.hidden && view.superview) return view;
	}

	id visualSearchIvar = [SCIUtils getIvarForObj:barView name:"_visualSearchButton"];
	if ([visualSearchIvar isKindOfClass:[UIView class]]) {
		UIView *view = (UIView *)visualSearchIvar;
		if (!view.hidden && view.superview) return view;
	}

	id saveButton = SCIObjectForSelector(barView, @"saveButton");
	if ([saveButton isKindOfClass:[UIView class]]) {
		UIView *view = (UIView *)saveButton;
		if (!view.hidden && view.superview) return view;
	}

	id saveButtonIvar = [SCIUtils getIvarForObj:barView name:"_saveButton"];
	if ([saveButtonIvar isKindOfClass:[UIView class]]) {
		UIView *view = (UIView *)saveButtonIvar;
		if (!view.hidden && view.superview) return view;
	}

	return nil;
}
