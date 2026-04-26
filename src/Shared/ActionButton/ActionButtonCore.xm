#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "ActionButtonCore.h"
#import "SCIActionButtonConfiguration.h"
#import "SCIActionDescriptor.h"
#import "../../Downloader/Download.h"
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../MediaPreview/SCIFullScreenMediaPlayer.h"
#import "../MediaPreview/SCIMediaItem.h"
#import "../Vault/SCIVaultFile.h"
#import "../Vault/SCIVaultSaveMetadata.h"

NSString * const kSCIActionNone = @"none";
NSString * const kSCIActionDownloadLibrary = @"download_library";
NSString * const kSCIActionDownloadShare = @"download_share";
NSString * const kSCIActionCopyDownloadLink = @"copy_download_link";
NSString * const kSCIActionDownloadVault = @"download_vault";
NSString * const kSCIActionExpand = @"expand";
NSString * const kSCIActionViewThumbnail = @"view_thumbnail";
NSString * const kSCIActionCopyCaption = @"copy_caption";
NSString * const kSCIActionOpenTopicSettings = @"open_topic_settings";
NSString * const kSCIActionRepost = @"repost";

static const void *kSCIActionButtonContextAssocKey = &kSCIActionButtonContextAssocKey;
static const void *kSCIActionButtonTapActionAssocKey = &kSCIActionButtonTapActionAssocKey;
static const void *kSCIActionButtonHapticActionAssocKey = &kSCIActionButtonHapticActionAssocKey;
static const void *kSCIActionButtonIconImageViewAssocKey = &kSCIActionButtonIconImageViewAssocKey;
static const void *kSCIActionButtonIconWidthConstraintAssocKey = &kSCIActionButtonIconWidthConstraintAssocKey;
static const void *kSCIActionButtonIconHeightConstraintAssocKey = &kSCIActionButtonIconHeightConstraintAssocKey;
static const void *kSCIActionButtonMenuSignatureAssocKey = &kSCIActionButtonMenuSignatureAssocKey;
static const void *kSCIActionButtonLastMenuActionAssocKey = &kSCIActionButtonLastMenuActionAssocKey;

@interface SCIResolvedMediaEntry : NSObject
@property (nonatomic, strong, nullable) id mediaObject;
@property (nonatomic, strong, nullable) NSURL *photoURL;
@property (nonatomic, strong, nullable) NSURL *videoURL;
@end

static void SCIPauseDirectPlaybackFromController(UIViewController *controller);
static void SCIResumeDirectPlaybackFromController(UIViewController *controller);
void SCIPauseStoryPlaybackFromOverlaySubview(UIView *overlayView);
void SCIResumeStoryPlaybackFromOverlaySubview(UIView *overlayView);
SCIActionButtonContext *SCIActionButtonContextFromButton(UIButton *button);

@implementation SCIResolvedMediaEntry
@end

@interface SCIActionMenuButton : UIButton
@end

