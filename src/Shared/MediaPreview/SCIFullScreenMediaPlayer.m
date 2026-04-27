#import <Photos/Photos.h>
#include <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "SCIFullScreenMediaPlayer.h"
#import "SCIMediaItem.h"
#import "SCIMediaCacheManager.h"
#import "SCIFullScreenImageViewController.h"
#import "SCIFullScreenVideoViewController.h"
#import "../../Utils.h"
#import "../UI/SCIMediaChrome.h"
#import "../Gallery/SCIGalleryFile.h"
#import "../Gallery/SCIGalleryOriginController.h"
#import "../Gallery/SCIGallerySaveMetadata.h"
#import "../Gallery/SCIGalleryCoreDataStack.h"
#import "../../AssetUtils.h"
#import "../../Downloader/Download.h"

static CGFloat const kDismissAxisLockSlop = 20.0;
static CGFloat const kDismissDistanceRatio = 50.0 / 667.0;
static CGFloat const kDismissMaximumDuration = 0.45;
static CGFloat const kDismissReturnVelocityAnimationRatio = 0.00007;
static CGFloat const kDismissMinimumVelocity = 1.0;
static CGFloat const kDismissMinimumDuration = 0.12;
static CGFloat const kDismissFinalBackdropAlpha = 0.1;
static CGFloat const kGalleryPreviewMenuIconPointSize = 22.0;

static UIImage *SCIGalleryPreviewMenuIcon(NSString *resourceName) {
    return [SCIAssetUtils instagramIconNamed:(resourceName.length > 0 ? resourceName : @"more")
                                   pointSize:kGalleryPreviewMenuIconPointSize];
}

static UIViewController *SCIPreviewPresenterForContext(SCIFullScreenPlaybackSource playbackSource,
                                                       UIViewController *sourceController) {
    if ((playbackSource == SCIFullScreenPlaybackSourceStories ||
         playbackSource == SCIFullScreenPlaybackSourceDirect) &&
        sourceController.view.window) {
        return sourceController;
    }

    return topMostController();
}

static CGPoint SCICenterForBounds(CGRect bounds) {
    return CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
}

@interface SCIFullScreenMediaPlayer () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning, UIViewControllerInteractiveTransitioning, SCIFullScreenContentDelegate>

@property (nonatomic, strong) NSArray<SCIMediaItem *> *items;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIViewController *> *controllerCache;

@property (nonatomic, strong) UIPageViewController *pageViewController;

@property (nonatomic, strong) UIView *topToolbar;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UIButton *topFavoriteButton;

@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *savePhotosButton;
@property (nonatomic, strong) UIButton *saveGalleryButton;
@property (nonatomic, strong) UIButton *deleteGalleryButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *clipboardButton;
@property (nonatomic, strong) UIButton *galleryOriginButton;

@property (nonatomic, assign) BOOL isToolbarVisible;
@property (nonatomic, assign) BOOL isSingleItemMode;

@property (nonatomic, assign) BOOL dismissPanDecided;
@property (nonatomic, assign) BOOL dismissPanIsVertical;
@property (nonatomic, weak) UIScrollView *pageScrollView;
@property (nonatomic, assign) BOOL interactiveDismissalInProgress;
@property (nonatomic, assign) CGPoint interactiveDismissAnchorPoint;
@property (nonatomic, strong, nullable) id<UIViewControllerContextTransitioning> interactiveDismissTransitionContext;

@property (nonatomic, assign) SCIFullScreenPlaybackSource playbackSource;
@property (nonatomic, weak, nullable) UIView *playbackSourceView;
@property (nonatomic, weak, nullable) UIViewController *playbackSourceController;
@property (nonatomic, copy, nullable) SCIMediaPreviewPlaybackBlock pausePlaybackBlock;
@property (nonatomic, copy, nullable) SCIMediaPreviewPlaybackBlock resumePlaybackBlock;
@property (nonatomic, assign) BOOL explicitPlaybackPauseActive;

/// Opaque black behind page content (letterboxing); alpha fades during interactive dismiss.
@property (nonatomic, strong) UIView *presentationBackdropView;

@end

@implementation SCIFullScreenMediaPlayer

#pragma mark - Convenience Factories

+ (void)showFileURL:(NSURL *)fileURL {
    [self showFileURL:fileURL fromGallery:NO];
}

+ (void)showFileURL:(NSURL *)fileURL metadata:(SCIGallerySaveMetadata *)metadata {
    SCIMediaItem *item = [SCIMediaItem itemWithFileURL:fileURL];
    item.isFromGallery = NO;
    item.galleryMetadata = metadata;

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    player.isFromGallery = NO;

    UIViewController *presenter = topMostController();
    [player playItems:@[item] startingAtIndex:0 fromViewController:presenter];
}

+ (void)showFileURL:(NSURL *)fileURL fromGallery:(BOOL)fromGallery {
    SCIMediaItem *item = [SCIMediaItem itemWithFileURL:fileURL];
    item.isFromGallery = fromGallery;

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    player.isFromGallery = fromGallery;

    UIViewController *presenter = topMostController();
    [player playItems:@[item] startingAtIndex:0 fromViewController:presenter];
}

+ (void)showGalleryFiles:(NSArray<SCIGalleryFile *> *)files
       startingAtIndex:(NSInteger)index
    fromViewController:(UIViewController *)presenter {
    if (files.count == 0) return;

    NSMutableArray<SCIMediaItem *> *items = [NSMutableArray arrayWithCapacity:files.count];
    for (SCIGalleryFile *file in files) {
        if (![file fileExists]) continue;
        SCIMediaItem *item = [SCIMediaItem itemWithGalleryFile:file];
        [items addObject:item];
    }

    if (items.count == 0) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewOpenGallery duration:2.0
                                 title:@"No files found"
                              subtitle:nil
                          iconResource:@"search"
                                  tone:SCIFeedbackPillToneError];
        return;
    }

    NSInteger adjustedIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));
    [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewOpenGallery duration:1.4
                                     title:@"Opened Gallery media"
                                  subtitle:nil
                              iconResource:@"media"
                                      tone:SCIFeedbackPillToneInfo];

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    player.isFromGallery = YES;
    [player playItems:items startingAtIndex:adjustedIndex fromViewController:presenter];
}

+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index {
    [self showPhotoURLs:urls initialIndex:index metadata:nil];
}

+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index metadata:(SCIGallerySaveMetadata *)metadata {
    if (urls.count == 0) return;

    NSMutableArray<SCIMediaItem *> *items = [NSMutableArray arrayWithCapacity:urls.count];
    for (NSURL *url in urls) {
        SCIMediaItem *item = [SCIMediaItem itemWithFileURL:url];
        item.galleryMetadata = metadata;
        [items addObject:item];
    }

    NSInteger adjustedIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    UIViewController *presenter = topMostController();
    [player playItems:items startingAtIndex:adjustedIndex fromViewController:presenter];
}

