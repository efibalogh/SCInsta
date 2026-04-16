#import "SCIFullScreenMediaPlayer.h"
#import "SCIMediaItem.h"
#import "SCIFullScreenImageViewController.h"
#import "SCIFullScreenVideoViewController.h"
#import "../InstagramHeaders.h"
#import "../Utils.h"
#import "../Vault/SCIVaultFile.h"
#import "../Vault/SCIVaultSaveMetadata.h"
#import "../Vault/SCIVaultCoreDataStack.h"
#import <Photos/Photos.h>

static CGFloat const kTopBarContentHeight = 44.0;
static CGFloat const kBottomBarHeight = 44.0;

static CGFloat const kDismissAxisLockSlop = 14.0;
static CGFloat const kDismissProgressDenominator = 320.0;
static CGFloat const kDismissProgressCommit = 0.28;
static CGFloat const kDismissVelocityCommit = 650.0;
static CGFloat const kDismissFinishDuration = 0.32;
static CGFloat const kDismissCancelSpringDamping = 0.82;

@interface SCIFullScreenMediaPlayer () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate, SCIFullScreenContentDelegate>

@property (nonatomic, strong) NSArray<SCIMediaItem *> *items;
@property (nonatomic, assign) NSInteger currentIndex;

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

@property (nonatomic, assign) BOOL isToolbarVisible;
@property (nonatomic, assign) BOOL isSingleItemMode;

@property (nonatomic, assign) BOOL dismissPanDecided;
@property (nonatomic, assign) BOOL dismissPanIsVertical;

@end

@implementation SCIFullScreenMediaPlayer

#pragma mark - Convenience Factories

+ (void)showFileURL:(NSURL *)fileURL {
    [self showFileURL:fileURL fromVault:NO];
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
        [SCIUtils showToastForDuration:2.0 title:@"No files found"];
        return;
    }

    NSInteger adjustedIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    player.isFromVault = YES;
    [player playItems:items startingAtIndex:adjustedIndex fromViewController:presenter];
}

+ (void)showPhotoURLs:(NSArray<NSURL *> *)urls initialIndex:(NSInteger)index {
    if (urls.count == 0) return;

    NSMutableArray<SCIMediaItem *> *items = [NSMutableArray arrayWithCapacity:urls.count];
    for (NSURL *url in urls) {
        [items addObject:[SCIMediaItem itemWithFileURL:url]];
    }

    NSInteger adjustedIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    UIViewController *presenter = topMostController();
    [player playItems:items startingAtIndex:adjustedIndex fromViewController:presenter];
}

+ (void)showImage:(UIImage *)image {
    if (!image) return;
    SCIMediaItem *item = [SCIMediaItem itemWithImage:image];
    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    [player playItems:@[item] startingAtIndex:0 fromViewController:topMostController()];
}

+ (void)showRemoteImageURL:(NSURL *)url {
    if (!url) return;

    SCIMediaItem *item = [SCIMediaItem itemWithFileURL:url];
    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    UIViewController *presenter = topMostController();
    [player playItems:@[item] startingAtIndex:0 fromViewController:presenter];
}

+ (void)showRemoteImageURL:(NSURL *)url profileUsername:(NSString *)username {
    if (!url) return;

    SCIMediaItem *item = [SCIMediaItem itemWithFileURL:url];
    if (username.length) {
        item.title = username;
    }
    item.vaultSaveSource = (NSInteger)SCIVaultSourceProfile;

    SCIFullScreenMediaPlayer *player = [[SCIFullScreenMediaPlayer alloc] init];
    UIViewController *presenter = topMostController();
    [player playItems:@[item] startingAtIndex:0 fromViewController:presenter];
}

#pragma mark - Present

- (void)playItems:(NSArray<SCIMediaItem *> *)items
  startingAtIndex:(NSInteger)index
fromViewController:(UIViewController *)presenter {
    _items = [items copy];
    _currentIndex = MAX(0, MIN(index, (NSInteger)items.count - 1));
    _isSingleItemMode = (items.count <= 1);
    _isToolbarVisible = YES;

    self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:self animated:YES completion:nil];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    [self setupTopToolbar];
    [self setupBottomBar];
    [self setupPageViewController];
    [self setupDismissGesture];
    [self updateUI];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