@implementation SCIActionMenuButton

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction
willDisplayMenuForConfiguration:(id)configuration
                      animator:(id<UIContextMenuInteractionAnimating>)animator
{
	[super contextMenuInteraction:interaction willDisplayMenuForConfiguration:configuration animator:animator];
	(void)interaction;
	(void)configuration;
	(void)animator;

	SCIActionButtonContext *context = SCIActionButtonContextFromButton(self);
	if (!context) return;

	objc_setAssociatedObject(self, kSCIActionButtonLastMenuActionAssocKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
	if (context.source == SCIActionButtonSourceStories) {
		SCIPauseStoryPlaybackFromOverlaySubview(context.view);
	} else if (context.source == SCIActionButtonSourceDirect) {
		SCIPauseDirectPlaybackFromController(context.controller);
	}
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction
   willEndForConfiguration:(id)configuration
                      animator:(id<UIContextMenuInteractionAnimating>)animator
{
	[super contextMenuInteraction:interaction willEndForConfiguration:configuration animator:animator];
	(void)interaction;
	(void)configuration;

	[animator addCompletion:^{
		SCIActionMenuButton *strongSelf = self;
		if (!strongSelf) return;

		SCIActionButtonContext *context = SCIActionButtonContextFromButton(strongSelf);
		NSString *lastAction = objc_getAssociatedObject(strongSelf, kSCIActionButtonLastMenuActionAssocKey);
		objc_setAssociatedObject(strongSelf, kSCIActionButtonLastMenuActionAssocKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
		if (!context) return;
		if ([lastAction isEqualToString:kSCIActionOpenTopicSettings]) return;

		if (context.source == SCIActionButtonSourceStories) {
			SCIResumeStoryPlaybackFromOverlaySubview(context.view);
		} else if (context.source == SCIActionButtonSourceDirect) {
			SCIResumeDirectPlaybackFromController(context.controller);
		}
	}];
}

@end

@implementation SCIActionButtonContext
- (instancetype)init {
	if ((self = [super init])) {
		_currentIndexOverride = -1;
	}
	return self;
}
@end

static BOOL SCIIsVideoExtension(NSString *ext) {
	if (ext.length == 0) return NO;

	static NSSet<NSString *> *videoExts;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		videoExts = [NSSet setWithArray:@[@"mp4", @"mov", @"m4v", @"avi", @"webm", @"hevc"]];
	});

	return [videoExts containsObject:ext.lowercaseString];
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

static NSString *SCIDefaultActionPrefKeyForSource(SCIActionButtonSource source) {
	return [NSString stringWithFormat:@"action_button_%@_default_action", SCIActionButtonTopicKeyForSource(source)];
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

extern "C" NSString *SCIActionButtonTitleForIdentifier(NSString *identifier) {
	return SCIActionDescriptorDisplayTitle(identifier, nil);
}

static NSString *SCIActionButtonDisplayTitleForContext(NSString *identifier, SCIActionButtonContext *context) {
	return SCIActionDescriptorDisplayTitle(identifier, context.settingsTitle);
}

static UIImage *SCIIconForActionIdentifier(NSString *identifier, SCIActionButtonSource source, CGFloat size) {
	NSString *append = (source == SCIActionButtonSourceReels) ? @"_reels" : @"";
	NSString *iconName = SCIActionDescriptorIconName(identifier);
	if ([identifier isEqualToString:kSCIActionDownloadLibrary]) {
		return SCIActionButtonImage([NSString stringWithFormat:@"download%@", append], @"arrow.down.to.line", size);
	}
	if ([identifier isEqualToString:kSCIActionDownloadShare]) {
		return SCIActionButtonImage([NSString stringWithFormat:@"share%@", append], @"square.and.arrow.up", size);
	}
	if ([identifier isEqualToString:kSCIActionCopyDownloadLink]) {
		return SCIActionButtonImage([NSString stringWithFormat:@"link%@", append], @"link", size);
	}
	if ([identifier isEqualToString:kSCIActionDownloadVault]) {
		return SCIActionButtonImage(@"photo_gallery", @"photo.on.rectangle.angled", size);
	}
	if ([identifier isEqualToString:kSCIActionExpand]) {
		return SCIActionButtonImage([NSString stringWithFormat:@"expand%@", append], @"arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", size);
	}
	if ([identifier isEqualToString:kSCIActionViewThumbnail]) {
		return SCIActionButtonImage([NSString stringWithFormat:@"photo%@", append], @"photo.on.rectangle", size);
	}
	if ([identifier isEqualToString:kSCIActionCopyCaption]) {
		return SCIActionButtonImage(@"caption", @"text.quote", size);
	}
	if ([identifier isEqualToString:kSCIActionOpenTopicSettings]) {
		return SCIActionButtonImage(@"settings", @"gearshape", size);
	}
	if ([identifier isEqualToString:kSCIActionRepost]) {
		return SCIActionButtonImage(@"repost", @"arrow.triangle.2.circlepath", size);
	}
	return SCIActionButtonImage([NSString stringWithFormat:@"%@%@", iconName, append], @"option", size);
}

UIImage *SCIActionButtonMenuIconForIdentifier(NSString *identifier, CGFloat size) {
	return SCIIconForActionIdentifier(identifier, SCIActionButtonSourceFeed, size);
}

static NSInteger SCIClampedIndex(NSInteger index, NSInteger count) {
	if (count <= 0) return 0;
	if (index < 0) return 0;
	if (index >= count) return count - 1;
	return index;
}

static void SCIPlayActionButtonTapHaptic(void) {
	UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
	[feedback selectionChanged];
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

	if (!entry.photoURL) entry.photoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"imageURL"));
	if (!entry.photoURL) entry.photoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"imageUrl"));
	if (!entry.photoURL) {
		id imageSpecifier = SCIObjectForSelector(mediaObject, @"imageSpecifier");
		entry.photoURL = SCIURLFromValue(SCIObjectForSelector(imageSpecifier, @"url"));
	}
	if (!entry.photoURL) entry.photoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"displayURL"));
	if (!entry.photoURL) entry.photoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"thumbnailURL"));

	id videoObject = SCIObjectForSelector(mediaObject, @"video");
	if (!videoObject) videoObject = SCIObjectForSelector(mediaObject, @"rawVideo");
	if (videoObject) {
		entry.videoURL = [SCIUtils getVideoUrl:videoObject];
		if (!entry.videoURL) {
			entry.videoURL = SCIURLFromAssetLikeObject(videoObject, YES);
		}
	}

	if (!entry.videoURL) entry.videoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"videoURL"));
	if (!entry.videoURL) entry.videoURL = SCIURLFromValue(SCIObjectForSelector(mediaObject, @"videoUrl"));

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
	if (items.count == 0) items = SCIArrayFromCollection(SCIKVCObject(media, @"items"));

	if (items.count > 0) {
		for (id item in items) {
			SCIResolvedMediaEntry *entry = SCIEntryFromMediaObject(item);
			if (!entry) entry = SCIEntryFromMediaObject(SCIObjectForSelector(item, @"media") ?: SCIKVCObject(item, @"media"));
			if (!entry) entry = SCIEntryFromMediaObject(SCIObjectForSelector(item, @"visualMessage") ?: SCIKVCObject(item, @"visualMessage"));
			if (!entry) entry = SCIEntryFromMediaObject(SCIObjectForSelector(item, @"item") ?: SCIKVCObject(item, @"item"));
			if (entry) {
				entry.mediaObject = item;
				[entries addObject:entry];
			}
		}
	} else {
		SCIResolvedMediaEntry *singleEntry = SCIEntryFromMediaObject(media);
		if (!singleEntry) {
			id nested = SCIObjectForSelector(media, @"media");
			if (!nested) nested = SCIKVCObject(media, @"media");
			singleEntry = SCIEntryFromMediaObject(nested);
		}
		if (singleEntry) [entries addObject:singleEntry];
	}

	return entries;
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
		if (username.length > 0) item.title = username;
		[items addObject:item];
	}

	return items;
}

