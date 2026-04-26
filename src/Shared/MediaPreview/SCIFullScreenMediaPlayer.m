#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

#import "SCIFullScreenMediaPlayer.h"
#import "SCIUnderlyingPlaybackController.h"
#import "SCIMediaItem.h"
#import "SCIMediaCacheManager.h"
#import "SCIFullScreenImageViewController.h"
#import "SCIFullScreenVideoViewController.h"
#import "../../Utils.h"
#import "../UI/SCIMediaChrome.h"
#import "../Vault/SCIVaultFile.h"
#import "../Vault/SCIVaultOriginController.h"
#import "../Vault/SCIVaultSaveMetadata.h"
#import "../Vault/SCIVaultCoreDataStack.h"
#import "../../Downloader/Download.h"

static CGFloat const kDismissAxisLockSlop = 20.0;
static CGFloat const kDismissProgressDenominator = 520.0;
static CGFloat const kDismissProgressCommit = 0.34;
static CGFloat const kDismissVelocityCommit = 980.0;
static CGFloat const kDismissFinishDuration = 0.24;
static CGFloat const kDismissCancelSpringDamping = 0.9;
static CGFloat const kDismissMinScale = 0.92;
static NSTimeInterval const kUnderlyingPlaybackDeferredRefreshShortDelay = 0.18;
static NSTimeInterval const kUnderlyingPlaybackDeferredRefreshLongDelay = 0.55;
static CGFloat const kVaultPreviewMenuIconPointSize = 22.0;

static UIImage *SCIVaultPreviewMenuIcon(NSString *resourceName, NSString *systemName) {
    UIImage *image = resourceName.length > 0
        ? [SCIUtils sci_resourceImageNamed:resourceName template:YES maxPointSize:kVaultPreviewMenuIconPointSize]
        : nil;
    if (!image) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:kVaultPreviewMenuIconPointSize
                                                                                                     weight:UIImageSymbolWeightRegular];
        image = [UIImage systemImageNamed:systemName withConfiguration:configuration];
    }
    return image;
}

@interface SCIFullScreenMediaPlayer () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate, SCIFullScreenContentDelegate>

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
@property (nonatomic, strong) UIButton *saveVaultButton;
@property (nonatomic, strong) UIButton *deleteVaultButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *clipboardButton;
@property (nonatomic, strong) UIButton *vaultMoreButton;

@property (nonatomic, assign) BOOL isToolbarVisible;
@property (nonatomic, assign) BOOL isSingleItemMode;

@property (nonatomic, assign) BOOL dismissPanDecided;
@property (nonatomic, assign) BOOL dismissPanIsVertical;
@property (nonatomic, weak) UIScrollView *pageScrollView;

@property (nonatomic, strong) SCIUnderlyingPlaybackController *underlyingPlaybackController;
@property (nonatomic, assign) NSInteger underlyingPlaybackRefreshGeneration;

/// Opaque black behind page content (letterboxing); alpha fades during dismiss so OverFullScreen content shows through.
@property (nonatomic, strong) UIView *presentationBackdropView;

@end

@implementation SCIFullScreenMediaPlayer

#pragma mark - Convenience Factories

+ (void)showFileURL:(NSURL *)fileURL {
    [self showFileURL:fileURL fromVault:NO];
}

+ (void)showFileURL:(NSURL *)fileURL metadata:(SCIVaultSaveMetadata *)metadata {
    SCIMediaItem *item = [SCIMediaItem itemWithFileURL:fileURL];
    item.isFromVault = NO;
    item.vaultMetadata = metadata;

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    player.isFromVault = NO;

    UIViewController *presenter = topMostController();
    [player playItems:@[item] startingAtIndex:0 fromViewController:presenter];
}

+ (void)showFileURL:(NSURL *)fileURL fromVault:(BOOL)fromVault {
    SCIMediaItem *item = [SCIMediaItem itemWithFileURL:fileURL];
    item.isFromVault = fromVault;

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    player.isFromVault = fromVault;

    UIViewController *presenter = topMostController();
    [player playItems:@[item] startingAtIndex:0 fromViewController:presenter];
}

