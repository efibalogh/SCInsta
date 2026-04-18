// DownloadButton.xm
//
// Regram-style action button for media surfaces:
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

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Downloader/Download.h"
#import "../../MediaPreview/SCIMediaItem.h"
#import "../../MediaPreview/SCIFullScreenMediaPlayer.h"
#import "../../Vault/SCIVaultFile.h"
#import "../../Vault/SCIVaultSaveMetadata.h"

@interface IGUFIButtonBarView : UIView
@end

typedef NS_ENUM(NSInteger, SCIActionButtonSource) {
	SCIActionButtonSourceFeed = 1,
	SCIActionButtonSourceReels = 2,
	SCIActionButtonSourceStories = 3,
	SCIActionButtonSourceDirect = 4
};

static NSString * const kSCIShowActionButtonPrefKey = @"show_download_button";
static NSString * const kSCIDefaultActionPrefKey = @"download_button_default_action";
static NSString * const kSCIViewThumbnailPrefKey = @"view_thumbnail";

static NSString * const kSCIActionNone = @"none";
static NSString * const kSCIActionDownloadLibrary = @"download_library";
static NSString * const kSCIActionDownloadShare = @"download_share";
static NSString * const kSCIActionCopyDownloadLink = @"copy_download_link";
static NSString * const kSCIActionDownloadVault = @"download_vault";
static NSString * const kSCIActionExpand = @"expand";
static NSString * const kSCIActionViewThumbnail = @"view_thumbnail";

static NSInteger const kSCIFeedActionButtonTag = 921341;
static NSInteger const kSCIReelsActionButtonTag = 921342;
static NSInteger const kSCIStoriesActionButtonTag = 921343;
static NSInteger const kSCIDirectActionButtonTag = 921344;
static NSInteger const kSCIDirectSeenButtonTag = 921345;

static const void *kSCIActionButtonContextAssocKey = &kSCIActionButtonContextAssocKey;
static const void *kSCIActionButtonTapActionAssocKey = &kSCIActionButtonTapActionAssocKey;
static const void *kSCIReelsActionBottomConstraintAssocKey = &kSCIReelsActionBottomConstraintAssocKey;
static const void *kSCIReelsActionCenterXConstraintAssocKey = &kSCIReelsActionCenterXConstraintAssocKey;
static const void *kSCIReelsActionWidthConstraintAssocKey = &kSCIReelsActionWidthConstraintAssocKey;
static const void *kSCIReelsActionHeightConstraintAssocKey = &kSCIReelsActionHeightConstraintAssocKey;
static const void *kSCIDirectActionBottomConstraintAssocKey = &kSCIDirectActionBottomConstraintAssocKey;
static const void *kSCIDirectActionTrailingConstraintAssocKey = &kSCIDirectActionTrailingConstraintAssocKey;
static const void *kSCIDirectActionWidthConstraintAssocKey = &kSCIDirectActionWidthConstraintAssocKey;
static const void *kSCIDirectActionHeightConstraintAssocKey = &kSCIDirectActionHeightConstraintAssocKey;
static const void *kSCIDirectSeenBottomConstraintAssocKey = &kSCIDirectSeenBottomConstraintAssocKey;
static const void *kSCIDirectSeenWidthConstraintAssocKey = &kSCIDirectSeenWidthConstraintAssocKey;
static const void *kSCIDirectSeenHeightConstraintAssocKey = &kSCIDirectSeenHeightConstraintAssocKey;
static const void *kSCIDirectSeenTrailingToActionAssocKey = &kSCIDirectSeenTrailingToActionAssocKey;
static const void *kSCIDirectSeenTrailingToOverlayAssocKey = &kSCIDirectSeenTrailingToOverlayAssocKey;
static const void *kSCIDirectSeenTapActionAssocKey = &kSCIDirectSeenTapActionAssocKey;