static UIView *SCIDirectMediaView(UIViewController *controller) {
	if (!controller) return nil;
	id viewerContainer = [SCIUtils getIvarForObj:controller name:"_viewerContainerView"];
	if (!viewerContainer) viewerContainer = SCIKVCObject(controller, @"viewerContainerView");
	id mediaView = SCIObjectForSelector(viewerContainer, @"mediaView");
	return [mediaView isKindOfClass:[UIView class]] ? (UIView *)mediaView : nil;
}

extern "C" void SCIPauseStoryPlaybackFromOverlaySubview(UIView *overlayView) {
	UIViewController *ancestorController = SCIViewControllerForAncestorView(overlayView);
	if (!ancestorController) return;

	if ([ancestorController respondsToSelector:NSSelectorFromString(@"pauseWithReason:")]) {
		((void (*)(id, SEL, NSInteger))objc_msgSend)(ancestorController, NSSelectorFromString(@"pauseWithReason:"), 1);
	} else if ([ancestorController respondsToSelector:NSSelectorFromString(@"pauseWithReason:callsiteContext:")]) {
		((void (*)(id, SEL, NSInteger, id))objc_msgSend)(ancestorController, NSSelectorFromString(@"pauseWithReason:callsiteContext:"), 1, nil);
	} else if ([ancestorController respondsToSelector:NSSelectorFromString(@"pause")]) {
		((void (*)(id, SEL))objc_msgSend)(ancestorController, NSSelectorFromString(@"pause"));
	}
}

extern "C" void SCIResumeStoryPlaybackFromOverlaySubview(UIView *overlayView) {
	UIViewController *ancestorController = SCIViewControllerForAncestorView(overlayView);
	if (!ancestorController) return;

	if ([ancestorController respondsToSelector:NSSelectorFromString(@"tryResumePlayback")]) {
		((void (*)(id, SEL))objc_msgSend)(ancestorController, NSSelectorFromString(@"tryResumePlayback"));
	} else if ([ancestorController respondsToSelector:NSSelectorFromString(@"tryResumePlaybackWithReason:")]) {
		((void (*)(id, SEL, NSInteger))objc_msgSend)(ancestorController, NSSelectorFromString(@"tryResumePlaybackWithReason:"), 1);
	} else if ([ancestorController respondsToSelector:NSSelectorFromString(@"resumePlayback")]) {
		((void (*)(id, SEL))objc_msgSend)(ancestorController, NSSelectorFromString(@"resumePlayback"));
	} else if ([ancestorController respondsToSelector:NSSelectorFromString(@"play")]) {
		((void (*)(id, SEL))objc_msgSend)(ancestorController, NSSelectorFromString(@"play"));
	}
}

static void SCIPauseDirectPlaybackFromController(UIViewController *controller) {
	UIView *mediaView = SCIDirectMediaView(controller);
	SEL pauseSelector = NSSelectorFromString(@"pauseWithReason:");
	if (mediaView && [mediaView respondsToSelector:pauseSelector]) {
		((void (*)(id, SEL, NSInteger))objc_msgSend)(mediaView, pauseSelector, 0);
	}
}

static void SCIResumeDirectPlaybackFromController(UIViewController *controller) {
	UIView *mediaView = SCIDirectMediaView(controller);
	SEL playSelector = NSSelectorFromString(@"play");
	if (mediaView && [mediaView respondsToSelector:playSelector]) {
		((void (*)(id, SEL))objc_msgSend)(mediaView, playSelector);
	}
}

static UIImage *SCIButtonDefaultImage(NSString *identifier, SCIActionButtonSource source) {
	CGFloat size = 24.0;
	if (source == SCIActionButtonSourceReels) {
		size = 44.0;
	} else if ([identifier isEqualToString:kSCIActionDownloadShare] || 
			   [identifier isEqualToString:kSCIActionViewThumbnail] ||
               [identifier isEqualToString:kSCIActionDownloadVault]) {
		size = 23.0;
	}

	if ([identifier isEqualToString:kSCIActionNone]) {
		return source == SCIActionButtonSourceReels
			? SCIActionButtonImage(@"action_reels", @"option", size)
			: SCIActionButtonImage(@"action", @"option", size);
	}

	return SCIIconForActionIdentifier(identifier, source, size);
}