#pragma mark - Top Toolbar

- (void)setupTopToolbar {
    _topToolbar = [[UIView alloc] initWithFrame:CGRectZero];
    _topToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_topToolbar];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [_topToolbar insertSubview:blurView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:_topToolbar.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:_topToolbar.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:_topToolbar.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:_topToolbar.trailingAnchor],
    ]];

    UIView *bottomBorder = [[UIView alloc] initWithFrame:CGRectZero];
    bottomBorder.translatesAutoresizingMaskIntoConstraints = NO;
    bottomBorder.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    [_topToolbar addSubview:bottomBorder];
    [NSLayoutConstraint activateConstraints:@[
        [bottomBorder.bottomAnchor constraintEqualToAnchor:_topToolbar.bottomAnchor],
        [bottomBorder.leadingAnchor constraintEqualToAnchor:_topToolbar.leadingAnchor],
        [bottomBorder.trailingAnchor constraintEqualToAnchor:_topToolbar.trailingAnchor],
        [bottomBorder.heightAnchor constraintEqualToConstant:1.0 / [UIScreen mainScreen].scale],
    ]];

    UIImageSymbolConfiguration *sym = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeButton setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:sym] forState:UIControlStateNormal];
    _closeButton.tintColor = [UIColor whiteColor];
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [_topToolbar addSubview:_closeButton];

    _counterLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _counterLabel.textColor = [UIColor whiteColor];
    _counterLabel.font = [UIFont monospacedDigitSystemFontOfSize:16.0 weight:UIFontWeightMedium];
    _counterLabel.textAlignment = NSTextAlignmentCenter;
    [_topToolbar addSubview:_counterLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_topToolbar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_topToolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_topToolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_topToolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:kTopBarContentHeight],

        [_closeButton.leadingAnchor constraintEqualToAnchor:_topToolbar.leadingAnchor constant:16],
        [_closeButton.bottomAnchor constraintEqualToAnchor:_topToolbar.bottomAnchor],
        [_closeButton.heightAnchor constraintEqualToConstant:kTopBarContentHeight],
        [_closeButton.widthAnchor constraintEqualToConstant:44],

        [_counterLabel.centerXAnchor constraintEqualToAnchor:_topToolbar.centerXAnchor],
        [_counterLabel.centerYAnchor constraintEqualToAnchor:_closeButton.centerYAnchor],
    ]];

    if (_isFromVault) {
        _topFavoriteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _topFavoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
        _topFavoriteButton.tintColor = [UIColor whiteColor];
        [_topFavoriteButton addTarget:self action:@selector(favoriteTapped) forControlEvents:UIControlEventTouchUpInside];
        [_topToolbar addSubview:_topFavoriteButton];

        [NSLayoutConstraint activateConstraints:@[
            [_topFavoriteButton.trailingAnchor constraintEqualToAnchor:_topToolbar.trailingAnchor constant:-16],
            [_topFavoriteButton.centerYAnchor constraintEqualToAnchor:_closeButton.centerYAnchor],
            [_topFavoriteButton.widthAnchor constraintEqualToConstant:44],
            [_topFavoriteButton.heightAnchor constraintEqualToConstant:kTopBarContentHeight],
        ]];
    }
}

#pragma mark - Bottom Bar