+ (void)showVaultFiles:(NSArray<SCIVaultFile *> *)files
       startingAtIndex:(NSInteger)index
    fromViewController:(UIViewController *)presenter {
    if (files.count == 0) return;

    NSMutableArray<SCIMediaItem *> *items = [NSMutableArray arrayWithCapacity:files.count];
    for (SCIVaultFile *file in files) {
        if (![file fileExists]) continue;
        SCIMediaItem *item = [SCIMediaItem itemWithVaultFile:file];
        [items addObject:item];
    }

    if (items.count == 0) {
        [SCIUtils showToastForDuration:2.0
                                 title:@"No files found"
                              subtitle:nil
                          iconResource:@"search"
               fallbackSystemImageName:@"magnifyingglass"
                                  tone:SCIFeedbackPillToneError];
        return;
    }

    NSInteger adjustedIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    player.isFromVault = YES;
    [player playItems:items startingAtIndex:adjustedIndex fromViewController:presenter];
}

+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index {
    [self showPhotoURLs:urls initialIndex:index metadata:nil];
}

+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index metadata:(SCIVaultSaveMetadata *)metadata {
    if (urls.count == 0) return;

    NSMutableArray<SCIMediaItem *> *items = [NSMutableArray arrayWithCapacity:urls.count];
    for (NSURL *url in urls) {
        SCIMediaItem *item = [SCIMediaItem itemWithFileURL:url];
        item.vaultMetadata = metadata;
        [items addObject:item];
    }

    NSInteger adjustedIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    UIViewController *presenter = topMostController();
    [player playItems:items startingAtIndex:adjustedIndex fromViewController:presenter];
}

+ (void)showMediaItems:(NSArray<SCIMediaItem *> *)items startingAtIndex:(NSInteger)index metadata:(SCIVaultSaveMetadata *)metadata {
    [self showMediaItems:items
         startingAtIndex:index
                metadata:metadata
          playbackSource:SCIFullScreenPlaybackSourceUnknown
              sourceView:nil
              controller:nil];
}

+ (void)showMediaItems:(NSArray<SCIMediaItem *> *)items
       startingAtIndex:(NSInteger)index
              metadata:(SCIVaultSaveMetadata *)metadata
        playbackSource:(SCIFullScreenPlaybackSource)playbackSource
            sourceView:(UIView *)sourceView
            controller:(UIViewController *)controller {
    if (items.count == 0) return;

    if (metadata) {
        for (SCIMediaItem *item in items) {
            if (item && !item.vaultMetadata) {
                item.vaultMetadata = metadata;
            }
        }
    }

    NSInteger adjustedIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    player.isFromVault = NO;
    [player configurePlaybackContextWithSource:playbackSource sourceView:sourceView controller:controller];
    UIViewController *presenter = topMostController();
    [player playItems:items startingAtIndex:adjustedIndex fromViewController:presenter];
}

+ (void)showImage:(UIImage *)image {
    [self showImage:image metadata:nil];
}

+ (void)showImage:(UIImage *)image metadata:(SCIVaultSaveMetadata *)metadata {
    [self showImage:image
           metadata:metadata
     playbackSource:SCIFullScreenPlaybackSourceUnknown
         sourceView:nil
         controller:nil];
}

+ (void)showImage:(UIImage *)image
         metadata:(SCIVaultSaveMetadata *)metadata
   playbackSource:(SCIFullScreenPlaybackSource)playbackSource
       sourceView:(UIView *)sourceView
       controller:(UIViewController *)controller {
    if (!image) return;
    SCIMediaItem *item = [SCIMediaItem itemWithImage:image];
    item.vaultMetadata = metadata;
    if (metadata.sourceUsername.length > 0) {
        item.title = metadata.sourceUsername;
    }
    item.vaultSaveSource = metadata ? (NSInteger)metadata.source : -1;

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    [player configurePlaybackContextWithSource:playbackSource sourceView:sourceView controller:controller];
    [player playItems:@[item] startingAtIndex:0 fromViewController:topMostController()];
}

+ (void)showRemoteImageURL:(NSURL *)url {
    [self showRemoteImageURL:url metadata:nil];
}