static CGSize SCICustomButtonIconDisplaySize(NSString *identifier, SCIActionButtonSource source, UIImage *image, UIButton *button) {
	if (!image) return CGSizeZero;

	CGFloat width = image.size.width;
	CGFloat height = image.size.height;
	if (source == SCIActionButtonSourceReels &&
		([identifier isEqualToString:kSCIActionDownloadShare] ||
		 [identifier isEqualToString:kSCIActionViewThumbnail] ||
		 [identifier isEqualToString:kSCIActionDownloadVault])) {
		if ([identifier isEqualToString:kSCIActionDownloadVault]) {
			width = 28.0;
			height = 28.0;
		} else {
		width = 38.0;
		height = 38.0;
		}
	}

	CGFloat maxWidth = CGRectGetWidth(button.bounds) > 0.0 ? CGRectGetWidth(button.bounds) : 44.0;
	CGFloat maxHeight = CGRectGetHeight(button.bounds) > 0.0 ? CGRectGetHeight(button.bounds) : 44.0;
	return CGSizeMake(MAX(1.0, MIN(maxWidth, width)), MAX(1.0, MIN(maxHeight, height)));
}

static UIImageView *SCIEnsureCustomIconImageView(UIButton *button) {
	UIImageView *imageView = objc_getAssociatedObject(button, kSCIActionButtonIconImageViewAssocKey);
	if ([imageView isKindOfClass:[UIImageView class]]) return imageView;

	imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	imageView.translatesAutoresizingMaskIntoConstraints = NO;
	imageView.contentMode = UIViewContentModeScaleAspectFit;
	imageView.userInteractionEnabled = NO;
	[button addSubview:imageView];

	[NSLayoutConstraint activateConstraints:@[
		[imageView.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
		[imageView.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
		[imageView.widthAnchor constraintLessThanOrEqualToAnchor:button.widthAnchor],
		[imageView.heightAnchor constraintLessThanOrEqualToAnchor:button.heightAnchor],
	]];

	NSLayoutConstraint *widthConstraint = [imageView.widthAnchor constraintEqualToConstant:24.0];
	NSLayoutConstraint *heightConstraint = [imageView.heightAnchor constraintEqualToConstant:24.0];
	widthConstraint.active = YES;
	heightConstraint.active = YES;

	objc_setAssociatedObject(button, kSCIActionButtonIconImageViewAssocKey, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(button, kSCIActionButtonIconWidthConstraintAssocKey, widthConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(button, kSCIActionButtonIconHeightConstraintAssocKey, heightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return imageView;
}

static void SCISetButtonVisualImage(UIButton *button, UIImage *image, SCIActionButtonSource source, NSString *identifier) {
	UIImage *templatedImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	if (source == SCIActionButtonSourceReels) {
		UIImageView *customIconView = SCIEnsureCustomIconImageView(button);
		NSLayoutConstraint *widthConstraint = objc_getAssociatedObject(button, kSCIActionButtonIconWidthConstraintAssocKey);
		NSLayoutConstraint *heightConstraint = objc_getAssociatedObject(button, kSCIActionButtonIconHeightConstraintAssocKey);
		CGSize displaySize = SCICustomButtonIconDisplaySize(identifier, source, templatedImage, button);
		widthConstraint.constant = displaySize.width;
		heightConstraint.constant = displaySize.height;
		customIconView.hidden = NO;
		customIconView.tintColor = button.tintColor ?: SCIActionButtonTintForSource(source);
		customIconView.image = templatedImage;
		[button setImage:nil forState:UIControlStateNormal];
		return;
	}

	UIImageView *customIconView = objc_getAssociatedObject(button, kSCIActionButtonIconImageViewAssocKey);
	if ([customIconView isKindOfClass:[UIImageView class]]) {
		customIconView.hidden = YES;
		customIconView.image = nil;
	}
	[button setImage:templatedImage forState:UIControlStateNormal];
}

static id SCIResolveMediaForContext(SCIActionButtonContext *context) {
	if (!context) return nil;
	if (context.mediaOverride) return context.mediaOverride;
	if (context.mediaResolver) return context.mediaResolver(context);
	return nil;
}

static NSInteger SCIResolveCurrentIndexForContext(SCIActionButtonContext *context) {
	if (!context) return 0;
	if (context.currentIndexOverride >= 0) return context.currentIndexOverride;
	if (context.currentIndexResolver) return context.currentIndexResolver(context);
	return 0;
}

static BOOL SCIIsActionVisible(SCIActionButtonContext *context,
							   SCIActionButtonConfiguration *configuration,
							   NSString *identifier,
							   id media,
							   NSArray<SCIResolvedMediaEntry *> *entries,
							   NSInteger currentIndex) {
	if (entries.count == 0 || identifier.length == 0) return NO;
	if ([configuration.disabledActions containsObject:identifier] || [configuration.unassignedActions containsObject:identifier]) {
		return NO;
	}

	NSInteger idx = SCIClampedIndex(currentIndex, (NSInteger)entries.count);
	SCIResolvedMediaEntry *currentEntry = entries[idx];
	NSURL *currentURL = currentEntry.videoURL ?: currentEntry.photoURL;

	if ([identifier isEqualToString:kSCIActionViewThumbnail]) {
		return currentEntry.videoURL != nil;
	}
	if ([identifier isEqualToString:kSCIActionDownloadLibrary] ||
		[identifier isEqualToString:kSCIActionDownloadShare] ||
		[identifier isEqualToString:kSCIActionCopyDownloadLink] ||
		[identifier isEqualToString:kSCIActionDownloadVault]) {
		return currentURL != nil;
	}
	if ([identifier isEqualToString:kSCIActionCopyCaption]) {
		return context.captionResolver != nil && [context.captionResolver(context, media, entries, idx) length] > 0;
	}
	if ([identifier isEqualToString:kSCIActionOpenTopicSettings]) {
		return context.settingsTitle.length > 0;
	}
	if ([identifier isEqualToString:kSCIActionRepost]) {
		return context.repostHandler != nil;
	}
	if (context.visibilityResolver) {
		return context.visibilityResolver(context, identifier, media, entries, idx);
	}
	return YES;
}

static NSArray<NSString *> *SCIVisibleActionsForContext(SCIActionButtonContext *context, id media, NSArray<SCIResolvedMediaEntry *> *entries, NSInteger currentIndex) {
	SCIActionButtonConfiguration *configuration = [SCIActionButtonConfiguration configurationForSource:context.source
																						  topicTitle:context.settingsTitle ?: SCIActionButtonTopicTitleForSource(context.source)
																					supportedActions:context.supportedActions ?: SCIActionButtonSupportedActionsForSource(context.source)
																					 defaultSections:SCIActionButtonDefaultSectionsForSource(context.source)];
	NSArray<NSString *> *supportedActions = configuration.supportedActions ?: @[];
	if (supportedActions.count == 0) return @[];

	NSMutableArray<NSString *> *visible = [NSMutableArray array];
	for (NSString *identifier in supportedActions) {
		if (SCIIsActionVisible(context, configuration, identifier, media, entries, currentIndex)) {
			[visible addObject:identifier];
		}
	}
	return visible;
}

static NSString *SCIResolvedDefaultActionIdentifier(NSArray<NSString *> *visibleIdentifiers, SCIActionButtonSource source) {
	if (visibleIdentifiers.count == 0) return nil;

	NSString *saved = [SCIUtils getStringPref:SCIDefaultActionPrefKeyForSource(source)];
	if ([saved isEqualToString:kSCIActionNone]) return kSCIActionNone;
	if (saved.length > 0 && [visibleIdentifiers containsObject:saved]) return saved;
	if (saved.length > 0) return kSCIActionNone;
	if ([visibleIdentifiers containsObject:kSCIActionDownloadLibrary]) return kSCIActionDownloadLibrary;
	return visibleIdentifiers.firstObject;
}

static NSString *SCIActionButtonMenuSignature(SCIActionButtonContext *context,
											  SCIActionButtonConfiguration *configuration,
											  NSArray<NSString *> *visibleActions,
											  NSString *defaultIdentifier) {
	return [NSString stringWithFormat:@"%@|%@|%@|%@",
			SCIActionButtonTopicKeyForSource(context.source),
			defaultIdentifier ?: @"",
			[visibleActions componentsJoinedByString:@","],
			configuration.dictionaryRepresentation.description ?: @""];
}

static void SCIShowExtractedVideoCover(NSURL *videoURL, SCIVaultSaveMetadata *metadata, SCIActionButtonContext *context) {
	if (!videoURL) {
		[SCIUtils showToastForDuration:2.0 title:@"Cover unavailable" subtitle:nil iconResource:@"photo_filled" fallbackSystemImageName:@"photo.fill" tone:SCIFeedbackPillToneError];
		return;
	}

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
		AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
		generator.appliesPreferredTrackTransform = YES;
		generator.maximumSize = CGSizeMake(2160, 2160);

		NSError *error = nil;
		CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.0, 600) actualTime:NULL error:&error];
		if (!imageRef) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[SCIUtils showToastForDuration:2.0 title:@"Cover unavailable" subtitle:error.localizedDescription ?: @"" iconResource:@"photo_filled" fallbackSystemImageName:@"photo.fill" tone:SCIFeedbackPillToneError];
			});
			return;
		}

		UIImage *image = [UIImage imageWithCGImage:imageRef];
		CGImageRelease(imageRef);

		dispatch_async(dispatch_get_main_queue(), ^{
			[SCIFullScreenMediaPlayer showImage:image metadata:metadata playbackSource:(SCIFullScreenPlaybackSource)context.source sourceView:context.view controller:context.controller];
		});
	});
}