@interface SCIResolvedMediaEntry : NSObject
@property (nonatomic, strong, nullable) id mediaObject;
@property (nonatomic, strong, nullable) NSURL *photoURL;
@property (nonatomic, strong, nullable) NSURL *videoURL;
@end

@implementation SCIResolvedMediaEntry
@end

@interface SCIActionButtonContext : NSObject
@property (nonatomic, assign) SCIActionButtonSource source;
@property (nonatomic, weak, nullable) UIView *view;
@property (nonatomic, weak, nullable) UIViewController *controller;
@end

@implementation SCIActionButtonContext
@end

static id SCIObjectForSelector(id target, NSString *selectorName) {
	if (!target || selectorName.length == 0) return nil;

	SEL selector = NSSelectorFromString(selectorName);
	if (![target respondsToSelector:selector]) return nil;

	return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static id SCIKVCObject(id target, NSString *key) {
	if (!target || key.length == 0) return nil;

	@try {
		return [target valueForKey:key];
	} @catch (__unused NSException *exception) {
		return nil;
	}
}

static NSArray *SCIArrayFromCollection(id collection) {
	if (!collection ||
		[collection isKindOfClass:[NSDictionary class]] ||
		[collection isKindOfClass:[NSString class]] ||
		[collection isKindOfClass:[NSURL class]]) {
		return nil;
	}

	if ([collection isKindOfClass:[NSArray class]]) {
		return collection;
	}

	if ([collection isKindOfClass:[NSOrderedSet class]]) {
		return [(NSOrderedSet *)collection array];
	}

	if ([collection isKindOfClass:[NSSet class]]) {
		return [(NSSet *)collection allObjects];
	}

	if ([collection conformsToProtocol:@protocol(NSFastEnumeration)]) {
		NSMutableArray *array = [NSMutableArray array];
		for (id item in collection) {
			[array addObject:item];
		}
		return array;
	}

	return nil;
}

static NSURL *SCIURLFromValue(id value) {
	if (!value) return nil;

	if ([value isKindOfClass:[NSURL class]]) {
		return value;
	}

	if ([value isKindOfClass:[NSString class]]) {
		NSString *string = (NSString *)value;
		if (string.length == 0) return nil;
		return [NSURL URLWithString:string];
	}

	return nil;
}

static NSString *SCIStringFromValue(id value) {
	if ([value isKindOfClass:[NSString class]]) return value;
	if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
	return nil;
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

static NSString *SCIUsernameFromUserObject(id user) {
	if (!user) return nil;

	id username = SCIObjectForSelector(user, @"username");
	if (!username) {
		username = SCIKVCObject(user, @"username");
	}

	if ([username isKindOfClass:[NSString class]] && [(NSString *)username length] > 0) {
		return (NSString *)username;
	}

	return nil;
}

static NSString *SCIUsernameFromMediaObject(id media) {
	if (!media) return nil;

	id user = SCIObjectForSelector(media, @"user");
	if (!user) user = SCIObjectForSelector(media, @"owner");
	if (!user) user = SCIObjectForSelector(media, @"author");
	if (!user) user = SCIKVCObject(media, @"user");

	return SCIUsernameFromUserObject(user);
}

static UIViewController *SCIViewControllerForAncestorView(UIView *view) {
	if (!view) return nil;

	id candidate = SCIObjectForSelector(view, @"_viewControllerForAncestor");
	if ([candidate isKindOfClass:[UIViewController class]]) {
		return (UIViewController *)candidate;
	}

	return [SCIUtils viewControllerForAncestralView:view];
}

static UIImage *SCIActionButtonImage(NSString *resourceName, NSString *systemFallback, CGFloat maxPointSize) {
	UIImage *image = [SCIUtils sci_resourceImageNamed:resourceName template:YES maxPointSize:maxPointSize];
	if (image) return image;

	UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:maxPointSize weight:UIImageSymbolWeightRegular];
	return [UIImage systemImageNamed:systemFallback withConfiguration:config];
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
		return SCIActionButtonImage(@"download", @"arrow.down", size);
	}
	if ([identifier isEqualToString:kSCIActionDownloadShare]) {
		return SCIActionButtonImage(@"share", @"square.and.arrow.up", size);
	}
	if ([identifier isEqualToString:kSCIActionCopyDownloadLink]) {
		return SCIActionButtonImage(@"link", @"link", size);
	}
	if ([identifier isEqualToString:kSCIActionDownloadVault]) {
		return SCIActionButtonImage(@"photo_gallery", @"tray.and.arrow.down", size);
	}
	if ([identifier isEqualToString:kSCIActionExpand]) {
		return SCIActionButtonImage(@"fullscreen", @"arrow.up.left.and.arrow.down.right", size);
	}
	if ([identifier isEqualToString:kSCIActionViewThumbnail]) {
		return SCIActionButtonImage(@"photo_filled", @"photo", size);
	}

	return SCIActionButtonImage(@"action", @"ellipsis", size);
}