+ (void)showRemoteImageURL:(NSURL *)url metadata:(SCIVaultSaveMetadata *)metadata {
    [self showRemoteImageURL:url
                    metadata:metadata
              playbackSource:SCIFullScreenPlaybackSourceUnknown
                  sourceView:nil
                  controller:nil];
}

+ (void)showRemoteImageURL:(NSURL *)url
                  metadata:(SCIVaultSaveMetadata *)metadata
            playbackSource:(SCIFullScreenPlaybackSource)playbackSource
                sourceView:(UIView *)sourceView
                controller:(UIViewController *)controller {
    if (!url) return;

    SCIMediaItem *item = [SCIMediaItem itemWithFileURL:url];
    item.vaultMetadata = metadata;
    if (metadata.sourceUsername.length > 0) {
        item.title = metadata.sourceUsername;
    }
    item.vaultSaveSource = metadata ? (NSInteger)metadata.source : -1;

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    [player configurePlaybackContextWithSource:playbackSource sourceView:sourceView controller:controller];
    UIViewController *presenter = topMostController();
    [player playItems:@[item] startingAtIndex:0 fromViewController:presenter];
}

+ (void)showRemoteImageURL:(NSURL *)url profileUsername:(NSString *)username {
    if (!url) return;
    SCIVaultSaveMetadata *meta = [[SCIVaultSaveMetadata alloc] init];
    meta.source = (int16_t)SCIVaultSourceProfile;
    [SCIVaultOriginController populateProfileMetadata:meta username:username user:nil];
    [self showRemoteImageURL:url metadata:meta];
}

#pragma mark - Playback Context

- (void)configurePlaybackContextWithSource:(SCIFullScreenPlaybackSource)playbackSource
                                sourceView:(UIView *)sourceView
                                controller:(UIViewController *)controller {
    self.underlyingPlaybackController = [[SCIUnderlyingPlaybackController alloc] initWithPlaybackSource:playbackSource
                                                                                              sourceView:sourceView
                                                                                              controller:controller];
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

    [self beginUnderlyingPlaybackSuppression];

    // Over full screen so the black backdrop can fade to reveal the app during dismiss (same idea as vault).
    self.modalPresentationStyle = self.isFromVault ? UIModalPresentationOverFullScreen : UIModalPresentationCurrentContext;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
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
    [self refreshUnderlyingPlaybackSuppression];
    if (![self.underlyingPlaybackController hasSuppressedSessions]) {
        [self scheduleDeferredUnderlyingPlaybackRefreshes];
    }
    [self prepareViewControllerForDisplay:self.pageViewController.viewControllers.firstObject];
    [self prepareAdjacentViewControllersAroundIndex:self.currentIndex];
}

- (void)dealloc {
    [self cancelDeferredUnderlyingPlaybackRefreshes];
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
    [_closeButton setImage:SCIMediaChromeTopIcon(@"xmark", @"xmark") forState:UIControlStateNormal];
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

    if (_isFromVault) {
        _topFavoriteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _topFavoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_topFavoriteButton setImage:SCIMediaChromeTopIcon(@"heart", @"heart") forState:UIControlStateNormal];
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

    _savePhotosButton = SCIMediaChromeBottomButton(@"arrow.down.to.line", @"download", @"Save to Photos");
    [_savePhotosButton addTarget:self action:@selector(saveToPhotos) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_savePhotosButton];

    _shareButton = SCIMediaChromeBottomButton(@"square.and.arrow.up", @"share", @"Share");
    [_shareButton addTarget:self action:@selector(shareMedia) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_shareButton];

    _clipboardButton = SCIMediaChromeBottomButton(@"doc.on.doc", @"copy", @"Copy");
    [_clipboardButton addTarget:self action:@selector(copyMedia) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_clipboardButton];

    if (_isFromVault) {
        _deleteVaultButton = SCIMediaChromeBottomButton(@"trash", @"trash", @"Delete from Vault");
        _deleteVaultButton.tintColor = [UIColor systemRedColor];
        [_deleteVaultButton addTarget:self action:@selector(deleteFromVault) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_deleteVaultButton];

        _vaultMoreButton = SCIMediaChromeBottomButton(@"ellipsis.circle", @"more", @"More");
        _vaultMoreButton.showsMenuAsPrimaryAction = YES;
        [_bottomBar addSubview:_vaultMoreButton];
    } else {
        _saveVaultButton = SCIMediaChromeBottomButton(@"tray.and.arrow.down", @"photo_gallery", @"Save to Vault");
        [_saveVaultButton addTarget:self action:@selector(saveToVault) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_saveVaultButton];
    }

    NSArray<UIView *> *row = _isFromVault
        ? @[_savePhotosButton, _shareButton, _clipboardButton, _deleteVaultButton, _vaultMoreButton]
        : @[_savePhotosButton, _shareButton, _clipboardButton, _saveVaultButton];

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
    [self updateVaultMoreButton];
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
    BOOL isFav = item.vaultFile.isFavorite;
    UIImage *img = isFav
        ? SCIMediaChromeTopIcon(@"heart_filled", @"heart.fill")
        : SCIMediaChromeTopIcon(@"heart", @"heart");

    if (!item.vaultFile) {
        _topFavoriteButton.hidden = YES;
        return;
    }

    _topFavoriteButton.hidden = NO;
    [_topFavoriteButton setImage:img forState:UIControlStateNormal];
    _topFavoriteButton.tintColor = isFav ? [UIColor systemPinkColor] : [UIColor labelColor];
}