static BOOL SCIExecuteCommonAction(NSString *identifier,
								   SCIActionButtonContext *context,
								   SCIResolvedMediaEntry *currentEntry,
								   NSArray<SCIResolvedMediaEntry *> *entries,
								   NSInteger resolvedIndex,
								   NSString *username,
								   SCIVaultSaveMetadata *meta,
								   id media) {
	NSURL *currentURL = currentEntry.videoURL ?: currentEntry.photoURL;
	BOOL isVideo = (currentEntry.videoURL != nil);

	if ([identifier isEqualToString:kSCIActionDownloadLibrary] ||
		[identifier isEqualToString:kSCIActionDownloadShare] ||
		[identifier isEqualToString:kSCIActionDownloadVault]) {
		if (!currentURL) {
			[SCIUtils showToastForDuration:2.0 title:@"No downloadable media" subtitle:nil iconResource:@"download" fallbackSystemImageName:@"arrow.down.to.line" tone:SCIFeedbackPillToneError];
			return YES;
		}

		DownloadAction action = saveToPhotos;
		if ([identifier isEqualToString:kSCIActionDownloadShare]) action = share;
		else if ([identifier isEqualToString:kSCIActionDownloadVault]) action = saveToVault;

		SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:action showProgress:YES];
		delegate.pendingVaultSaveMetadata = meta;
		[delegate downloadFileWithURL:currentURL fileExtension:SCIExtensionForURL(currentURL, isVideo) hudLabel:nil];
		return YES;
	}

	if ([identifier isEqualToString:kSCIActionCopyDownloadLink]) {
		if (!currentURL) {
			[SCIUtils showToastForDuration:2.0 title:@"No link available" subtitle:nil iconResource:@"link" fallbackSystemImageName:@"link" tone:SCIFeedbackPillToneError];
			return YES;
		}

		NSURL *normalized = currentURL;
		if ([normalized respondsToSelector:@selector(normalizedURL)]) {
			NSURL *resolved = [normalized normalizedURL];
			if (resolved) normalized = resolved;
		}

		[UIPasteboard generalPasteboard].string = normalized.absoluteString ?: @"";
		[SCIUtils showToastForDuration:1.5 title:@"Download link copied" subtitle:nil iconResource:@"copy_filled" fallbackSystemImageName:@"doc.on.doc.fill" tone:SCIFeedbackPillToneSuccess];
		return YES;
	}

	if ([identifier isEqualToString:kSCIActionExpand]) {
		NSArray<SCIMediaItem *> *playerItems = SCIPlayerItemsFromEntries(entries, context.source, username);
		if (playerItems.count == 0) {
			[SCIUtils showToastForDuration:2.0 title:@"No media to expand" subtitle:nil iconResource:@"expand" fallbackSystemImageName:@"arrow.up.left.and.arrow.down.right" tone:SCIFeedbackPillToneError];
			return YES;
		}

		NSInteger clampedIndex = SCIClampedIndex(resolvedIndex, (NSInteger)playerItems.count);
		[SCIFullScreenMediaPlayer showMediaItems:playerItems startingAtIndex:clampedIndex metadata:meta playbackSource:(SCIFullScreenPlaybackSource)context.source sourceView:context.view controller:context.controller];
		return YES;
	}

	if ([identifier isEqualToString:kSCIActionViewThumbnail]) {
		if (!currentEntry.videoURL) {
			[SCIUtils showToastForDuration:2.0 title:@"Thumbnail is only available for videos" subtitle:nil iconResource:@"photo_filled" fallbackSystemImageName:@"photo.fill" tone:SCIFeedbackPillToneError];
			return YES;
		}

		SCIVaultSaveMetadata *thumbnailMeta = [[SCIVaultSaveMetadata alloc] init];
		thumbnailMeta.source = (int16_t)SCIVaultSourceThumbnail;
		thumbnailMeta.sourceUsername = meta.sourceUsername;
		SCIShowExtractedVideoCover(currentEntry.videoURL, thumbnailMeta, context);
		return YES;
	}

	if ([identifier isEqualToString:kSCIActionCopyCaption]) {
		NSString *caption = context.captionResolver ? context.captionResolver(context, media, entries, resolvedIndex) : nil;
		if (caption.length == 0) {
			[SCIUtils showToastForDuration:2.0 title:@"No caption available" subtitle:nil iconResource:@"copy_filled" fallbackSystemImageName:@"doc.on.doc.fill" tone:SCIFeedbackPillToneError];
			return YES;
		}

		[UIPasteboard generalPasteboard].string = caption;
		[SCIUtils showToastForDuration:1.5 title:@"Caption copied" subtitle:nil iconResource:@"copy_filled" fallbackSystemImageName:@"doc.on.doc.fill" tone:SCIFeedbackPillToneSuccess];
		return YES;
	}

	if ([identifier isEqualToString:kSCIActionOpenTopicSettings]) {
		if (context.settingsTitle.length == 0) {
			[SCIUtils showToastForDuration:2.0 title:@"Settings unavailable" subtitle:nil iconResource:@"settings" fallbackSystemImageName:@"gearshape" tone:SCIFeedbackPillToneError];
			return YES;
		}

		[SCIUtils showSettingsForTopicTitle:context.settingsTitle];
		return YES;
	}

	if ([identifier isEqualToString:kSCIActionRepost]) {
		BOOL handled = context.repostHandler ? context.repostHandler(context) : NO;
		if (!handled) {
			[SCIUtils showToastForDuration:2.0 title:@"Repost unavailable" subtitle:nil iconResource:@"repost" fallbackSystemImageName:@"arrow.triangle.2.circlepath" tone:SCIFeedbackPillToneError];
		}
		return YES;
	}

	return NO;
}