+ (void)showMediaItems:(NSArray<SCIMediaItem *> *)items startingAtIndex:(NSInteger)index metadata:(SCIGallerySaveMetadata *)metadata {
    [self showMediaItems:items
         startingAtIndex:index
                metadata:metadata
          playbackSource:SCIFullScreenPlaybackSourceUnknown
              sourceView:nil
              controller:nil
           pausePlayback:nil
          resumePlayback:nil];
}

+ (void)showMediaItems:(NSArray<SCIMediaItem *> *)items
       startingAtIndex:(NSInteger)index
              metadata:(SCIGallerySaveMetadata *)metadata
        playbackSource:(SCIFullScreenPlaybackSource)playbackSource
            sourceView:(UIView *)sourceView
            controller:(UIViewController *)controller
         pausePlayback:(SCIMediaPreviewPlaybackBlock)pausePlayback
        resumePlayback:(SCIMediaPreviewPlaybackBlock)resumePlayback {
    if (items.count == 0) return;

    if (metadata) {
        for (SCIMediaItem *item in items) {
            if (item && !item.galleryMetadata) {
                item.galleryMetadata = metadata;
            }
        }
    }

    NSInteger adjustedIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    player.isFromGallery = NO;
    [player configurePlaybackContextWithSource:playbackSource
                                    sourceView:sourceView
                                    controller:controller
                                 pausePlayback:pausePlayback
                                resumePlayback:resumePlayback];
    UIViewController *presenter = SCIPreviewPresenterForContext(playbackSource, controller);
    [player playItems:items startingAtIndex:adjustedIndex fromViewController:presenter];
}

+ (void)showImage:(UIImage *)image {
    [self showImage:image metadata:nil];
}

+ (void)showImage:(UIImage *)image metadata:(SCIGallerySaveMetadata *)metadata {
    [self showImage:image
           metadata:metadata
     playbackSource:SCIFullScreenPlaybackSourceUnknown
         sourceView:nil
         controller:nil
      pausePlayback:nil
     resumePlayback:nil];
}

+ (void)showImage:(UIImage *)image
         metadata:(SCIGallerySaveMetadata *)metadata
   playbackSource:(SCIFullScreenPlaybackSource)playbackSource
       sourceView:(UIView *)sourceView
       controller:(UIViewController *)controller
    pausePlayback:(SCIMediaPreviewPlaybackBlock)pausePlayback
   resumePlayback:(SCIMediaPreviewPlaybackBlock)resumePlayback {
    if (!image) return;
    SCIMediaItem *item = [SCIMediaItem itemWithImage:image];
    item.galleryMetadata = metadata;
    if (metadata.sourceUsername.length > 0) {
        item.title = metadata.sourceUsername;
    }
    item.gallerySaveSource = metadata ? (NSInteger)metadata.source : -1;

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    [player configurePlaybackContextWithSource:playbackSource
                                    sourceView:sourceView
                                    controller:controller
                                 pausePlayback:pausePlayback
                                resumePlayback:resumePlayback];
    UIViewController *presenter = SCIPreviewPresenterForContext(playbackSource, controller);
    [player playItems:@[item] startingAtIndex:0 fromViewController:presenter];
}

+ (void)showRemoteImageURL:(NSURL *)url {
    [self showRemoteImageURL:url metadata:nil];
}

+ (void)showRemoteImageURL:(NSURL *)url metadata:(SCIGallerySaveMetadata *)metadata {
    [self showRemoteImageURL:url
                    metadata:metadata
              playbackSource:SCIFullScreenPlaybackSourceUnknown
                  sourceView:nil
                  controller:nil
               pausePlayback:nil
              resumePlayback:nil];
}

+ (void)showRemoteImageURL:(NSURL *)url
                  metadata:(SCIGallerySaveMetadata *)metadata
            playbackSource:(SCIFullScreenPlaybackSource)playbackSource
                sourceView:(UIView *)sourceView
                controller:(UIViewController *)controller
             pausePlayback:(SCIMediaPreviewPlaybackBlock)pausePlayback
            resumePlayback:(SCIMediaPreviewPlaybackBlock)resumePlayback {
    if (!url) return;

    SCIMediaItem *item = [SCIMediaItem itemWithFileURL:url];
    item.galleryMetadata = metadata;
    if (metadata.sourceUsername.length > 0) {
        item.title = metadata.sourceUsername;
    }
    item.gallerySaveSource = metadata ? (NSInteger)metadata.source : -1;

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    [player configurePlaybackContextWithSource:playbackSource
                                    sourceView:sourceView
                                    controller:controller
                                 pausePlayback:pausePlayback
                                resumePlayback:resumePlayback];
    UIViewController *presenter = SCIPreviewPresenterForContext(playbackSource, controller);
    [player playItems:@[item] startingAtIndex:0 fromViewController:presenter];
}

+ (void)showRemoteImageURL:(NSURL *)url profileUsername:(NSString *)username {
    if (!url) return;
    SCIGallerySaveMetadata *meta = [[SCIGallerySaveMetadata alloc] init];
    meta.source = (int16_t)SCIGallerySourceProfile;
    [SCIGalleryOriginController populateProfileMetadata:meta username:username user:nil];
    [self showRemoteImageURL:url metadata:meta];
}

#pragma mark - Playback Context

- (void)configurePlaybackContextWithSource:(SCIFullScreenPlaybackSource)playbackSource
                                sourceView:(UIView *)sourceView
                                controller:(UIViewController *)controller
                             pausePlayback:(SCIMediaPreviewPlaybackBlock)pausePlayback
                            resumePlayback:(SCIMediaPreviewPlaybackBlock)resumePlayback {
    self.playbackSource = playbackSource;
    self.playbackSourceView = sourceView;
    self.playbackSourceController = controller;
    self.pausePlaybackBlock = pausePlayback;
    self.resumePlaybackBlock = resumePlayback;
    self.explicitPlaybackPauseActive = NO;
}

#pragma mark - Present

- (void)playItems:(NSArray<SCIMediaItem *> *)items
  startingAtIndex:(NSInteger)index