- (void)showVaultOpenFailureMessage:(NSString *)title {
    [SCIUtils showToastForDuration:2.0
                             title:title
                          subtitle:@"The original content may no longer exist."
                      iconResource:@"error_filled"
           fallbackSystemImageName:@"exclamationmark.circle.fill"
                              tone:SCIFeedbackPillToneError];
}

- (void)openOriginalPostForCurrentVaultItem {
    SCIVaultFile *file = self.currentItem.vaultFile;
    if (![SCIVaultOriginController openOriginalPostForVaultFile:file]) {
        [self showVaultOpenFailureMessage:@"Unable to open original post"];
    }
}

- (void)openProfileForCurrentVaultItem {
    SCIVaultFile *file = self.currentItem.vaultFile;
    if (![SCIVaultOriginController openProfileForVaultFile:file]) {
        [self showVaultOpenFailureMessage:@"Unable to open profile"];
    }
}

- (UIMenu *)vaultOriginMenuForCurrentItem {
    SCIVaultFile *file = self.currentItem.vaultFile;
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    if (file.hasOpenableOriginalMedia) {
        [actions addObject:[UIAction actionWithTitle:@"Open Original Post"
                                               image:SCIVaultPreviewMenuIcon(@"external_link", @"arrow.up.right.square")
                                          identifier:nil
                                             handler:^(__unused UIAction *action) {
            [weakSelf openOriginalPostForCurrentVaultItem];
        }]];
    }

    if (file.hasOpenableProfile) {
        [actions addObject:[UIAction actionWithTitle:@"Open Profile"
                                               image:SCIVaultPreviewMenuIcon(@"profile", @"person.crop.circle")
                                          identifier:nil
                                             handler:^(__unused UIAction *action) {
            [weakSelf openProfileForCurrentVaultItem];
        }]];
    }

    if (actions.count == 0) {
        UIAction *empty = [UIAction actionWithTitle:@"No origin actions available" image:nil identifier:nil handler:^(__unused UIAction *action) {}];
        empty.attributes = UIMenuElementAttributesDisabled;
        [actions addObject:empty];
    }

    return [UIMenu menuWithTitle:@"" children:actions];
}