BOOL SCIExecuteActionIdentifier(NSString *identifier, SCIActionButtonContext *context, BOOL isDefaultTap) {
	if (identifier.length == 0 || !context) return NO;

	id media = SCIResolveMediaForContext(context);
	NSArray<SCIResolvedMediaEntry *> *entries = SCIEntriesFromMedia(media);
	if (entries.count == 0) {
		[SCIUtils showToastForDuration:2.0 title:@"Media not found" subtitle:nil iconResource:@"media_filled" fallbackSystemImageName:@"photo.on.rectangle" tone:SCIFeedbackPillToneError];
		return NO;
	}

	NSInteger resolvedIndex = SCIClampedIndex(SCIResolveCurrentIndexForContext(context), (NSInteger)entries.count);
	SCIResolvedMediaEntry *currentEntry = entries[resolvedIndex];

	NSString *username = (context.source == SCIActionButtonSourceDirect)
		? SCIDirectUsernameFromController(context.controller)
		: SCIUsernameFromMediaObject(media);
	if (username.length == 0) username = SCIUsernameFromMediaObject(currentEntry.mediaObject);
	if (username.length == 0) {
		for (SCIResolvedMediaEntry *entry in entries) {
			username = SCIUsernameFromMediaObject(entry.mediaObject);
			if (username.length > 0) break;
		}
	}
	if (context.source == SCIActionButtonSourceDirect && username.length > 0) {
		NSString *sessionUsername = SCISessionUsernameFromController(context.controller);
		if (sessionUsername.length > 0 && [username caseInsensitiveCompare:sessionUsername] == NSOrderedSame) {
			username = nil;
		}
	}

	SCIVaultSaveMetadata *meta = SCIVaultMetadata(context.source, username);

	if (context.source == SCIActionButtonSourceStories && isDefaultTap) {
		SCIPauseStoryPlaybackFromOverlaySubview(context.view);
	}
	if (context.source == SCIActionButtonSourceDirect && isDefaultTap) {
		SCIPauseDirectPlaybackFromController(context.controller);
	}

	return SCIExecuteCommonAction(identifier, context, currentEntry, entries, resolvedIndex, username, meta, media);
}