fromViewController:(UIViewController *)presenter {
    _items = [items copy];
    _currentIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));
    _controllerCache = [NSMutableDictionary dictionary];
    _isSingleItemMode = (items.count <= 1);
    _isToolbarVisible = YES;

    [self beginPreviewPlaybackSuppressionIfNeeded];
    self.modalPresentationStyle = [self shouldUseLifecycleSuppressingPresentation]
        ? UIModalPresentationFullScreen
        : UIModalPresentationOverFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    self.transitioningDelegate = self;
    [presenter presentViewController:self animated:YES completion:nil];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = [UIColor clearColor];
    [self setupPresentationBackdrop];

    [self setupTopToolbar];
    [self setupBottomBar];
    [self setupPageViewController];
    [self setupDismissGesture];
    [self updateUI];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self prepareViewControllerForDisplay:self.pageViewController.viewControllers.firstObject];
    [self prepareAdjacentViewControllersAroundIndex:self.currentIndex];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (void)setupPresentationBackdrop {
    _presentationBackdropView = [[UIView alloc] initWithFrame:CGRectZero];
    _presentationBackdropView.backgroundColor = [UIColor blackColor];
    _presentationBackdropView.translatesAutoresizingMaskIntoConstraints = NO;
    _presentationBackdropView.alpha = 1.0;
    [self.view addSubview:_presentationBackdropView];
    [NSLayoutConstraint activateConstraints:@[
        [_presentationBackdropView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_presentationBackdropView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_presentationBackdropView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_presentationBackdropView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    [self.view sendSubviewToBack:_presentationBackdropView];
}

#pragma mark - Top Toolbar

- (void)setupTopToolbar {
    _topToolbar = [[UIView alloc] initWithFrame:CGRectZero];
    _topToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_topToolbar];

    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:SCIMediaChromeBlurEffect()];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [_topToolbar addSubview:blurView];

    UIView *contentView = [[UIView alloc] initWithFrame:CGRectZero];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_topToolbar addSubview:contentView];

    UIView *bottomBorder = [[UIView alloc] initWithFrame:CGRectZero];
    bottomBorder.translatesAutoresizingMaskIntoConstraints = NO;
    bottomBorder.backgroundColor = [UIColor separatorColor];
    [_topToolbar addSubview:bottomBorder];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeButton setImage:SCIMediaChromeTopIcon(@"xmark") forState:UIControlStateNormal];
    _closeButton.tintColor = [UIColor labelColor];
    _closeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:_closeButton];

    _counterLabel = SCIMediaChromeTitleLabel(@"");
    _counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:_counterLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_topToolbar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_topToolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_topToolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_topToolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:SCIMediaChromeTopBarContentHeight],

        [blurView.topAnchor constraintEqualToAnchor:_topToolbar.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:_topToolbar.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:_topToolbar.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:_topToolbar.trailingAnchor],

        [contentView.leadingAnchor constraintEqualToAnchor:_topToolbar.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:_topToolbar.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:_topToolbar.bottomAnchor],
        [contentView.heightAnchor constraintEqualToConstant:SCIMediaChromeTopBarContentHeight],

        [bottomBorder.bottomAnchor constraintEqualToAnchor:_topToolbar.bottomAnchor],
        [bottomBorder.leadingAnchor constraintEqualToAnchor:_topToolbar.leadingAnchor],
        [bottomBorder.trailingAnchor constraintEqualToAnchor:_topToolbar.trailingAnchor],
        [bottomBorder.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [_closeButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [_closeButton.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [_closeButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [_closeButton.widthAnchor constraintEqualToConstant:44],

        [_counterLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [_counterLabel.centerYAnchor constraintEqualToAnchor:_closeButton.centerYAnchor],
    ]];

    if (_isFromGallery) {
        _topFavoriteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _topFavoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_topFavoriteButton setImage:SCIMediaChromeTopIcon(@"heart") forState:UIControlStateNormal];
        _topFavoriteButton.tintColor = [UIColor labelColor];
        _topFavoriteButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [_topFavoriteButton addTarget:self action:@selector(favoriteTapped) forControlEvents:UIControlEventTouchUpInside];
        [contentView addSubview:_topFavoriteButton];

        [NSLayoutConstraint activateConstraints:@[
            [_topFavoriteButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
            [_topFavoriteButton.topAnchor constraintEqualToAnchor:contentView.topAnchor],
            [_topFavoriteButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
            [_topFavoriteButton.widthAnchor constraintEqualToConstant:44],
        ]];
    } else {
        _topFavoriteButton = nil;
    }
}

#pragma mark - Bottom Bar

- (void)setupBottomBar {
    _bottomBar = SCIMediaChromeInstallBottomBar(self.view);

    _savePhotosButton = SCIMediaChromeBottomButton(@"download", @"Save to Photos");
    [_savePhotosButton addTarget:self action:@selector(saveToPhotos) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_savePhotosButton];

    _shareButton = SCIMediaChromeBottomButton(@"share", @"Share");
    [_shareButton addTarget:self action:@selector(shareMedia) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_shareButton];

    _clipboardButton = SCIMediaChromeBottomButton(@"copy", @"Copy");
    [_clipboardButton addTarget:self action:@selector(copyMedia) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_clipboardButton];

    if (_isFromGallery) {
        _galleryOriginButton = SCIMediaChromeBottomButton(@"more", @"More");
        [_bottomBar addSubview:_galleryOriginButton];

        _deleteGalleryButton = SCIMediaChromeBottomButton(@"trash", @"Delete from Gallery");
        _deleteGalleryButton.tintColor = [UIColor systemRedColor];
        [_deleteGalleryButton addTarget:self action:@selector(deleteFromGallery) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_deleteGalleryButton];
    } else {
        _saveGalleryButton = SCIMediaChromeBottomButton(@"media", @"Save to Gallery");
        [_saveGalleryButton addTarget:self action:@selector(saveToGallery) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_saveGalleryButton];
    }

    NSArray<UIView *> *row = _isFromGallery
        ? @[_savePhotosButton, _shareButton, _clipboardButton, _galleryOriginButton, _deleteGalleryButton]
        : @[_savePhotosButton, _shareButton, _clipboardButton, _saveGalleryButton];

    SCIMediaChromeInstallBottomRow(_bottomBar, row);
}

#pragma mark - Page View Controller

- (void)setupPageViewController {
    _pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                          navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                        options:nil];
    _pageViewController.dataSource = self;
    _pageViewController.delegate = self;

    [self addChildViewController:_pageViewController];
    _pageViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:_pageViewController.view aboveSubview:_presentationBackdropView];
    [_pageViewController didMoveToParentViewController:self];

    [NSLayoutConstraint activateConstraints:@[
        [_pageViewController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_pageViewController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_pageViewController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_pageViewController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    for (UIView *subview in _pageViewController.view.subviews) {
        if ([subview isKindOfClass:[UIScrollView class]]) {
            _pageScrollView = (UIScrollView *)subview;
            break;
        }
    }

    UIViewController *initialVC = [self viewControllerForIndex:_currentIndex];
    if (initialVC) {
        [_pageViewController setViewControllers:@[initialVC]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:NO
                                     completion:nil];
    }
}

- (UIViewController *)createViewControllerForIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_items.count) return nil;

    SCIMediaItem *item = _items[index];

    if (item.mediaType == SCIMediaItemTypeVideo) {
        SCIFullScreenVideoViewController *vc = [[SCIFullScreenVideoViewController alloc] initWithMediaItem:item];
        vc.delegate = self;
        return vc;
    }

    SCIFullScreenImageViewController *vc = [[SCIFullScreenImageViewController alloc] initWithMediaItem:item];
    vc.delegate = self;
    return vc;
}

- (UIViewController *)viewControllerForIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_items.count) return nil;

    NSNumber *cacheKey = @(index);
    UIViewController *cachedController = self.controllerCache[cacheKey];
    if (cachedController) {
        return cachedController;
    }

    UIViewController *controller = [self createViewControllerForIndex:index];
    if (controller) {
        self.controllerCache[cacheKey] = controller;
    }
    return controller;
}