static NSString *SCITitleForActionIdentifier(NSString *identifier) {
	if ([identifier isEqualToString:kSCIActionDownloadLibrary]) return @"Download";
	if ([identifier isEqualToString:kSCIActionDownloadShare]) return @"Share";
	if ([identifier isEqualToString:kSCIActionCopyDownloadLink]) return @"Copy link";
	if ([identifier isEqualToString:kSCIActionDownloadVault]) return @"Download to Vault";
	if ([identifier isEqualToString:kSCIActionExpand]) return @"Expand";
	if ([identifier isEqualToString:kSCIActionViewThumbnail]) return @"View thumbnail";
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

	id currentPage = SCIObjectForSelector(indicator, @"currentPage");
	NSString *pageString = SCIStringFromValue(currentPage);
	if (pageString.length > 0) return pageString.integerValue;

	currentPage = SCIKVCObject(indicator, @"currentPage");
	pageString = SCIStringFromValue(currentPage);
	if (pageString.length > 0) return pageString.integerValue;

	return -1;
}

static NSInteger SCIFeedCurrentIndexFromBarView(UIView *barView) {
	if (!barView) return -1;

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

static id SCIStoryMediaFromOverlay(UIView *overlayView) {
	id sectionController = SCIStorySectionControllerFromOverlay(overlayView);
	id media = SCIObjectForSelector(sectionController, @"currentStoryItem");
	if (media) return media;

	UIViewController *ancestorController = SCIViewControllerForAncestorView(overlayView);
	media = SCIObjectForSelector(ancestorController, @"currentStoryItem");
	if (media) return media;

	return nil;
}

static id SCIDirectCurrentMessageFromController(UIViewController *controller) {
	if (!controller) return nil;

	id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
	if (!dataSource) dataSource = SCIKVCObject(controller, @"dataSource");

	id message = [SCIUtils getIvarForObj:dataSource name:"_currentMessage"];
	if (!message) message = SCIKVCObject(dataSource, @"currentMessage");

	return message;
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

static SCIResolvedMediaEntry *SCIEntryFromMediaObject(id mediaObject) {
	if (!mediaObject) return nil;

	SCIResolvedMediaEntry *entry = [[SCIResolvedMediaEntry alloc] init];
	entry.mediaObject = mediaObject;

	id photoObject = SCIObjectForSelector(mediaObject, @"photo");
	if (photoObject) {
		entry.photoURL = [SCIUtils getPhotoUrl:photoObject];
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
			if (entry) [entries addObject:entry];
		}
	} else {
		SCIResolvedMediaEntry *singleEntry = SCIEntryFromMediaObject(media);
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
		return SCIActionButtonImage(@"action", @"option", 20.0);
	}

	if (identifier.length > 0) {
		return SCIIconForActionIdentifier(identifier, 22.0);
	}

	if (source == SCIActionButtonSourceFeed) {
		return SCIActionButtonImage(@"action", @"option", 20.0);
	}

	return SCIActionButtonImage(@"more", @"ellipsis", 20.0);
}

static id SCIResolveMediaForContext(SCIActionButtonContext *context) {
	if (!context) return nil;

	switch (context.source) {
		case SCIActionButtonSourceFeed:
			return SCIFeedMediaFromBarView(context.view);
		case SCIActionButtonSourceReels:
			return SCIReelsMediaFromVerticalUFI(context.view);
		case SCIActionButtonSourceStories:
			return SCIStoryMediaFromOverlay(context.view);
		case SCIActionButtonSourceDirect:
			return SCIDirectCurrentMessageFromController(context.controller);
	}

	return nil;
}

static NSInteger SCIResolveCurrentIndexForContext(SCIActionButtonContext *context) {
	if (!context) return 0;

	switch (context.source) {
		case SCIActionButtonSourceFeed:
			return SCIFeedCurrentIndexFromBarView(context.view);
		case SCIActionButtonSourceReels:
			return SCIReelsCurrentIndexFromVerticalUFI(context.view);
		case SCIActionButtonSourceStories:
		case SCIActionButtonSourceDirect:
			return 0;
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

static void SCIShowExtractedVideoCover(NSURL *videoURL) {
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
			[SCIFullScreenMediaPlayer showImage:image];
		});
	});
}