- (void)setupBottomBar {
    _bottomBar = [[UIView alloc] initWithFrame:CGRectZero];
    _bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_bottomBar];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [_bottomBar insertSubview:blurView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:_bottomBar.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:_bottomBar.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:_bottomBar.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:_bottomBar.trailingAnchor],
    ]];

    UIView *topBorder = [[UIView alloc] initWithFrame:CGRectZero];
    topBorder.translatesAutoresizingMaskIntoConstraints = NO;
    topBorder.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    [_bottomBar addSubview:topBorder];
    [NSLayoutConstraint activateConstraints:@[
        [topBorder.topAnchor constraintEqualToAnchor:_bottomBar.topAnchor],
        [topBorder.leadingAnchor constraintEqualToAnchor:_bottomBar.leadingAnchor],
        [topBorder.trailingAnchor constraintEqualToAnchor:_bottomBar.trailingAnchor],
        [topBorder.heightAnchor constraintEqualToConstant:1.0 / [UIScreen mainScreen].scale],
    ]];

    UIImageSymbolConfiguration *sym = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular];

    _savePhotosButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _savePhotosButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_savePhotosButton setImage:[UIImage systemImageNamed:@"arrow.down" withConfiguration:sym] forState:UIControlStateNormal];
    _savePhotosButton.tintColor = [UIColor whiteColor];
    [_savePhotosButton addTarget:self action:@selector(saveToPhotos) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_savePhotosButton];

    _shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _shareButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_shareButton setImage:[UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:sym] forState:UIControlStateNormal];
    _shareButton.tintColor = [UIColor whiteColor];
    [_shareButton addTarget:self action:@selector(shareMedia) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_shareButton];

    _clipboardButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _clipboardButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_clipboardButton setImage:[UIImage systemImageNamed:@"doc.on.doc" withConfiguration:sym] forState:UIControlStateNormal];
    _clipboardButton.tintColor = [UIColor whiteColor];
    [_clipboardButton addTarget:self action:@selector(copyMedia) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_clipboardButton];

    if (_isFromVault) {
        _deleteVaultButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _deleteVaultButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_deleteVaultButton setImage:[UIImage systemImageNamed:@"trash" withConfiguration:sym] forState:UIControlStateNormal];
        _deleteVaultButton.tintColor = [UIColor systemRedColor];
        [_deleteVaultButton addTarget:self action:@selector(deleteFromVault) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_deleteVaultButton];
    } else {
        _saveVaultButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _saveVaultButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_saveVaultButton setImage:[UIImage systemImageNamed:@"tray.and.arrow.down" withConfiguration:sym] forState:UIControlStateNormal];
        _saveVaultButton.tintColor = [UIColor whiteColor];
        [_saveVaultButton addTarget:self action:@selector(saveToVault) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_saveVaultButton];
    }

    NSArray<UIView *> *row = _isFromVault
        ? @[_savePhotosButton, _shareButton, _clipboardButton, _deleteVaultButton]
        : @[_savePhotosButton, _shareButton, _clipboardButton, _saveVaultButton];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:row];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.alignment = UIStackViewAlignmentCenter;
    [_bottomBar addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:_bottomBar.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:_bottomBar.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:_bottomBar.trailingAnchor],
        [stack.heightAnchor constraintEqualToConstant:kBottomBarHeight],
    ]];

    for (UIView *v in row) {
        [v.heightAnchor constraintEqualToConstant:kBottomBarHeight].active = YES;
    }

    [NSLayoutConstraint activateConstraints:@[
        [_bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_bottomBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_bottomBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-kBottomBarHeight],
    ]];
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
    [self.view insertSubview:_pageViewController.view atIndex:0];
    [_pageViewController didMoveToParentViewController:self];

    [NSLayoutConstraint activateConstraints:@[
        [_pageViewController.view.topAnchor constraintEqualToAnchor:_topToolbar.bottomAnchor],
        [_pageViewController.view.bottomAnchor constraintEqualToAnchor:_bottomBar.topAnchor],
        [_pageViewController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_pageViewController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    UIViewController *initialVC = [self viewControllerForIndex:_currentIndex];
    if (initialVC) {
        [_pageViewController setViewControllers:@[initialVC]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:NO
                                     completion:nil];
    }
}

- (UIViewController *)viewControllerForIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_items.count) return nil;

    SCIMediaItem *item = _items[index];

    if (item.mediaType == SCIMediaItemTypeVideo) {
        SCIFullScreenVideoViewController *vc = [[SCIFullScreenVideoViewController alloc] initWithMediaItem:item];
        vc.delegate = self;
        [vc preloadContent];
        return vc;
    }

    SCIFullScreenImageViewController *vc = [[SCIFullScreenImageViewController alloc] initWithMediaItem:item];
    vc.delegate = self;
    return vc;
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
}

- (void)updateCounter {
    if (_isSingleItemMode) {
        _counterLabel.text = @"";
        return;
    }
    _counterLabel.text = [NSString stringWithFormat:@"%ld of %lu",
                          (long)_currentIndex + 1,
                          (unsigned long)_items.count];
}