UIButton *SCIActionButtonWithTag(UIView *container, NSInteger tag) {
	UIView *existing = [container viewWithTag:tag];
	if ([existing isKindOfClass:[UIButton class]]) {
		return (UIButton *)existing;
	}

	UIButton *button = [SCIActionMenuButton buttonWithType:UIButtonTypeSystem];
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
	button.layer.shadowColor = UIColor.clearColor.CGColor;
	button.layer.shadowOpacity = 0.0;
	button.layer.shadowRadius = 0.0;
	button.layer.shadowOffset = CGSizeZero;

	if (source == SCIActionButtonSourceReels) {
		button.layer.cornerRadius = CGRectGetHeight(button.bounds) / 2.0;
		button.layer.shadowColor = [UIColor blackColor].CGColor;
		button.layer.shadowOpacity = 0.24;
		button.layer.shadowRadius = 1.8;
	} else if (source == SCIActionButtonSourceStories || source == SCIActionButtonSourceDirect) {
		button.layer.cornerRadius = 8.0;
		button.layer.shadowColor = [UIColor blackColor].CGColor;
		button.layer.shadowOpacity = 0.5;
		button.layer.shadowRadius = 2.0;
		button.layer.shadowOffset = CGSizeMake(0.0, 2.0);
	}
}

BOOL SCIIsDirectVisualViewerAncestor(UIView *view) {
	UIViewController *ancestorController = SCIViewControllerForAncestorView(view);
	return [ancestorController isKindOfClass:NSClassFromString(@"IGDirectVisualMessageViewerController")];
}

SCIActionButtonContext *SCIActionButtonContextFromButton(UIButton *button) {
	id context = objc_getAssociatedObject(button, kSCIActionButtonContextAssocKey);
	return [context isKindOfClass:[SCIActionButtonContext class]] ? context : nil;
}