- (NSInteger)indexOfViewController:(UIViewController *)vc {
    SCIMediaItem *item = nil;
    if ([vc isKindOfClass:[SCIFullScreenImageViewController class]]) {
        item = ((SCIFullScreenImageViewController *)vc).mediaItem;
    } else if ([vc isKindOfClass:[SCIFullScreenVideoViewController class]]) {
        item = ((SCIFullScreenVideoViewController *)vc).mediaItem;
    }
    if (!item) return NSNotFound;
    return [_items indexOfObjectIdenticalTo:item];
}

- (void)prepareViewControllerForDisplay:(UIViewController *)controller {
    SCIMediaItem *item = nil;
    if ([controller isKindOfClass:[SCIFullScreenImageViewController class]]) {
        item = ((SCIFullScreenImageViewController *)controller).mediaItem;
    } else if ([controller isKindOfClass:[SCIFullScreenVideoViewController class]]) {
        item = ((SCIFullScreenVideoViewController *)controller).mediaItem;
    }
    if (item) {
        [[SCIMediaCacheManager sharedManager] prefetchItem:item];
    }

    if ([controller isKindOfClass:[SCIFullScreenVideoViewController class]]) {
        [(SCIFullScreenVideoViewController *)controller prepareForDisplay];
    } else if ([controller isKindOfClass:[SCIFullScreenImageViewController class]]) {
        [(SCIFullScreenImageViewController *)controller preloadContent];
    }
}

- (void)prepareAdjacentViewControllersAroundIndex:(NSInteger)index {
    for (NSInteger resolvedIndex = index - 2; resolvedIndex <= index + 2; resolvedIndex++) {
        if (resolvedIndex == index) continue;
        if (resolvedIndex < 0 || resolvedIndex >= (NSInteger)self.items.count) continue;

        [[SCIMediaCacheManager sharedManager] prefetchItem:self.items[resolvedIndex]];
        UIViewController *controller = [self viewControllerForIndex:resolvedIndex];
        if ([controller isKindOfClass:[SCIFullScreenVideoViewController class]]) {
            [(SCIFullScreenVideoViewController *)controller preloadContent];
        } else if ([controller isKindOfClass:[SCIFullScreenImageViewController class]]) {
            [(SCIFullScreenImageViewController *)controller preloadContent];
        }
    }

    [self trimControllerCacheAroundIndex:index];
}

- (void)trimControllerCacheAroundIndex:(NSInteger)index {
    NSArray<NSNumber *> *cachedIndexes = self.controllerCache.allKeys.copy;
    for (NSNumber *cachedIndex in cachedIndexes) {
        NSInteger value = cachedIndex.integerValue;
        if (ABS(value - index) <= 2) continue;

        UIViewController *controller = self.controllerCache[cachedIndex];
        if ([controller respondsToSelector:@selector(cleanup)]) {
            [(id)controller cleanup];
        }
        [self.controllerCache removeObjectForKey:cachedIndex];
    }
}

#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    NSInteger index = [self indexOfViewController:viewController];
    if (index == NSNotFound || index == 0) return nil;
    return [self viewControllerForIndex:index - 1];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    NSInteger index = [self indexOfViewController:viewController];
    if (index == NSNotFound || index >= (NSInteger)_items.count - 1) return nil;
    return [self viewControllerForIndex:index + 1];
}

#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed {
    if (!completed) return;

    UIViewController *currentVC = pageViewController.viewControllers.firstObject;
    NSInteger newIndex = [self indexOfViewController:currentVC];
    if (newIndex == NSNotFound) return;

    _currentIndex = newIndex;
    [self updateUI];
    [self prepareViewControllerForDisplay:currentVC];
    [self prepareAdjacentViewControllersAroundIndex:newIndex];

    for (UIViewController *prevVC in previousViewControllers) {
        if ([prevVC isKindOfClass:[SCIFullScreenVideoViewController class]]) {
            [(SCIFullScreenVideoViewController *)prevVC pause];
        }
    }
}

#pragma mark - SCIFullScreenContentDelegate

- (void)mediaContentDidTap:(UIViewController *)controller {
    [self toggleToolbar];
}

- (void)mediaContent:(UIViewController *)controller didFailWithError:(NSError *)error {
}

#pragma mark - UI Updates

- (void)updateUI {
    [self updateCounter];
    [self updateFavoriteButton];
    [self updateGalleryOriginButton];
}

- (void)updateCounter {
    if (_isSingleItemMode) {
        _counterLabel.text = @"";
        [_counterLabel sizeToFit];
        return;
    }
    _counterLabel.text = [NSString stringWithFormat:@"%ld of %lu",
                          (long)_currentIndex + 1,
                          (unsigned long)_items.count];
    [_counterLabel sizeToFit];
}

- (void)updateFavoriteButton {
    if (!_topFavoriteButton) return;

    SCIMediaItem *item = [self currentItem];
    BOOL isFav = item.galleryFile.isFavorite;
    UIImage *img = isFav
        ? SCIMediaChromeTopIcon(@"heart_filled")
        : SCIMediaChromeTopIcon(@"heart");

    if (!item.galleryFile) {
        _topFavoriteButton.hidden = YES;
        return;
    }

    _topFavoriteButton.hidden = NO;
    [_topFavoriteButton setImage:img forState:UIControlStateNormal];
    _topFavoriteButton.tintColor = isFav ? [UIColor systemPinkColor] : [UIColor labelColor];
}

- (void)showGalleryOpenFailureMessage:(NSString *)title actionIdentifier:(NSString *)actionIdentifier {
    [SCIUtils showToastForActionIdentifier:actionIdentifier duration:2.0
                             title:title
                          subtitle:@"The original content may no longer exist."
                      iconResource:@"error_filled"
                              tone:SCIFeedbackPillToneError];
}