- (void)updateVaultMoreButton {
    if (!_vaultMoreButton) return;

    SCIVaultFile *file = self.currentItem.vaultFile;
    BOOL hasActions = file.hasOpenableOriginalMedia || file.hasOpenableProfile;
    _vaultMoreButton.hidden = !file;
    _vaultMoreButton.enabled = hasActions;
    _vaultMoreButton.menu = [self vaultOriginMenuForCurrentItem];
    _vaultMoreButton.alpha = hasActions ? 1.0 : 0.55;
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

- (void)ensureUnderlyingPlaybackController {
    if (!self.underlyingPlaybackController) {
        self.underlyingPlaybackController = [[SCIUnderlyingPlaybackController alloc] initWithPlaybackSource:SCIFullScreenPlaybackSourceUnknown
                                                                                                  sourceView:nil
                                                                                                  controller:nil];
    }
}

- (void)beginUnderlyingPlaybackSuppression {
    [self ensureUnderlyingPlaybackController];
    [self.underlyingPlaybackController beginSuppressionExcludingPreviewView:self.isViewLoaded ? self.view : nil];
}

- (void)cancelDeferredUnderlyingPlaybackRefreshes {
    self.underlyingPlaybackRefreshGeneration++;
}

- (void)refreshUnderlyingPlaybackSuppression {
    [self ensureUnderlyingPlaybackController];
    [self.underlyingPlaybackController refreshAndApplySuppressionExcludingPreviewView:self.isViewLoaded ? self.view : nil];
}

- (void)scheduleDeferredUnderlyingPlaybackRefreshes {
    [self cancelDeferredUnderlyingPlaybackRefreshes];
    NSInteger generation = self.underlyingPlaybackRefreshGeneration;
    __weak typeof(self) weakSelf = self;

    void (^scheduleRefresh)(NSTimeInterval) = ^(NSTimeInterval delay) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.underlyingPlaybackRefreshGeneration != generation || !strongSelf.view.window) {
                return;
            }
            [strongSelf refreshUnderlyingPlaybackSuppression];
        });
    };

    scheduleRefresh(kUnderlyingPlaybackDeferredRefreshShortDelay);
    scheduleRefresh(kUnderlyingPlaybackDeferredRefreshLongDelay);
}

- (void)restoreUnderlyingPlaybackIfNeeded {
    [self cancelDeferredUnderlyingPlaybackRefreshes];
    [self.underlyingPlaybackController restorePlaybackIfNeeded];
}

#pragma mark - Actions

- (void)closeTapped {
    [self cleanupAll];
    [self dismissViewControllerAnimated:YES completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self restoreUnderlyingPlaybackIfNeeded];
        });
        if ([self.delegate respondsToSelector:@selector(fullScreenMediaPlayerDidDismiss)]) {
            [self.delegate fullScreenMediaPlayerDidDismiss];
        }
    }];
}

- (void)favoriteTapped {
    SCIMediaItem *item = [self currentItem];
    if (!item.vaultFile) return;

    item.vaultFile.isFavorite = !item.vaultFile.isFavorite;
    [[SCIVaultCoreDataStack shared] saveContext];
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
    
    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:saveToPhotos showProgress:YES];
    delegate.pendingVaultSaveMetadata = item.vaultMetadata;
    [delegate downloadFileWithURL:url fileExtension:ext hudLabel:nil];
}

- (void)showSaveResult:(BOOL)success error:(NSError *)error {
    UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
    if (success) {
        [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
        [SCIUtils showToastForDuration:2.0
                                 title:@"Saved to Photos"
                              subtitle:nil
                          iconResource:@"circle_check_filled"
               fallbackSystemImageName:@"checkmark.circle.fill"
                                  tone:SCIFeedbackPillToneSuccess];
    } else {
        [haptic notificationOccurred:UINotificationFeedbackTypeError];
        [SCIUtils showToastForDuration:3.0
                                 title:@"Failed to save"
                              subtitle:error.localizedDescription
                          iconResource:@"error_filled"
               fallbackSystemImageName:@"exclamationmark.circle.fill"
                                  tone:SCIFeedbackPillToneError];
    }
}

- (void)saveToVault {
    NSURL *targetURL = [self currentFileURL];
    SCIMediaItem *item = [self currentItem];

    if (!targetURL && !item.image) {
        [SCIUtils showToastForDuration:2.0
                                 title:@"No media to save"
                              subtitle:nil
                          iconResource:@"media"
               fallbackSystemImageName:@"photo.on.rectangle"
                                  tone:SCIFeedbackPillToneError];
        return;
    }

    SCIVaultMediaType vaultType = (item.mediaType == SCIMediaItemTypeVideo && targetURL) ? SCIVaultMediaTypeVideo : SCIVaultMediaTypeImage;

    if (targetURL.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:targetURL.path]) {
        [self vaultSaveLocalFile:targetURL mediaType:vaultType];
        return;
    } else if (!targetURL && item.image) {
        NSData *jpegData = UIImageJPEGRepresentation(item.image, 0.95);
        if (jpegData) {
            NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"jpg"]];
            NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
            [jpegData writeToURL:tempURL atomically:YES];
            [self vaultSaveLocalFile:tempURL mediaType:SCIVaultMediaTypeImage];
            [[NSFileManager defaultManager] removeItemAtURL:tempURL error:nil];
            return;
        }
    }

    NSString *ext = targetURL.pathExtension;
    if (ext.length == 0) ext = vaultType == SCIVaultMediaTypeVideo ? @"mp4" : @"jpg";

    SCIVaultSaveMetadata *meta = item.vaultMetadata;
    if (!meta && (item.title.length > 0 || item.vaultSaveSource >= 0)) {
        meta = [[SCIVaultSaveMetadata alloc] init];
        if (item.title.length) {
            meta.sourceUsername = item.title;
        }
        if (item.vaultSaveSource >= 0) {
            meta.source = (int16_t)item.vaultSaveSource;
        } else {
            meta.source = (int16_t)SCIVaultSourceOther;
        }
    }
    
    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:saveToVault showProgress:YES];
    delegate.pendingVaultSaveMetadata = meta;
    [delegate downloadFileWithURL:targetURL fileExtension:ext hudLabel:nil];
}