void SCIConfigureActionButton(UIButton *button, SCIActionButtonContext *context) {
	if (!button || !context) return;

	id media = SCIResolveMediaForContext(context);
	NSArray<SCIResolvedMediaEntry *> *entries = SCIEntriesFromMedia(media);
	NSInteger currentIndex = SCIResolveCurrentIndexForContext(context);
	NSArray<NSString *> *visibleActions = SCIVisibleActionsForContext(context, media, entries, currentIndex);

	if (visibleActions.count == 0) {
		button.hidden = YES;
		button.menu = nil;
		return;
	}

	button.hidden = NO;

	NSString *defaultIdentifier = SCIResolvedDefaultActionIdentifier(visibleActions, context.source);
	UIImage *defaultImage = SCIButtonDefaultImage(defaultIdentifier, context.source);
	SCISetButtonVisualImage(button, defaultImage, context.source, defaultIdentifier);
	BOOL shouldOpenMenuOnTap = [defaultIdentifier isEqualToString:kSCIActionNone];
	SCIActionButtonConfiguration *configuration = [SCIActionButtonConfiguration configurationForSource:context.source
																						  topicTitle:context.settingsTitle ?: SCIActionButtonTopicTitleForSource(context.source)
																					supportedActions:context.supportedActions ?: SCIActionButtonSupportedActionsForSource(context.source)
																					 defaultSections:SCIActionButtonDefaultSectionsForSource(context.source)];
	NSString *menuSignature = SCIActionButtonMenuSignature(context, configuration, visibleActions, defaultIdentifier);
	NSString *existingSignature = objc_getAssociatedObject(button, kSCIActionButtonMenuSignatureAssocKey);
	if ([existingSignature isEqualToString:menuSignature] && button.menu != nil) {
		button.showsMenuAsPrimaryAction = shouldOpenMenuOnTap;
		objc_setAssociatedObject(button, kSCIActionButtonContextAssocKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		return;
	}

	__weak UIButton *weakButton = button;
	UIAction *oldHapticAction = objc_getAssociatedObject(button, kSCIActionButtonHapticActionAssocKey);
	if (oldHapticAction) [button removeAction:oldHapticAction forControlEvents:UIControlEventTouchDown];
	UIAction *newHapticAction = [UIAction actionWithHandler:^(__unused UIAction *action) {
		SCIPlayActionButtonTapHaptic();
	}];
	[button addAction:newHapticAction forControlEvents:UIControlEventTouchDown];
	objc_setAssociatedObject(button, kSCIActionButtonHapticActionAssocKey, newHapticAction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	UIAction *oldTapAction = objc_getAssociatedObject(button, kSCIActionButtonTapActionAssocKey);
	if (oldTapAction) [button removeAction:oldTapAction forControlEvents:UIControlEventTouchUpInside];

	if (shouldOpenMenuOnTap) {
		objc_setAssociatedObject(button, kSCIActionButtonTapActionAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	} else {
		UIAction *newTapAction = [UIAction actionWithHandler:^(__unused UIAction *action) {
			UIButton *strongButton = weakButton;
			SCIActionButtonContext *strongContext = SCIActionButtonContextFromButton(strongButton);
			if (!strongContext) return;

			id tapMedia = SCIResolveMediaForContext(strongContext);
			NSArray<SCIResolvedMediaEntry *> *tapEntries = SCIEntriesFromMedia(tapMedia);
			NSArray<NSString *> *tapVisibleActions = SCIVisibleActionsForContext(strongContext, tapMedia, tapEntries, SCIResolveCurrentIndexForContext(strongContext));
			NSString *tapIdentifier = SCIResolvedDefaultActionIdentifier(tapVisibleActions, strongContext.source);
			SCIExecuteActionIdentifier(tapIdentifier, strongContext, YES);
		}];
		[button addAction:newTapAction forControlEvents:UIControlEventTouchUpInside];
		objc_setAssociatedObject(button, kSCIActionButtonTapActionAssocKey, newTapAction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	NSMutableArray<UIMenuElement *> *menuElements = [NSMutableArray array];
	NSArray<SCIActionMenuSection *> *menuSections = [configuration visibleSections];
	BOOL firstGroup = YES;
	for (SCIActionMenuSection *group in menuSections) {
		NSString *title = group.title;
		NSArray<NSString *> *identifiers = group.actions;
		if (![identifiers isKindOfClass:[NSArray class]] || identifiers.count == 0) continue;

		NSMutableArray<UIMenuElement *> *groupElements = [NSMutableArray array];
		for (NSString *identifier in identifiers) {
			if (![visibleActions containsObject:identifier]) continue;

			UIAction *menuAction = [UIAction actionWithTitle:SCIActionButtonDisplayTitleForContext(identifier, context)
													   image:SCIActionButtonMenuIconForIdentifier(identifier, 22.0)
												  identifier:nil
													 handler:^(__unused UIAction *action) {
				UIButton *strongButton = weakButton;
				if (strongButton) {
					objc_setAssociatedObject(strongButton, kSCIActionButtonLastMenuActionAssocKey, identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
				}
				SCIExecuteActionIdentifier(identifier, context, NO);
			}];
			[groupElements addObject:menuAction];
		}

		if (groupElements.count == 0) continue;
		if (!firstGroup) {
			[menuElements addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[]]];
		}
		if (group.collapsible) {
			UIImage *sectionImage = nil;
			if (group.iconName.length > 0) {
				sectionImage = [[SCIActionButtonImage(group.iconName, @"option", 22.0) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] imageWithTintColor:[UIColor labelColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
			}
			UIMenu *submenu = [UIMenu menuWithTitle:title ?: @""
											 image:sectionImage
										identifier:nil
										   options:0
										  children:groupElements];
			[menuElements addObject:[UIMenu menuWithTitle:@""
													image:nil
											   identifier:nil
												  options:UIMenuOptionsDisplayInline
												 children:@[submenu]]];
		} else {
			[menuElements addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:groupElements]];
		}
		firstGroup = NO;
	}

	if (menuElements.count == 0) {
		for (NSString *identifier in visibleActions) {
			[menuElements addObject:[UIAction actionWithTitle:SCIActionButtonDisplayTitleForContext(identifier, context)
														image:SCIActionButtonMenuIconForIdentifier(identifier, 22.0)
												   identifier:nil
													  handler:^(__unused UIAction *action) {
				UIButton *strongButton = weakButton;
				if (strongButton) {
					objc_setAssociatedObject(strongButton, kSCIActionButtonLastMenuActionAssocKey, identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
				}
				SCIExecuteActionIdentifier(identifier, context, NO);
			}]];
		}
	}

	button.menu = [UIMenu menuWithTitle:@"" children:menuElements];
	button.showsMenuAsPrimaryAction = shouldOpenMenuOnTap;
	objc_setAssociatedObject(button, kSCIActionButtonContextAssocKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(button, kSCIActionButtonMenuSignatureAssocKey, menuSignature, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