static void SCIExecuteActionIdentifier(NSString *identifier, SCIActionButtonContext *context, BOOL isDefaultTap) {
	if (identifier.length == 0 || !context) return;

	id media = SCIResolveMediaForContext(context);
	NSArray<SCIResolvedMediaEntry *> *entries = SCIEntriesFromMedia(media);

	if (entries.count == 0) {
		[SCIUtils showToastForDuration:2.0 title:@"Media not found"];
		return;
	}

	NSInteger resolvedIndex = SCIClampedIndex(SCIResolveCurrentIndexForContext(context), (NSInteger)entries.count);
	SCIResolvedMediaEntry *currentEntry = entries[resolvedIndex];
	NSURL *currentURL = currentEntry.videoURL ?: currentEntry.photoURL;

	NSString *username = SCIUsernameFromMediaObject(media);
	SCIVaultSaveMetadata *meta = SCIVaultMetadata(context.source, username);

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
			[SCIFullScreenMediaPlayer showRemoteImageURL:currentEntry.photoURL];
			return;
		}

		if (currentEntry.videoURL) {
			SCIShowExtractedVideoCover(currentEntry.videoURL);
			return;
		}

		[SCIUtils showToastForDuration:2.0 title:@"Cover unavailable"];
		return;
	}
}

static UIButton *SCIActionButtonWithTag(UIView *container, NSInteger tag) {
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

static void SCIApplyButtonStyle(UIButton *button, SCIActionButtonSource source) {
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

static BOOL SCIIsDirectVisualViewerAncestor(UIView *view) {
	UIViewController *ancestorController = SCIViewControllerForAncestorView(view);
	return [ancestorController isKindOfClass:NSClassFromString(@"IGDirectVisualMessageViewerController")];
}

static void SCIConfigureActionButton(UIButton *button, SCIActionButtonContext *context) {
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

static CGRect SCIFeedAnyButtonFrameFromBarView(UIView *barView) {
	UIView *anyButton = SCIFeedAnyButtonFromBarView(barView);
	if (anyButton) {
		return anyButton.frame;
	}

	return CGRectMake(0.0, 0.0, 40.0, 48.0);
}

static UIView *SCIFeedFirstRightButtonFromBarView(UIView *barView) {
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

static void SCIInstallFeedActionButton(UIView *barView) {
	if (!barView) return;

	UIButton *button = (UIButton *)[barView viewWithTag:kSCIFeedActionButtonTag];

	if (![SCIUtils getBoolPref:kSCIShowActionButtonPrefKey]) {
		[button removeFromSuperview];
		return;
	}

	button = SCIActionButtonWithTag(barView, kSCIFeedActionButtonTag);

	SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
	context.source = SCIActionButtonSourceFeed;
	context.view = barView;

	SCIConfigureActionButton(button, context);
	if (button.hidden) return;

	CGRect anyFrame = SCIFeedAnyButtonFrameFromBarView(barView);
	UIView *firstRightButton = SCIFeedFirstRightButtonFromBarView(barView);
	if (!firstRightButton) {
		[button removeFromSuperview];
		return;
	}

	CGFloat width = CGRectGetWidth(anyFrame) > 0.0 ? CGRectGetWidth(anyFrame) : 40.0;
	CGFloat xAnchor = CGRectGetMinX(firstRightButton.frame);

	button.frame = CGRectMake(xAnchor - width, CGRectGetMinY(anyFrame) + 2.0, width, CGRectGetHeight(anyFrame));
	SCIApplyButtonStyle(button, SCIActionButtonSourceFeed);
}

static void SCIInstallReelsActionButton(UIView *verticalUFIView) {
	if (!verticalUFIView) return;

	UIButton *button = (UIButton *)[verticalUFIView viewWithTag:kSCIReelsActionButtonTag];

	if (![SCIUtils getBoolPref:kSCIShowActionButtonPrefKey]) {
		[button removeFromSuperview];
		return;
	}

	button = SCIActionButtonWithTag(verticalUFIView, kSCIReelsActionButtonTag);

	SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
	context.source = SCIActionButtonSourceReels;
	context.view = verticalUFIView;

	SCIConfigureActionButton(button, context);
	if (button.hidden) return;

	CGFloat size = 52.0;
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

		[NSLayoutConstraint activateConstraints:@[
			bottomConstraint,
			centerXConstraint,
			widthConstraint,
			heightConstraint
		]];

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

static void SCIInstallStoriesActionButton(UIView *overlayView) {
	if (!overlayView) return;

	if (SCIIsDirectVisualViewerAncestor(overlayView)) {
		UIButton *existing = (UIButton *)[overlayView viewWithTag:kSCIStoriesActionButtonTag];
		[existing removeFromSuperview];
		return;
	}

	UIButton *button = (UIButton *)[overlayView viewWithTag:kSCIStoriesActionButtonTag];

	if (![SCIUtils getBoolPref:kSCIShowActionButtonPrefKey]) {
		[button removeFromSuperview];
		return;
	}

	button = SCIActionButtonWithTag(overlayView, kSCIStoriesActionButtonTag);

	SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
	context.source = SCIActionButtonSourceStories;
	context.view = overlayView;

	SCIConfigureActionButton(button, context);
	if (button.hidden) return;

	UIView *mediaView = [SCIUtils getIvarForObj:overlayView name:"_mediaView"];
	UIView *footerContainer = [SCIUtils getIvarForObj:overlayView name:"_footerContainerView"];
	if (![mediaView isKindOfClass:[UIView class]]) mediaView = nil;
	if (![footerContainer isKindOfClass:[UIView class]]) footerContainer = nil;

	if (!mediaView && !footerContainer) {
		[button removeFromSuperview];
		return;
	}

	CGFloat size = 38.0;
	CGFloat y = 0.0;

	if (mediaView) {
		CGRect mediaFrame = mediaView.frame;
		y = CGRectGetMaxY(mediaFrame) - size - 7.0;
		if (footerContainer && CGRectGetMinY(footerContainer.frame) < CGRectGetMaxY(mediaFrame)) {
			y -= 50.0;
		}
	} else {
		y = CGRectGetMinY(footerContainer.frame) - size - 12.0;
	}

	id showCommentsPreview = [SCIUtils getIvarForObj:overlayView name:"_showCommentsPreview"];
	BOOL hasCommentsPreview = [showCommentsPreview respondsToSelector:@selector(boolValue)] ? [showCommentsPreview boolValue] : NO;
	if (hasCommentsPreview) {
		UIView *hypeFaceswarmView = [SCIUtils getIvarForObj:overlayView name:"_hypeFaceswarmView"];
		if ([hypeFaceswarmView isKindOfClass:[UIView class]] && (y + size) > CGRectGetMinY(hypeFaceswarmView.frame)) {
			y = CGRectGetMinY(hypeFaceswarmView.frame) - size - 2.0;
		} else {
			y -= 35.0;
		}
	}

	CGFloat x = CGRectGetWidth(overlayView.frame) - size - 7.0;

	button.frame = CGRectMake(x, y, size, size);
	SCIApplyButtonStyle(button, SCIActionButtonSourceStories);
}

static UIView *SCIDirectOverlayView(UIViewController *controller) {
	if (!controller) return nil;

	id viewerContainer = [SCIUtils getIvarForObj:controller name:"_viewerContainerView"];
	if (!viewerContainer) viewerContainer = SCIKVCObject(controller, @"viewerContainerView");

	id overlay = SCIObjectForSelector(viewerContainer, @"overlayView");
	return [overlay isKindOfClass:[UIView class]] ? (UIView *)overlay : nil;
}

static BOOL SCIShouldShowDirectSeenButton(void) {
	// Reuse SCInsta's manual seen toggle for visual DM seen button visibility.
	return [SCIUtils getBoolPref:@"remove_lastseen"];
}

static CGFloat SCIHeightFromFrameLikeObject(id object) {
	if (!object) return 0.0;

	if ([object isKindOfClass:[UIView class]]) {
		return ((UIView *)object).frame.size.height;
	}

	@try {
		id frameValue = [object valueForKey:@"frame"];
		if ([frameValue isKindOfClass:[NSValue class]]) {
			return ((NSValue *)frameValue).CGRectValue.size.height;
		}
	} @catch (__unused NSException *exception) {
	}

	return 0.0;
}

static CGFloat SCIDirectBottomOffset(UIViewController *controller) {
	if (!controller) return 40.0;

	id inputView = [SCIUtils getIvarForObj:controller name:"_inputView"];
	NSInteger offset = (NSInteger)(controller.view.safeAreaInsets.bottom + 40.0);
	if (inputView) {
		offset = (NSInteger)(SCIHeightFromFrameLikeObject(inputView) + (CGFloat)offset);
	}

	return (CGFloat)offset;
}

static void SCIMarkDirectVisualMessageAsSeen(UIViewController *controller) {
	if (!controller) return;

	id message = SCIDirectCurrentMessageFromController(controller);
	if (!message) {
		[SCIUtils showToastForDuration:1.5 title:@"Message not found"];
		return;
	}

	id responders = [SCIUtils getIvarForObj:controller name:"_eventResponders"];
	if (!responders) responders = SCIKVCObject(controller, @"eventResponders");

	SEL beginPlaybackSelector = NSSelectorFromString(@"visualMessageViewerController:didBeginPlaybackForVisualMessage:atIndex:");
	for (id responder in SCIArrayFromCollection(responders) ?: @[]) {
		if ([responder respondsToSelector:beginPlaybackSelector]) {
			((void (*)(id, SEL, id, id, NSInteger))objc_msgSend)(responder, beginPlaybackSelector, controller, message, 0);
			break;
		}
	}

	SEL overlayTapSelector = NSSelectorFromString(@"fullscreenOverlay:didTapInRegion:");
	if ([controller respondsToSelector:overlayTapSelector]) {
		((void (*)(id, SEL, id, NSInteger))objc_msgSend)(controller, overlayTapSelector, nil, 3);
	}

	[SCIUtils showToastForDuration:1.5 title:@"Marked as seen"];
}

static void SCIInstallDirectActionButton(UIViewController *controller) {
	UIView *overlay = SCIDirectOverlayView(controller);
	if (!overlay) return;

	UIButton *button = (UIButton *)[overlay viewWithTag:kSCIDirectActionButtonTag];
	UIButton *seenButton = (UIButton *)[overlay viewWithTag:kSCIDirectSeenButtonTag];
	BOOL shouldShowActionButton = [SCIUtils getBoolPref:kSCIShowActionButtonPrefKey];
	BOOL shouldShowSeenButton = SCIShouldShowDirectSeenButton();

	if (!shouldShowActionButton && !shouldShowSeenButton) {
		[button removeFromSuperview];
		[seenButton removeFromSuperview];
		return;
	}

	if (shouldShowActionButton) {
		button = SCIActionButtonWithTag(overlay, kSCIDirectActionButtonTag);

		SCIActionButtonContext *context = [[SCIActionButtonContext alloc] init];
		context.source = SCIActionButtonSourceDirect;
		context.controller = controller;

		SCIConfigureActionButton(button, context);
	} else {
		[button removeFromSuperview];
		button = nil;
	}

	CGFloat size = 44.0;
	CGFloat bottomOffset = SCIDirectBottomOffset(controller);
	BOOL actionButtonVisible = (button && !button.hidden && button.superview == overlay);

	if (button) {
		button.translatesAutoresizingMaskIntoConstraints = NO;

		NSLayoutConstraint *bottomConstraint = objc_getAssociatedObject(button, kSCIDirectActionBottomConstraintAssocKey);
		NSLayoutConstraint *trailingConstraint = objc_getAssociatedObject(button, kSCIDirectActionTrailingConstraintAssocKey);
		NSLayoutConstraint *widthConstraint = objc_getAssociatedObject(button, kSCIDirectActionWidthConstraintAssocKey);
		NSLayoutConstraint *heightConstraint = objc_getAssociatedObject(button, kSCIDirectActionHeightConstraintAssocKey);

		if (!bottomConstraint || !trailingConstraint || !widthConstraint || !heightConstraint) {
			trailingConstraint = [button.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-10.0];
			bottomConstraint = [button.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor constant:-bottomOffset];
			widthConstraint = [button.widthAnchor constraintEqualToConstant:size];
			heightConstraint = [button.heightAnchor constraintEqualToConstant:size];

			[NSLayoutConstraint activateConstraints:@[
				trailingConstraint,
				bottomConstraint,
				widthConstraint,
				heightConstraint
			]];

			objc_setAssociatedObject(button, kSCIDirectActionBottomConstraintAssocKey, bottomConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			objc_setAssociatedObject(button, kSCIDirectActionTrailingConstraintAssocKey, trailingConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			objc_setAssociatedObject(button, kSCIDirectActionWidthConstraintAssocKey, widthConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			objc_setAssociatedObject(button, kSCIDirectActionHeightConstraintAssocKey, heightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		trailingConstraint.constant = -10.0;
		bottomConstraint.constant = -bottomOffset;
		widthConstraint.constant = size;
		heightConstraint.constant = size;

		SCIApplyButtonStyle(button, SCIActionButtonSourceDirect);
		[overlay bringSubviewToFront:button];
	}

	if (!shouldShowSeenButton) {
		[seenButton removeFromSuperview];
		return;
	}

	seenButton = SCIActionButtonWithTag(overlay, kSCIDirectSeenButtonTag);
	seenButton.translatesAutoresizingMaskIntoConstraints = NO;
	seenButton.showsMenuAsPrimaryAction = NO;
	seenButton.adjustsImageWhenHighlighted = YES;
	UIImage *seenImage = SCIActionButtonImage(@"eye", @"eye", 20.0);
	[seenButton setImage:[seenImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
	// seenButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
	SCIApplyButtonStyle(seenButton, SCIActionButtonSourceDirect);

	UIAction *oldSeenTapAction = objc_getAssociatedObject(seenButton, kSCIDirectSeenTapActionAssocKey);
	if (oldSeenTapAction) {
		[seenButton removeAction:oldSeenTapAction forControlEvents:UIControlEventTouchUpInside];
	}
	__weak UIViewController *weakController = controller;
	UIAction *newSeenTapAction = [UIAction actionWithHandler:^(__unused UIAction *action) {
		UIViewController *strongController = weakController;
		if (!strongController) return;
		SCIMarkDirectVisualMessageAsSeen(strongController);
	}];
	[seenButton addAction:newSeenTapAction forControlEvents:UIControlEventTouchUpInside];
	objc_setAssociatedObject(seenButton, kSCIDirectSeenTapActionAssocKey, newSeenTapAction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	NSLayoutConstraint *seenBottomConstraint = objc_getAssociatedObject(seenButton, kSCIDirectSeenBottomConstraintAssocKey);
	NSLayoutConstraint *seenWidthConstraint = objc_getAssociatedObject(seenButton, kSCIDirectSeenWidthConstraintAssocKey);
	NSLayoutConstraint *seenHeightConstraint = objc_getAssociatedObject(seenButton, kSCIDirectSeenHeightConstraintAssocKey);

	if (!seenBottomConstraint || !seenWidthConstraint || !seenHeightConstraint) {
		seenBottomConstraint = [seenButton.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor constant:-bottomOffset];
		seenWidthConstraint = [seenButton.widthAnchor constraintEqualToConstant:size];
		seenHeightConstraint = [seenButton.heightAnchor constraintEqualToConstant:size];

		[NSLayoutConstraint activateConstraints:@[
			seenBottomConstraint,
			seenWidthConstraint,
			seenHeightConstraint
		]];

		objc_setAssociatedObject(seenButton, kSCIDirectSeenBottomConstraintAssocKey, seenBottomConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(seenButton, kSCIDirectSeenWidthConstraintAssocKey, seenWidthConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(seenButton, kSCIDirectSeenHeightConstraintAssocKey, seenHeightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	seenBottomConstraint.constant = -bottomOffset;
	seenWidthConstraint.constant = size;
	seenHeightConstraint.constant = size;

	NSLayoutConstraint *seenTrailingToAction = objc_getAssociatedObject(seenButton, kSCIDirectSeenTrailingToActionAssocKey);
	NSLayoutConstraint *seenTrailingToOverlay = objc_getAssociatedObject(seenButton, kSCIDirectSeenTrailingToOverlayAssocKey);
	if (seenTrailingToAction) {
		seenTrailingToAction.active = NO;
	}
	if (seenTrailingToOverlay) {
		seenTrailingToOverlay.active = NO;
	}

	if (actionButtonVisible) {
		seenTrailingToAction = [seenButton.trailingAnchor constraintEqualToAnchor:button.leadingAnchor constant:-5.0];
		seenTrailingToAction.active = YES;
		objc_setAssociatedObject(seenButton, kSCIDirectSeenTrailingToActionAssocKey, seenTrailingToAction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	} else {
		seenTrailingToOverlay = [seenButton.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-10.0];
		seenTrailingToOverlay.active = YES;
		objc_setAssociatedObject(seenButton, kSCIDirectSeenTrailingToOverlayAssocKey, seenTrailingToOverlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	[overlay bringSubviewToFront:seenButton];
}

%hook IGUFIButtonBarView
- (void)layoutSubviews {
	%orig;

	SCIInstallFeedActionButton(self);
}
%end

%hook IGUFIInteractionCountsView
- (void)layoutSubviews {
	%orig;

	SCIInstallFeedActionButton(self);
}
%end

%hook IGSundialViewerVerticalUFI
- (void)layoutSubviews {
	%orig;

	SCIInstallReelsActionButton(self);
}
%end

%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
	%orig;

	SCIInstallStoriesActionButton(self);
}
%end

%hook IGDirectVisualMessageViewerController
- (void)viewDidLayoutSubviews {
	%orig;

	SCIInstallDirectActionButton(self);
}
%end