- (void)vaultSaveLocalFile:(NSURL *)localURL mediaType:(SCIVaultMediaType)vaultType {
    NSError *error;
    SCIMediaItem *item = [self currentItem];
    SCIVaultSaveMetadata *meta = item.vaultMetadata;
    if (!meta && (item.title.length > 0 || item.vaultSaveSource >= 0)) {
        meta = [[SCIVaultSaveMetadata alloc] init];
        if (item.title.length) {
            meta.sourceUsername = item.title;
        }
        if (item.vaultSaveSource >= 0) {
            meta.source = (int16_t)item.vaultSaveSource;
        } else {
            meta.source = (int16_t)SCIVaultSourceOther;
        }
    }
    SCIVaultFile *file = [SCIVaultFile saveFileToVault:localURL
                                                source:SCIVaultSourceOther
                                             mediaType:vaultType
                                            folderPath:nil
                                              metadata:meta
                                                 error:&error];

    UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
    if (file) {
        [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
        [SCIUtils showToastForDuration:2.0
                                 title:@"Saved to Vault"
                              subtitle:nil
                          iconResource:@"circle_check_filled"
               fallbackSystemImageName:@"checkmark.circle.fill"
                                  tone:SCIFeedbackPillToneSuccess];
    } else {
        [haptic notificationOccurred:UINotificationFeedbackTypeError];
        NSString *msg = error.localizedDescription.length ? error.localizedDescription : @"Failed to save";
        [SCIUtils showToastForDuration:3.0
                                 title:@"Failed to save"
                              subtitle:msg
                          iconResource:@"error_filled"
               fallbackSystemImageName:@"exclamationmark.circle.fill"
                                  tone:SCIFeedbackPillToneError];
    }
}

- (void)shareMedia {
    NSURL *url = [self currentFileURL];
    SCIMediaItem *item = [self currentItem];
    if (!url && !item.image) return;

    if (url.isFileURL || (!url && item.image)) {
        id activityItem = url.isFileURL ? url : item.image;
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
    
    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:share showProgress:YES];
    delegate.pendingVaultSaveMetadata = item.vaultMetadata;
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
            UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
            [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
            [SCIUtils showToastForDuration:1.5
                                     title:@"Copied photo to clipboard"
                                  subtitle:nil
                              iconResource:@"copy_filled"
                   fallbackSystemImageName:@"doc.on.doc.fill"
                                      tone:SCIFeedbackPillToneSuccess];
        }
    } else {
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            [[UIPasteboard generalPasteboard] setData:data forPasteboardType:@"public.mpeg-4"];
            UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
            [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
            [SCIUtils showToastForDuration:1.5
                                     title:@"Copied video to clipboard"
                                  subtitle:nil
                              iconResource:@"copy_filled"
                   fallbackSystemImageName:@"doc.on.doc.fill"
                                      tone:SCIFeedbackPillToneSuccess];
        }
    }
}