- (void)updateFavoriteButton {
    if (!_topFavoriteButton) return;

    SCIMediaItem *item = [self currentItem];
    BOOL isFav = item.vaultFile.isFavorite;
    UIImageSymbolConfiguration *sym = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular];
    NSString *imageName = isFav ? @"heart.fill" : @"heart";
    UIImage *img = [UIImage systemImageNamed:imageName withConfiguration:sym];

    if (!item.vaultFile) {
        _topFavoriteButton.hidden = YES;
        return;
    }

    _topFavoriteButton.hidden = NO;
    [_topFavoriteButton setImage:img forState:UIControlStateNormal];
    _topFavoriteButton.tintColor = isFav ? [UIColor systemPinkColor] : [UIColor whiteColor];
}

#pragma mark - Toolbar Toggle

- (void)toggleToolbar {
    UIViewController *currentVC = _pageViewController.viewControllers.firstObject;
    if ([currentVC isKindOfClass:[SCIFullScreenVideoViewController class]]) return;

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
    return [self currentItem].fileURL;
}

#pragma mark - Actions

- (void)closeTapped {
    [self cleanupAll];
    [self dismissViewControllerAnimated:YES completion:^{
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
    if (!url) return;

    SCIMediaItem *item = [self currentItem];

    if (item.mediaType == SCIMediaItemTypeImage) {
        NSData *imageData = [NSData dataWithContentsOfURL:url];
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
}

- (void)showSaveResult:(BOOL)success error:(NSError *)error {
    UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
    if (success) {
        [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
        [SCIUtils showToastForDuration:2.0 title:@"Saved to Photos"];
    } else {
        [haptic notificationOccurred:UINotificationFeedbackTypeError];
        [SCIUtils showToastForDuration:3.0 title:@"Failed to save" subtitle:error.localizedDescription];
    }
}

- (void)saveToVault {
    NSURL *targetURL = [self currentFileURL];
    if (!targetURL) {
        [SCIUtils showToastForDuration:2.0 title:@"No media to save"];
        return;
    }

    SCIMediaItem *item = [self currentItem];
    SCIVaultMediaType vaultType = (item.mediaType == SCIMediaItemTypeVideo) ? SCIVaultMediaTypeVideo : SCIVaultMediaTypeImage;

    if (targetURL.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:targetURL.path]) {
        [self vaultSaveLocalFile:targetURL mediaType:vaultType];
        return;
    }

    [SCIUtils showToastForDuration:1.0 title:@"Downloading..."];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:targetURL];
        if (!data.length) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SCIUtils showToastForDuration:2.0 title:@"Download failed"];
            });
            return;
        }

        NSString *ext = targetURL.pathExtension.length > 0 ? targetURL.pathExtension : (vaultType == SCIVaultMediaTypeVideo ? @"mp4" : @"jpg");
        NSString *tmpName = [NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, ext];
        NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpName];
        [data writeToFile:tmpPath atomically:YES];

        NSURL *localURL = [NSURL fileURLWithPath:tmpPath];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf vaultSaveLocalFile:localURL mediaType:vaultType];
            [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
        });
    });
}

- (void)vaultSaveLocalFile:(NSURL *)localURL mediaType:(SCIVaultMediaType)vaultType {
    NSError *error;
    SCIMediaItem *item = [self currentItem];
    SCIVaultSaveMetadata *meta = nil;
    if (item.title.length > 0 || item.vaultSaveSource >= 0) {
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
        [SCIUtils showToastForDuration:2.0 title:@"Saved to Vault"];
    } else {
        [haptic notificationOccurred:UINotificationFeedbackTypeError];
        NSString *msg = error.localizedDescription.length ? error.localizedDescription : @"Failed to save";
        [SCIUtils showToastForDuration:3.0 title:@"Failed to save" subtitle:msg];
    }
}

- (void)shareMedia {
    NSURL *url = [self currentFileURL];
    if (!url) return;

    UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad && _shareButton) {
        acVC.popoverPresentationController.sourceView = _shareButton;
        acVC.popoverPresentationController.sourceRect = _shareButton.bounds;
    }
    [self presentViewController:acVC animated:YES completion:nil];
}