- (void)openOriginalPostForCurrentGalleryItem {
    SCIGalleryFile *file = self.currentItem.galleryFile;
    if ([SCIGalleryOriginController openOriginalPostForGalleryFile:file]) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionGalleryOpenOriginal duration:1.4 title:@"Opened original post" subtitle:nil iconResource:@"external_link"];
    } else {
        [self showGalleryOpenFailureMessage:@"Unable to open original post" actionIdentifier:kSCIFeedbackActionGalleryOpenOriginal];
    }
}

- (void)openProfileForCurrentGalleryItem {
    SCIGalleryFile *file = self.currentItem.galleryFile;
    if ([SCIGalleryOriginController openProfileForGalleryFile:file]) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionGalleryOpenProfile duration:1.4 title:@"Opened profile" subtitle:nil iconResource:@"profile"];
    } else {
        [self showGalleryOpenFailureMessage:@"Unable to open profile" actionIdentifier:kSCIFeedbackActionGalleryOpenProfile];
    }
}

- (UIMenu *)galleryOriginMenuForCurrentItem {
    SCIGalleryFile *file = self.currentItem.galleryFile;
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    if (file.hasOpenableOriginalMedia) {
        [actions addObject:[UIAction actionWithTitle:@"Open Original Post"
                                               image:SCIGalleryPreviewMenuIcon(@"external_link")
                                          identifier:nil
                                             handler:^(__unused UIAction *action) {
            [weakSelf openOriginalPostForCurrentGalleryItem];
        }]];
    }

    if (file.hasOpenableProfile) {
        [actions addObject:[UIAction actionWithTitle:@"Open Profile"
                                               image:SCIGalleryPreviewMenuIcon(@"profile")
                                          identifier:nil
                                             handler:^(__unused UIAction *action) {
            [weakSelf openProfileForCurrentGalleryItem];
        }]];
    }

    if (actions.count == 0) {
        UIAction *empty = [UIAction actionWithTitle:@"No origin actions available" image:nil identifier:nil handler:^(__unused UIAction *action) {}];
        empty.attributes = UIMenuElementAttributesDisabled;
        [actions addObject:empty];
    }

    return [UIMenu menuWithTitle:@"" children:actions];
}

- (void)performSingleGalleryOriginAction {
    SCIGalleryFile *file = self.currentItem.galleryFile;
    if (file.hasOpenableProfile && !file.hasOpenableOriginalMedia) {
        [self openProfileForCurrentGalleryItem];
        return;
    }
    if (file.hasOpenableOriginalMedia && !file.hasOpenableProfile) {
        [self openOriginalPostForCurrentGalleryItem];
    }
}

- (void)updateGalleryOriginButton {
    if (!_galleryOriginButton) return;

    SCIGalleryFile *file = self.currentItem.galleryFile;
    BOOL hasOriginal = file.hasOpenableOriginalMedia;
    BOOL hasProfile = file.hasOpenableProfile;
    NSInteger actionCount = (hasOriginal ? 1 : 0) + (hasProfile ? 1 : 0);

    _galleryOriginButton.hidden = !file;
    [_galleryOriginButton removeTarget:self action:@selector(performSingleGalleryOriginAction) forControlEvents:UIControlEventTouchUpInside];

    if (actionCount <= 0) {
        [_galleryOriginButton setImage:SCIMediaChromeBottomIcon(@"more") forState:UIControlStateNormal];
        _galleryOriginButton.accessibilityLabel = @"More";
        _galleryOriginButton.enabled = NO;
        _galleryOriginButton.alpha = 0.55;
        _galleryOriginButton.menu = nil;
        _galleryOriginButton.showsMenuAsPrimaryAction = NO;
        return;
    }

    _galleryOriginButton.enabled = YES;
    _galleryOriginButton.alpha = 1.0;

    if (actionCount == 1) {
        NSString *resourceName = hasProfile ? @"profile" : @"external_link";
        NSString *label = hasProfile ? @"Open Profile" : @"Open Original Post";
        [_galleryOriginButton setImage:SCIMediaChromeBottomIcon(resourceName) forState:UIControlStateNormal];
        _galleryOriginButton.accessibilityLabel = label;
        _galleryOriginButton.menu = nil;
        _galleryOriginButton.showsMenuAsPrimaryAction = NO;
        [_galleryOriginButton addTarget:self action:@selector(performSingleGalleryOriginAction) forControlEvents:UIControlEventTouchUpInside];
        return;
    }

    [_galleryOriginButton setImage:SCIMediaChromeBottomIcon(@"more") forState:UIControlStateNormal];
    _galleryOriginButton.accessibilityLabel = @"More";
    _galleryOriginButton.menu = [self galleryOriginMenuForCurrentItem];
    _galleryOriginButton.showsMenuAsPrimaryAction = YES;
}

#pragma mark - Toolbar Toggle

- (void)toggleToolbar {
    _isToolbarVisible = !_isToolbarVisible;
    [UIView animateWithDuration:0.25 animations:^{
        CGFloat alpha = self->_isToolbarVisible ? 1.0 : 0.0;
        self->_topToolbar.alpha = alpha;
        if (self->_bottomBar) self->_bottomBar.alpha = alpha;
    }];
}

#pragma mark - Current Item

- (SCIMediaItem *)currentItem {
    if (_currentIndex < 0 || _currentIndex >= (NSInteger)_items.count) return nil;
    return _items[_currentIndex];
}

- (NSURL *)currentFileURL {
    SCIMediaItem *item = [self currentItem];
    NSURL *bestURL = [[SCIMediaCacheManager sharedManager] bestAvailableFileURLForItem:item];
    return bestURL ?: item.fileURL;
}

#pragma mark - Playback Suppression

- (BOOL)shouldUseLifecycleSuppressingPresentation {
    switch (self.playbackSource) {
        case SCIFullScreenPlaybackSourceFeed:
        case SCIFullScreenPlaybackSourceReels:
        case SCIFullScreenPlaybackSourceProfile:
        case SCIFullScreenPlaybackSourceStories:
        case SCIFullScreenPlaybackSourceDirect:
            return YES;
        case SCIFullScreenPlaybackSourceUnknown:
        default:
            return NO;
    }
}

- (BOOL)shouldUseExplicitPlaybackCallbacks {
    switch (self.playbackSource) {
        case SCIFullScreenPlaybackSourceStories:
        case SCIFullScreenPlaybackSourceDirect:
            return YES;
        case SCIFullScreenPlaybackSourceFeed:
        case SCIFullScreenPlaybackSourceReels:
        case SCIFullScreenPlaybackSourceProfile:
        case SCIFullScreenPlaybackSourceUnknown:
        default:
            return NO;
    }
}

- (void)beginPreviewPlaybackSuppressionIfNeeded {
    if ([self shouldUseExplicitPlaybackCallbacks] && self.pausePlaybackBlock && !self.explicitPlaybackPauseActive) {
        self.pausePlaybackBlock();
        self.explicitPlaybackPauseActive = YES;
    }
}