- (void)deleteFromVault {
    SCIMediaItem *item = [self currentItem];
    if (!item.vaultFile) return;

    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete from Vault?"
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
    if (!item.vaultFile) return;

    NSInteger deletedIndex = _currentIndex;
    NSError *err;
    [item.vaultFile removeWithError:&err];
    if (err) {
        [SCIUtils showToastForDuration:2.0
                                 title:@"Failed to delete"
                              subtitle:err.localizedDescription
                          iconResource:@"error_filled"
               fallbackSystemImageName:@"exclamationmark.circle.fill"
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

    CGFloat dy = ty;
    CGFloat absDy = fabs(dy);
    CGFloat resistedDy = dy * 0.82;
    CGFloat progress = MIN(1.0, absDy / kDismissProgressDenominator);
    CGFloat scale = MAX(kDismissMinScale, 1.0 - progress * (1.0 - kDismissMinScale));

    switch (pan.state) {
        case UIGestureRecognizerStateChanged: {
            CGAffineTransform translate = CGAffineTransformMakeTranslation(0, resistedDy);
            _pageViewController.view.transform = CGAffineTransformScale(translate, scale, scale);
            self.presentationBackdropView.alpha = MAX(0.0, 1.0 - progress * 1.1);
            CGFloat fade = (_isToolbarVisible ? 1.0 : 0.0) * (1.0 - progress * 1.2);
            _topToolbar.alpha = MAX(0.0, fade);
            if (_bottomBar) _bottomBar.alpha = MAX(0.0, fade);
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            BOOL commit = progress > kDismissProgressCommit || fabs(velocity.y) > kDismissVelocityCommit;
            if (commit) {
                CGFloat direction = dy >= 0.0 ? 1.0 : -1.0;
                CGFloat vy = MAX(fabs(velocity.y), 400.0);
                CGFloat extra = self.view.bounds.size.height - absDy + 80.0;
                CGFloat duration = MIN(kDismissFinishDuration, extra / vy);
                duration = MAX(0.18, duration);

                [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^{
                    CGAffineTransform translate = CGAffineTransformMakeTranslation(0, direction * (self.view.bounds.size.height + 60.0));
                    self->_pageViewController.view.transform = CGAffineTransformScale(translate, kDismissMinScale, kDismissMinScale);
                    self.presentationBackdropView.alpha = 0.0;
                    self->_topToolbar.alpha = 0.0;
                    if (self->_bottomBar) self->_bottomBar.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [self cleanupAll];
                    [self dismissViewControllerAnimated:NO completion:^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self restoreUnderlyingPlaybackIfNeeded];
                        });
                        if ([self.delegate respondsToSelector:@selector(fullScreenMediaPlayerDidDismiss)]) {
                            [self.delegate fullScreenMediaPlayerDidDismiss];
                        }
                    }];
                }];
            } else {
                CGFloat springVel = (CGFloat)fmin(fmax(-velocity.y / 1400.0, -6.0), 6.0);
                [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:kDismissCancelSpringDamping initialSpringVelocity:springVel options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                    self->_pageViewController.view.transform = CGAffineTransformIdentity;
                    self.presentationBackdropView.alpha = 1.0;
                    CGFloat alpha = self->_isToolbarVisible ? 1.0 : 0.0;
                    self->_topToolbar.alpha = alpha;
                    if (self->_bottomBar) self->_bottomBar.alpha = alpha;
                } completion:^(BOOL finished) {
                    UIViewController *currentVC = self->_pageViewController.viewControllers.firstObject;
                    if ([currentVC isKindOfClass:[SCIFullScreenImageViewController class]]) {
                        [(SCIFullScreenImageViewController *)currentVC resetZoomIfNeeded];
                    }
                }];
            }
            _dismissPanDecided = NO;
            _pageScrollView.scrollEnabled = YES;
            break;
        }
        case UIGestureRecognizerStateFailed: {
            if (_dismissPanDecided && _dismissPanIsVertical) {
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

#pragma mark - Cleanup

- (void)cleanupAll {
    [self cancelDeferredUnderlyingPlaybackRefreshes];

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