- (void)copyMedia {
    SCIMediaItem *item = [self currentItem];
    NSURL *url = [self currentFileURL];
    if (!url) return;

    if (item.mediaType == SCIMediaItemTypeImage) {
        NSData *imageData = [NSData dataWithContentsOfURL:url];
        UIImage *image = item.image ?: [UIImage imageWithData:imageData];
        if (image) {
            [[UIPasteboard generalPasteboard] setImage:image];
            UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
            [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
            [SCIUtils showToastForDuration:1.5 title:@"Copied"];
        }
    } else {
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            [[UIPasteboard generalPasteboard] setData:data forPasteboardType:@"public.mpeg-4"];
            UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
            [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
            [SCIUtils showToastForDuration:1.5 title:@"Copied"];
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
        [SCIUtils showToastForDuration:2.0 title:@"Failed to delete" subtitle:err.localizedDescription];
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

    _currentIndex = MIN(deletedIndex, (NSInteger)_items.count - 1);
    UIViewController *newVC = [self viewControllerForIndex:_currentIndex];
    if (newVC) {
        [_pageViewController setViewControllers:@[newVC]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:YES
                                     completion:nil];
    }
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
    }

    if (!_dismissPanIsVertical) {
        if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
            [self resetDismissInteractiveStateAnimated:NO];
        }
        return;
    }

    CGFloat dy = MAX(0.0, ty);
    CGFloat progress = MIN(1.0, dy / kDismissProgressDenominator);

    switch (pan.state) {
        case UIGestureRecognizerStateChanged: {
            _pageViewController.view.transform = CGAffineTransformMakeTranslation(0, dy);
            self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:1.0 - progress * 0.92];
            CGFloat fade = (_isToolbarVisible ? 1.0 : 0.0) * (1.0 - progress * 1.35);
            _topToolbar.alpha = MAX(0.0, fade);
            if (_bottomBar) _bottomBar.alpha = MAX(0.0, fade);
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            BOOL commit = progress > kDismissProgressCommit || velocity.y > kDismissVelocityCommit;
            if (commit) {
                CGFloat vy = MAX(velocity.y, 400.0);
                CGFloat extra = self.view.bounds.size.height - dy + 80.0;
                CGFloat duration = MIN(kDismissFinishDuration, extra / vy);
                duration = MAX(0.22, duration);

                [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^{
                    self->_pageViewController.view.transform = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height + 60.0);
                    self.view.backgroundColor = [UIColor clearColor];
                    self->_topToolbar.alpha = 0.0;
                    if (self->_bottomBar) self->_bottomBar.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [self cleanupAll];
                    [self dismissViewControllerAnimated:NO completion:^{
                        if ([self.delegate respondsToSelector:@selector(fullScreenMediaPlayerDidDismiss)]) {
                            [self.delegate fullScreenMediaPlayerDidDismiss];
                        }
                    }];
                }];
            } else {
                CGFloat springVel = (CGFloat)fmin(fmax(-velocity.y / 1200.0, -8.0), 8.0);
                [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:kDismissCancelSpringDamping initialSpringVelocity:springVel options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                    self->_pageViewController.view.transform = CGAffineTransformIdentity;
                    self.view.backgroundColor = [UIColor blackColor];
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
            break;
        }
        case UIGestureRecognizerStateFailed: {
            if (_dismissPanDecided && _dismissPanIsVertical) {
                [self resetDismissInteractiveStateAnimated:YES];
            }
            _dismissPanDecided = NO;
            _dismissPanIsVertical = NO;
            break;
        }
        default:
            break;
    }
}

- (void)resetDismissInteractiveStateAnimated:(BOOL)animated {
    _dismissPanDecided = NO;
    _dismissPanIsVertical = NO;
    void (^animations)(void) = ^{
        self->_pageViewController.view.transform = CGAffineTransformIdentity;
        self.view.backgroundColor = [UIColor blackColor];
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
    UIViewController *currentVC = _pageViewController.viewControllers.firstObject;
    if ([currentVC respondsToSelector:@selector(cleanup)]) {
        [(id)currentVC cleanup];
    }
    [[AVAudioSession sharedInstance] setActive:NO
                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                         error:nil];
}

@end