- (void)restorePreviewPlaybackIfNeeded {
    if (self.explicitPlaybackPauseActive && self.resumePlaybackBlock) {
        self.resumePlaybackBlock();
    }
    self.explicitPlaybackPauseActive = NO;
}

#pragma mark - Actions

- (void)closeTapped {
    [self cleanupAll];
    [self dismissViewControllerAnimated:YES completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self restorePreviewPlaybackIfNeeded];
        });
        if ([self.delegate respondsToSelector:@selector(fullScreenMediaPlayerDidDismiss)]) {
            [self.delegate fullScreenMediaPlayerDidDismiss];
        }
    }];
}

- (void)favoriteTapped {
    SCIMediaItem *item = [self currentItem];
    if (!item.galleryFile) return;

    item.galleryFile.isFavorite = !item.galleryFile.isFavorite;
    [[SCIGalleryCoreDataStack shared] saveContext];
    [self updateFavoriteButton];

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
}

- (void)saveToPhotos {
    NSURL *url = [self currentFileURL];
    SCIMediaItem *item = [self currentItem];
    if (!url && !item.image) return;

    if (url.isFileURL || (!url && item.image)) {
        if (item.mediaType == SCIMediaItemTypeImage || item.image) {
            NSData *imageData = url ? [NSData dataWithContentsOfURL:url] : nil;
            UIImage *image = item.image ?: [UIImage imageWithData:imageData];
            if (image) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:^(BOOL success, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showSaveResult:success error:error];
                    });
                }];
            }
        } else {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
            } completionHandler:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showSaveResult:success error:error];
                });
            }];
        }
        return;
    }

    NSString *ext = url.pathExtension;
    if (ext.length == 0) ext = item.mediaType == SCIMediaItemTypeVideo ? @"mp4" : @"jpg";
    
    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:saveToPhotos showProgress:[SCIUtils shouldShowFeedbackPillForActionIdentifier:kSCIFeedbackActionMediaPreviewSavePhotos]];
    delegate.pendingGallerySaveMetadata = item.galleryMetadata;
    [delegate downloadFileWithURL:url fileExtension:ext hudLabel:nil];
}

- (void)showSaveResult:(BOOL)success error:(NSError *)error {
    if (success) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewSavePhotos duration:2.0
                                 title:@"Saved to Photos"
                              subtitle:nil
                          iconResource:@"circle_check_filled"
                                  tone:SCIFeedbackPillToneSuccess];
    } else {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewSavePhotos duration:3.0
                                 title:@"Failed to save"
                              subtitle:error.localizedDescription
                          iconResource:@"error_filled"
                                  tone:SCIFeedbackPillToneError];
    }
}

- (void)saveToGallery {
    NSURL *targetURL = [self currentFileURL];
    SCIMediaItem *item = [self currentItem];

    if (!targetURL && !item.image) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewSaveGallery duration:2.0
                                 title:@"No media to save"
                              subtitle:nil
                          iconResource:@"media"
                                  tone:SCIFeedbackPillToneError];
        return;
    }

    SCIGalleryMediaType galleryType = (item.mediaType == SCIMediaItemTypeVideo && targetURL) ? SCIGalleryMediaTypeVideo : SCIGalleryMediaTypeImage;

    if (targetURL.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:targetURL.path]) {
        [self gallerySaveLocalFile:targetURL mediaType:galleryType];
        return;
    } else if (!targetURL && item.image) {
        NSData *jpegData = UIImageJPEGRepresentation(item.image, 0.95);
        if (jpegData) {
            NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"jpg"]];
            NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
            [jpegData writeToURL:tempURL atomically:YES];
            [self gallerySaveLocalFile:tempURL mediaType:SCIGalleryMediaTypeImage];
            [[NSFileManager defaultManager] removeItemAtURL:tempURL error:nil];
            return;
        }
    }

    NSString *ext = targetURL.pathExtension;
    if (ext.length == 0) ext = galleryType == SCIGalleryMediaTypeVideo ? @"mp4" : @"jpg";

    SCIGallerySaveMetadata *meta = item.galleryMetadata;
    if (!meta && (item.title.length > 0 || item.gallerySaveSource >= 0)) {
        meta = [[SCIGallerySaveMetadata alloc] init];
        if (item.title.length) {
            meta.sourceUsername = item.title;
        }
        if (item.gallerySaveSource >= 0) {
            meta.source = (int16_t)item.gallerySaveSource;
        } else {
            meta.source = (int16_t)SCIGallerySourceOther;
        }
    }
    
    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:saveToGallery showProgress:[SCIUtils shouldShowFeedbackPillForActionIdentifier:kSCIFeedbackActionMediaPreviewSaveGallery]];
    delegate.pendingGallerySaveMetadata = meta;
    [delegate downloadFileWithURL:targetURL fileExtension:ext hudLabel:nil];
}

- (void)gallerySaveLocalFile:(NSURL *)localURL mediaType:(SCIGalleryMediaType)galleryType {
    NSError *error;
    SCIMediaItem *item = [self currentItem];
    SCIGallerySaveMetadata *meta = item.galleryMetadata;
    if (!meta && (item.title.length > 0 || item.gallerySaveSource >= 0)) {
        meta = [[SCIGallerySaveMetadata alloc] init];
        if (item.title.length) {
            meta.sourceUsername = item.title;
        }
        if (item.gallerySaveSource >= 0) {
            meta.source = (int16_t)item.gallerySaveSource;
        } else {
            meta.source = (int16_t)SCIGallerySourceOther;
        }
    }
    SCIGalleryFile *file = [SCIGalleryFile saveFileToGallery:localURL
                                                source:SCIGallerySourceOther
                                             mediaType:galleryType
                                            folderPath:nil
                                              metadata:meta
                                                 error:&error];

    if (file) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewSaveGallery duration:2.0
                                 title:@"Saved to Gallery"
                              subtitle:nil
                          iconResource:@"circle_check_filled"
                                  tone:SCIFeedbackPillToneSuccess];
    } else {
        NSString *msg = error.localizedDescription.length ? error.localizedDescription : @"Failed to save";
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewSaveGallery duration:3.0
                                 title:@"Failed to save"
                              subtitle:msg
                          iconResource:@"error_filled"
                                  tone:SCIFeedbackPillToneError];
    }
}

- (void)shareMedia {
    NSURL *url = [self currentFileURL];
    SCIMediaItem *item = [self currentItem];
    if (!url && !item.image) return;

    if (url.isFileURL || (!url && item.image)) {
        id activityItem = url.isFileURL ? url : item.image;
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewShare duration:1.4
                                         title:@"Opened share sheet"
                                      subtitle:nil
                                  iconResource:@"share"
                                          tone:SCIFeedbackPillToneInfo];
        UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[activityItem] applicationActivities:nil];
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad && _shareButton) {
            acVC.popoverPresentationController.sourceView = _shareButton;
            acVC.popoverPresentationController.sourceRect = _shareButton.bounds;
        }
        [self presentViewController:acVC animated:YES completion:nil];
        return;
    }

    NSString *ext = url.pathExtension;
    if (ext.length == 0) ext = item.mediaType == SCIMediaItemTypeVideo ? @"mp4" : @"jpg";
    
    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:share showProgress:[SCIUtils shouldShowFeedbackPillForActionIdentifier:kSCIFeedbackActionMediaPreviewShare]];
    delegate.pendingGallerySaveMetadata = item.galleryMetadata;
    [delegate downloadFileWithURL:url fileExtension:ext hudLabel:nil];
}

- (void)copyMedia {
    SCIMediaItem *item = [self currentItem];
    NSURL *url = [self currentFileURL];
    if (!url && !item.image) return;

    if (item.mediaType == SCIMediaItemTypeImage || (!url && item.image)) {
        NSData *imageData = url ? [NSData dataWithContentsOfURL:url] : nil;
        UIImage *image = item.image ?: [UIImage imageWithData:imageData];
        if (image) {
            [[UIPasteboard generalPasteboard] setImage:image];
            [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewCopy duration:1.5
                                     title:@"Copied photo to clipboard"
                                  subtitle:nil
                              iconResource:@"copy_filled"
                                      tone:SCIFeedbackPillToneSuccess];
        }
    } else {
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            [[UIPasteboard generalPasteboard] setData:data forPasteboardType:@"public.mpeg-4"];
            [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewCopy duration:1.5
                                     title:@"Copied video to clipboard"
                                  subtitle:nil
                              iconResource:@"copy_filled"
                                      tone:SCIFeedbackPillToneSuccess];
        }
    }
}

- (void)deleteFromGallery {
    SCIMediaItem *item = [self currentItem];
    if (!item.galleryFile) return;

    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete from Gallery?"
                                                                  message:@"This will permanently remove this file."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf performDeleteCurrentItem];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performDeleteCurrentItem {
    SCIMediaItem *item = [self currentItem];
    if (!item.galleryFile) return;

    NSInteger deletedIndex = _currentIndex;
    NSError *err;
    [item.galleryFile removeWithError:&err];
    if (err) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewDeleteGallery duration:2.0
                                 title:@"Failed to delete"
                              subtitle:err.localizedDescription
                          iconResource:@"error_filled"
                                  tone:SCIFeedbackPillToneError];
        return;
    }

    NSMutableArray *mutableItems = [_items mutableCopy];
    [mutableItems removeObjectAtIndex:deletedIndex];
    _items = [mutableItems copy];
    _isSingleItemMode = (_items.count <= 1);

    if ([self.delegate respondsToSelector:@selector(fullScreenMediaPlayerDidDeleteFileAtIndex:)]) {
        [self.delegate fullScreenMediaPlayerDidDeleteFileAtIndex:deletedIndex];
    }

    if (_items.count == 0) {
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewDeleteGallery duration:1.5
                                         title:@"Deleted from Gallery"
                                      subtitle:nil
                                  iconResource:@"circle_check_filled"
                                          tone:SCIFeedbackPillToneSuccess];
        [self closeTapped];
        return;
    }

    for (UIViewController *controller in self.controllerCache.allValues) {
        if ([controller respondsToSelector:@selector(cleanup)]) {
            [(id)controller cleanup];
        }
    }
    [self.controllerCache removeAllObjects];

    _currentIndex = MIN(deletedIndex, (NSInteger)_items.count - 1);
    UIViewController *newVC = [self viewControllerForIndex:_currentIndex];
    if (newVC) {
        [_pageViewController setViewControllers:@[newVC]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:YES
                                     completion:nil];
    }
    [self prepareViewControllerForDisplay:newVC];
    [self prepareAdjacentViewControllersAroundIndex:_currentIndex];
    [self updateUI];
    [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionMediaPreviewDeleteGallery duration:1.5
                                     title:@"Deleted from Gallery"
                                  subtitle:nil
                              iconResource:@"circle_check_filled"
                                      tone:SCIFeedbackPillToneSuccess];
}

#pragma mark - Swipe to Dismiss

- (void)setupDismissGesture {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanDismiss:)];
    pan.delegate = self;
    pan.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:pan];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    UIViewController *currentVC = _pageViewController.viewControllers.firstObject;
    if ([currentVC isKindOfClass:[SCIFullScreenImageViewController class]] &&
        [(SCIFullScreenImageViewController *)currentVC isZoomed]) {
        return NO;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handlePanDismiss:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.view];
    CGPoint velocity = [pan velocityInView:self.view];

    if (pan.state == UIGestureRecognizerStateBegan) {
        _dismissPanDecided = NO;
        _dismissPanIsVertical = NO;
        _pageScrollView.scrollEnabled = YES;
        return;
    }

    CGFloat tx = translation.x;
    CGFloat ty = translation.y;

    if (!_dismissPanDecided) {
        CGFloat mag = hypot(tx, ty);
        if (mag < kDismissAxisLockSlop) {
            if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
                [self resetDismissInteractiveStateAnimated:NO];
            }
            return;
        }
        _dismissPanDecided = YES;
        _dismissPanIsVertical = fabs(ty) >= fabs(tx);
        _pageScrollView.scrollEnabled = !_dismissPanIsVertical;
    }

    if (!_dismissPanIsVertical) {
        if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
            [self resetDismissInteractiveStateAnimated:NO];
        }
        return;
    }

    [self beginInteractiveDismissalIfNeeded];
    if (!self.interactiveDismissTransitionContext) return;

    CGFloat dy = ty;
    CGFloat absDy = fabs(dy);
    CGFloat maximumBackdropDelta = MAX(1.0, CGRectGetHeight(self.view.bounds) / 2.0);
    CGFloat deltaRatio = MIN(1.0, absDy / maximumBackdropDelta);
    CGFloat backdropAlpha = 1.0 - (deltaRatio * (1.0 - kDismissFinalBackdropAlpha));

    switch (pan.state) {
        case UIGestureRecognizerStateChanged: {
            [self updateInteractiveDismissalWithVerticalDelta:dy backdropAlpha:backdropAlpha];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat dismissDistance = kDismissDistanceRatio * CGRectGetHeight(self.view.bounds);
            BOOL commit = pan.state != UIGestureRecognizerStateCancelled && absDy > dismissDistance;
            if (commit) {
                CGFloat direction = dy >= 0.0 ? 1.0 : -1.0;
                CGFloat finalCenterY = self.interactiveDismissAnchorPoint.y + direction * CGRectGetHeight(self.view.bounds);
                CGFloat vy = MAX(fabs(velocity.y), kDismissMinimumVelocity);
                CGFloat duration = fabs(finalCenterY - _pageViewController.view.center.y) / vy;
                duration = MIN(duration, kDismissMaximumDuration);
                duration = MAX(kDismissMinimumDuration, duration);

                [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
                    self->_pageViewController.view.center = CGPointMake(self.interactiveDismissAnchorPoint.x, finalCenterY);
                    self.presentationBackdropView.alpha = 0.0;
                    self->_topToolbar.alpha = 0.0;
                    if (self->_bottomBar) self->_bottomBar.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [self finishInteractiveDismissal];
                }];
            } else {
                CGFloat duration = fabs(velocity.y) * kDismissReturnVelocityAnimationRatio + 0.2;
                [self removeTransitionToViewForCancelledInteractiveDismissalIfNeeded];
                [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
                    self->_pageViewController.view.center = self.interactiveDismissAnchorPoint;
                    self.presentationBackdropView.alpha = 1.0;
                    CGFloat alpha = self->_isToolbarVisible ? 1.0 : 0.0;
                    self->_topToolbar.alpha = alpha;
                    if (self->_bottomBar) self->_bottomBar.alpha = alpha;
                } completion:^(BOOL finished) {
                    UIViewController *currentVC = self->_pageViewController.viewControllers.firstObject;
                    if ([currentVC isKindOfClass:[SCIFullScreenImageViewController class]]) {
                        [(SCIFullScreenImageViewController *)currentVC resetZoomIfNeeded];
                    }
                    [self cancelInteractiveDismissal];
                }];
            }
            _dismissPanDecided = NO;
            _pageScrollView.scrollEnabled = YES;
            break;
        }
        case UIGestureRecognizerStateFailed: {
            if (self.interactiveDismissTransitionContext) {
                [self removeTransitionToViewForCancelledInteractiveDismissalIfNeeded];
                [self cancelInteractiveDismissal];
            } else if (_dismissPanDecided && _dismissPanIsVertical) {
                [self resetDismissInteractiveStateAnimated:YES];
            }
            _dismissPanDecided = NO;
            _dismissPanIsVertical = NO;
            _pageScrollView.scrollEnabled = YES;
            break;
        }
        default:
            break;
    }
}

- (void)resetDismissInteractiveStateAnimated:(BOOL)animated {
    _dismissPanDecided = NO;
    _dismissPanIsVertical = NO;
    _pageScrollView.scrollEnabled = YES;
    void (^animations)(void) = ^{
        self->_pageViewController.view.transform = CGAffineTransformIdentity;
        self->_pageViewController.view.center = SCICenterForBounds(self.view.bounds);
        self.presentationBackdropView.alpha = 1.0;
        CGFloat alpha = self->_isToolbarVisible ? 1.0 : 0.0;
        self->_topToolbar.alpha = alpha;
        if (self->_bottomBar) self->_bottomBar.alpha = alpha;
    };
    if (animated) {
        [UIView animateWithDuration:0.25 animations:animations];
    } else {
        animations();
    }
}

#pragma mark - Interactive Dismissal Transition

- (void)beginInteractiveDismissalIfNeeded {
    if (self.interactiveDismissalInProgress) return;

    self.interactiveDismissalInProgress = YES;
    self.interactiveDismissAnchorPoint = self.pageViewController.view.center;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateInteractiveDismissalWithVerticalDelta:(CGFloat)verticalDelta backdropAlpha:(CGFloat)backdropAlpha {
    id<UIViewControllerContextTransitioning> transitionContext = self.interactiveDismissTransitionContext;
    UIView *fromView = [transitionContext viewForKey:UITransitionContextFromViewKey];
    UIView *toView = [transitionContext viewForKey:UITransitionContextToViewKey];

    if (toView && !toView.superview) {
        UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
        toView.frame = [transitionContext finalFrameForViewController:toViewController];
        if (![toView isDescendantOfView:transitionContext.containerView]) {
            [transitionContext.containerView addSubview:toView];
        }
        [transitionContext.containerView bringSubviewToFront:fromView ?: self.view];
    }

    self.pageViewController.view.center = CGPointMake(self.interactiveDismissAnchorPoint.x,
                                                      self.interactiveDismissAnchorPoint.y + verticalDelta);
    self.presentationBackdropView.alpha = backdropAlpha;
    CGFloat fade = (self.isToolbarVisible ? 1.0 : 0.0) * backdropAlpha;
    self.topToolbar.alpha = MAX(0.0, fade);
    if (self.bottomBar) self.bottomBar.alpha = MAX(0.0, fade);
}

- (void)removeTransitionToViewForCancelledInteractiveDismissalIfNeeded {
    id<UIViewControllerContextTransitioning> transitionContext = self.interactiveDismissTransitionContext;
    if (transitionContext.presentationStyle != UIModalPresentationFullScreen) return;

    UIView *toView = [transitionContext viewForKey:UITransitionContextToViewKey];
    [toView removeFromSuperview];
}

- (void)finishInteractiveDismissal {
    id<UIViewControllerContextTransitioning> transitionContext = self.interactiveDismissTransitionContext;
    [transitionContext finishInteractiveTransition];
    [transitionContext completeTransition:!transitionContext.transitionWasCancelled];
    self.interactiveDismissTransitionContext = nil;
    self.interactiveDismissalInProgress = NO;

    [self cleanupAll];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self restorePreviewPlaybackIfNeeded];
    });
    if ([self.delegate respondsToSelector:@selector(fullScreenMediaPlayerDidDismiss)]) {
        [self.delegate fullScreenMediaPlayerDidDismiss];
    }
}

- (void)cancelInteractiveDismissal {
    id<UIViewControllerContextTransitioning> transitionContext = self.interactiveDismissTransitionContext;
    [transitionContext cancelInteractiveTransition];
    [transitionContext completeTransition:NO];
    self.interactiveDismissTransitionContext = nil;
    self.interactiveDismissalInProgress = NO;
    self.pageViewController.view.transform = CGAffineTransformIdentity;
    self.pageViewController.view.center = SCICenterForBounds(self.view.bounds);
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    return self.interactiveDismissalInProgress ? self : nil;
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator {
    return self.interactiveDismissalInProgress ? self : nil;
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return kDismissMaximumDuration;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    [transitionContext completeTransition:!transitionContext.transitionWasCancelled];
}

- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    self.interactiveDismissTransitionContext = transitionContext;
}

#pragma mark - Cleanup

- (void)cleanupAll {
    for (UIViewController *controller in self.controllerCache.allValues) {
        if ([controller respondsToSelector:@selector(cleanup)]) {
            [(id)controller cleanup];
        }
    }
    [self.controllerCache removeAllObjects];

    [[AVAudioSession sharedInstance] setActive:NO
                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                         error:nil];
}

@end
