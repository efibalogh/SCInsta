#import "SCIMediaPreviewController.h"
#import "../InstagramHeaders.h"
#import "../Utils.h"
#import "../Vault/SCIVaultFile.h"
#import <Photos/Photos.h>
#import <dlfcn.h>

static CGFloat const kActionBarHeight   = 56.0;
static CGFloat const kActionBarPadding  = 16.0;
static CGFloat const kCloseButtonSize   = 36.0;
static CGFloat const kMaxZoom           = 5.0;
static CGFloat const kMinZoom           = 1.0;

@interface SCIInlinePhotoCarouselCell : UICollectionViewCell <UIScrollViewDelegate>

- (void)configureWithURL:(NSURL *)url cache:(NSCache<NSString *, UIImage *> *)cache;
- (BOOL)isZoomedIn;

@property (nonatomic, copy) void (^zoomStateChanged)(BOOL zoomed);

@end

@interface SCIInlinePhotoCarouselCell ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) NSString *currentURLKey;

@end

@implementation SCIInlinePhotoCarouselCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = [UIColor clearColor];

        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        _scrollView.delegate = self;
        _scrollView.minimumZoomScale = kMinZoom;
        _scrollView.maximumZoomScale = kMaxZoom;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.bouncesZoom = YES;
        _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _scrollView.scrollEnabled = NO;
        [self.contentView addSubview:_scrollView];

        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.clipsToBounds = YES;
        [_scrollView addSubview:_imageView];

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        _spinner.translatesAutoresizingMaskIntoConstraints = NO;
        _spinner.color = [UIColor whiteColor];
        [self.contentView addSubview:_spinner];

        [NSLayoutConstraint activateConstraints:@[
            [_scrollView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [_scrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],

            [_imageView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor],
            [_imageView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor],
            [_imageView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor],
            [_imageView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor],

            [_imageView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor],
            [_imageView.heightAnchor constraintEqualToAnchor:_scrollView.heightAnchor],

            [_spinner.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            [_spinner.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];

        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        [_scrollView addGestureRecognizer:doubleTap];
    }

    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];

    self.currentURLKey = nil;
    self.imageView.image = nil;
    [self.scrollView setZoomScale:kMinZoom animated:NO];
    self.scrollView.scrollEnabled = NO;
    if (self.zoomStateChanged) {
        self.zoomStateChanged(NO);
    }
    [self.spinner stopAnimating];
}

- (void)configureWithURL:(NSURL *)url cache:(NSCache<NSString *,UIImage *> *)cache {
    NSString *key = url.absoluteString ?: @"";
    self.currentURLKey = key;

    if (key.length == 0) {
        self.imageView.image = nil;
        [self.spinner stopAnimating];
        return;
    }

    UIImage *cached = [cache objectForKey:key];
    if (cached) {
        [self.scrollView setZoomScale:kMinZoom animated:NO];
        self.scrollView.scrollEnabled = NO;
        self.imageView.image = cached;
        [self.spinner stopAnimating];
        if (self.zoomStateChanged) {
            self.zoomStateChanged(NO);
        }
        return;
    }

    [self.scrollView setZoomScale:kMinZoom animated:NO];
    self.scrollView.scrollEnabled = NO;
    self.imageView.image = nil;
    [self.spinner startAnimating];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        UIImage *image = data ? [UIImage imageWithData:data] : nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!weakSelf || ![weakSelf.currentURLKey isEqualToString:key]) {
                return;
            }

            [weakSelf.spinner stopAnimating];
            weakSelf.imageView.image = image;
            [weakSelf.scrollView setZoomScale:kMinZoom animated:NO];
            weakSelf.scrollView.scrollEnabled = NO;
            if (weakSelf.zoomStateChanged) {
                weakSelf.zoomStateChanged(NO);
            }

            if (image) {
                [cache setObject:image forKey:key];
            }
        });
    });
}

- (BOOL)isZoomedIn {
    return self.scrollView.zoomScale > (kMinZoom + 0.01);
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    BOOL zoomed = [self isZoomedIn];
    self.scrollView.scrollEnabled = zoomed;
    if (self.zoomStateChanged) {
        self.zoomStateChanged(zoomed);
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    if ([self isZoomedIn]) {
        [self.scrollView setZoomScale:kMinZoom animated:YES];
        return;
    }

    CGPoint point = [recognizer locationInView:self.imageView];
    CGFloat newZoom = kMaxZoom / 2.0;
    CGSize scrollSize = self.scrollView.bounds.size;
    CGFloat w = scrollSize.width / newZoom;
    CGFloat h = scrollSize.height / newZoom;
    CGRect zoomRect = CGRectMake(point.x - w / 2.0, point.y - h / 2.0, w, h);
    [self.scrollView zoomToRect:zoomRect animated:YES];
}

@end

@interface SCIMediaPreviewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate, UICollectionViewDataSource, UICollectionViewDelegate>

// Common
@property (nonatomic, strong) NSURL        *fileURL;
@property (nonatomic, assign) SCIMediaType  mediaType;
@property (nonatomic, strong) UIVisualEffectView *backgroundBlur;

// Photo
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView  *imageView;
@property (nonatomic, copy) NSArray<NSURL *> *photoURLs;
@property (nonatomic, strong) UICollectionView *photoCollectionView;
@property (nonatomic, strong) UILabel *photoCounterLabel;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *photoImageCache;
@property (nonatomic, assign) NSInteger currentPhotoIndex;
@property (nonatomic, assign) BOOL didApplyInitialPhotoIndex;
@property (nonatomic, assign) BOOL isCarouselItemZoomed;

// Video
@property (nonatomic, strong) AVPlayer           *player;
@property (nonatomic, strong) AVPlayerLayer      *playerLayer;
@property (nonatomic, strong) UIView             *playerContainerView;
@property (nonatomic, strong) UIButton           *playPauseButton;
@property (nonatomic, strong) UISlider           *scrubber;
@property (nonatomic, strong) UILabel            *timeLabel;
@property (nonatomic, strong) UIView             *videoControlsBar;
@property (nonatomic, strong) id                  timeObserver;

// UI
@property (nonatomic, strong) UIButton           *closeButton;
@property (nonatomic, strong) UIView             *actionBar;
@property (nonatomic, strong) UIVisualEffectView *actionBarBlur;

// Dismiss gesture
@property (nonatomic, assign) CGPoint  panStartCenter;
@property (nonatomic, assign) BOOL     isDismissing;

@end

@implementation SCIMediaPreviewController

#pragma mark - Factory

+ (instancetype)previewWithFileURL:(NSURL *)fileURL {
    NSString *ext = fileURL.pathExtension.lowercaseString;
    SCIMediaType type = SCIMediaTypePhoto;
    if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] ||
        [ext isEqualToString:@"m4v"] || [ext isEqualToString:@"avi"] ||
        [ext isEqualToString:@"webm"]) {
        type = SCIMediaTypeVideo;
    }
    return [[SCIMediaPreviewController alloc] initWithFileURL:fileURL mediaType:type];
}

+ (instancetype)previewWithPhotoURLs:(NSArray<NSURL *> *)photoURLs initialIndex:(NSInteger)initialIndex {
    if (photoURLs.count == 0) {
        return nil;
    }

    NSInteger boundedIndex = MAX(0, MIN(initialIndex, (NSInteger)photoURLs.count - 1));
    SCIMediaPreviewController *controller = [[SCIMediaPreviewController alloc] initWithFileURL:photoURLs[boundedIndex] mediaType:SCIMediaTypePhoto];
    controller.photoURLs = [photoURLs copy];
    controller.currentPhotoIndex = boundedIndex;
    controller.photoImageCache = [[NSCache alloc] init];
    return controller;
}

+ (void)showPreviewForFileURL:(NSURL *)fileURL {
    SCIMediaPreviewController *vc = [SCIMediaPreviewController previewWithFileURL:fileURL];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [topMostController() presentViewController:vc animated:YES completion:nil];
}

+ (void)showPreviewForPhotoURLs:(NSArray<NSURL *> *)photoURLs initialIndex:(NSInteger)initialIndex {
    SCIMediaPreviewController *vc = [SCIMediaPreviewController previewWithPhotoURLs:photoURLs initialIndex:initialIndex];
    if (!vc) {
        return;
    }

    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [topMostController() presentViewController:vc animated:YES completion:nil];
}

#pragma mark - Init

- (instancetype)initWithFileURL:(NSURL *)fileURL mediaType:(SCIMediaType)type {
    self = [super init];
    if (self) {
        _fileURL = fileURL;
        _mediaType = type;
        _currentPhotoIndex = 0;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor clearColor];

    [self setupBackground];
    [self setupCloseButton];

    if (self.mediaType == SCIMediaTypePhoto && self.photoURLs.count > 1) {
        [self setupPhotoCarouselViewer];
    } else if (self.mediaType == SCIMediaTypePhoto) {
        [self setupPhotoViewer];
    } else {
        [self setupVideoPlayer];
    }

    [self setupActionBar];
    [self setupDismissGesture];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    if (self.mediaType == SCIMediaTypeVideo && self.playerLayer) {
        self.playerLayer.frame = self.playerContainerView.bounds;
    }

    if (self.photoCollectionView) {
        UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.photoCollectionView.collectionViewLayout;
        if (!CGSizeEqualToSize(layout.itemSize, self.photoCollectionView.bounds.size)) {
            layout.itemSize = self.photoCollectionView.bounds.size;
            [layout invalidateLayout];
        }

        if (!self.didApplyInitialPhotoIndex && self.photoURLs.count > 0) {
            self.didApplyInitialPhotoIndex = YES;
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:self.currentPhotoIndex inSection:0];
            [self.photoCollectionView scrollToItemAtIndexPath:indexPath
                                             atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                     animated:NO];
            [self updatePhotoCounter];
            [self updateCurrentFileURLForPhotoIndex:self.currentPhotoIndex];
        }
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)dealloc {
    if (_timeObserver) {
        [_player removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
    [_player pause];
}

#pragma mark - Background

- (void)setupBackground {
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _backgroundBlur = [[UIVisualEffectView alloc] initWithEffect:blur];
    _backgroundBlur.frame = self.view.bounds;
    _backgroundBlur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_backgroundBlur];
}

#pragma mark - Close Button

- (void)setupCloseButton {
    _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
    [_closeButton setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:config] forState:UIControlStateNormal];
    _closeButton.tintColor = [UIColor whiteColor];
    _closeButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    _closeButton.layer.cornerRadius = kCloseButtonSize / 2.0;
    _closeButton.clipsToBounds = YES;
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:_closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [_closeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [_closeButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_closeButton.widthAnchor constraintEqualToConstant:kCloseButtonSize],
        [_closeButton.heightAnchor constraintEqualToConstant:kCloseButtonSize],
    ]];
}

#pragma mark - Photo Viewer

- (void)setupPhotoViewer {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.delegate = self;
    _scrollView.minimumZoomScale = kMinZoom;
    _scrollView.maximumZoomScale = kMaxZoom;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.bouncesZoom = YES;
    _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view insertSubview:_scrollView aboveSubview:_backgroundBlur];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    _imageView = [[UIImageView alloc] init];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.clipsToBounds = YES;
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_imageView];

    [NSLayoutConstraint activateConstraints:@[
        [_imageView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor],
        [_imageView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor],
        [_imageView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor],
        [_imageView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor],
        [_imageView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor],
        [_imageView.heightAnchor constraintEqualToAnchor:_scrollView.heightAnchor],
    ]];

    // Load image
    NSData *imageData = [NSData dataWithContentsOfURL:self.fileURL];
    UIImage *image = [UIImage imageWithData:imageData];
    _imageView.image = image;

    // Double-tap to zoom
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [_scrollView addGestureRecognizer:doubleTap];
}

- (void)setupPhotoCarouselViewer {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 0.0;
    layout.minimumInteritemSpacing = 0.0;

    _photoCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _photoCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _photoCollectionView.backgroundColor = [UIColor clearColor];
    _photoCollectionView.pagingEnabled = YES;
    _photoCollectionView.showsHorizontalScrollIndicator = NO;
    _photoCollectionView.showsVerticalScrollIndicator = NO;
    _photoCollectionView.alwaysBounceVertical = NO;
    _photoCollectionView.dataSource = self;
    _photoCollectionView.delegate = self;
    _photoCollectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [_photoCollectionView registerClass:[SCIInlinePhotoCarouselCell class] forCellWithReuseIdentifier:@"SCIInlinePhotoCarouselCell"];
    [self.view insertSubview:_photoCollectionView aboveSubview:_backgroundBlur];

    [NSLayoutConstraint activateConstraints:@[
        [_photoCollectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_photoCollectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_photoCollectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_photoCollectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    _photoCounterLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _photoCounterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _photoCounterLabel.textColor = [UIColor whiteColor];
    _photoCounterLabel.font = [UIFont monospacedDigitSystemFontOfSize:14.0 weight:UIFontWeightSemibold];
    _photoCounterLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_photoCounterLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_photoCounterLabel.centerYAnchor constraintEqualToAnchor:self.closeButton.centerYAnchor],
        [_photoCounterLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];

    [self updatePhotoCounter];
    [self updateCurrentFileURLForPhotoIndex:self.currentPhotoIndex];
}

- (void)updatePhotoCounter {
    if (!self.photoCounterLabel) {
        return;
    }

    if (self.photoURLs.count <= 1) {
        self.photoCounterLabel.text = @"";
        return;
    }

    self.photoCounterLabel.text = [NSString stringWithFormat:@"%ld / %lu",
                                   (long)self.currentPhotoIndex + 1,
                                   (unsigned long)self.photoURLs.count];
}

- (void)updateCurrentFileURLForPhotoIndex:(NSInteger)index {
    if (self.photoURLs.count == 0) {
        return;
    }

    NSInteger boundedIndex = MAX(0, MIN(index, (NSInteger)self.photoURLs.count - 1));
    self.currentPhotoIndex = boundedIndex;
    self.fileURL = self.photoURLs[boundedIndex];
}

- (void)updateCurrentPhotoIndexFromScrollView:(UIScrollView *)scrollView {
    CGFloat pageWidth = CGRectGetWidth(scrollView.bounds);
    if (pageWidth <= 0.0 || self.photoURLs.count == 0) {
        return;
    }

    NSInteger index = (NSInteger)llround(scrollView.contentOffset.x / pageWidth);
    index = MAX(0, MIN(index, (NSInteger)self.photoURLs.count - 1));
    if (index == self.currentPhotoIndex) {
        return;
    }

    [self updateCurrentFileURLForPhotoIndex:index];
    [self updatePhotoCounter];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.photoURLs.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SCIInlinePhotoCarouselCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"SCIInlinePhotoCarouselCell"
                                                                                   forIndexPath:indexPath];
    __weak typeof(self) weakSelf = self;
    __weak SCIInlinePhotoCarouselCell *weakCell = cell;
    cell.zoomStateChanged = ^(BOOL zoomed) {
        SCIInlinePhotoCarouselCell *strongCell = weakCell;
        if (!weakSelf || !strongCell) {
            return;
        }

        NSIndexPath *cellIndexPath = [weakSelf.photoCollectionView indexPathForCell:strongCell];
        if (!cellIndexPath || cellIndexPath.item != weakSelf.currentPhotoIndex) {
            return;
        }

        weakSelf.isCarouselItemZoomed = zoomed;
        weakSelf.photoCollectionView.scrollEnabled = !zoomed;
    };
    [cell configureWithURL:self.photoURLs[indexPath.item] cache:self.photoImageCache];
    return cell;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == self.photoCollectionView) {
        self.isCarouselItemZoomed = NO;
        self.photoCollectionView.scrollEnabled = YES;
        [self updateCurrentPhotoIndexFromScrollView:scrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (scrollView == self.photoCollectionView) {
        self.isCarouselItemZoomed = NO;
        self.photoCollectionView.scrollEnabled = YES;
        [self updateCurrentPhotoIndexFromScrollView:scrollView];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if (scrollView != _scrollView) {
        return nil;
    }

    return _imageView;
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    if (_scrollView.zoomScale > kMinZoom) {
        [_scrollView setZoomScale:kMinZoom animated:YES];
    } else {
        CGPoint point = [recognizer locationInView:_imageView];
        CGFloat newZoom = kMaxZoom / 2.0;
        CGSize scrollSize = _scrollView.bounds.size;
        CGFloat w = scrollSize.width / newZoom;
        CGFloat h = scrollSize.height / newZoom;
        CGRect zoomRect = CGRectMake(point.x - w/2.0, point.y - h/2.0, w, h);
        [_scrollView zoomToRect:zoomRect animated:YES];
    }
}

#pragma mark - Video Player

- (void)setupVideoPlayer {
    _playerContainerView = [[UIView alloc] init];
    _playerContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _playerContainerView.backgroundColor = [UIColor clearColor];
    [self.view insertSubview:_playerContainerView aboveSubview:_backgroundBlur];

    [NSLayoutConstraint activateConstraints:@[
        [_playerContainerView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_playerContainerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_playerContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_playerContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:self.fileURL];
    _player = [AVPlayer playerWithPlayerItem:item];

    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [_playerContainerView.layer addSublayer:_playerLayer];

    [self setupVideoControls];

    // Observe end of playback
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];

    // Start playing
    [_player play];
    [self updatePlayPauseIcon];

    // Time observer for scrubber
    __weak typeof(self) weakSelf = self;
    _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.1, NSEC_PER_SEC)
                                                          queue:dispatch_get_main_queue()
                                                     usingBlock:^(CMTime time) {
        [weakSelf updateVideoTime];
    }];
}

- (void)setupVideoControls {
    _videoControlsBar = [[UIView alloc] init];
    _videoControlsBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_videoControlsBar];

    // Blur background for controls
    UIBlurEffect *controlBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    UIVisualEffectView *controlBlurView = [[UIVisualEffectView alloc] initWithEffect:controlBlur];
    controlBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    controlBlurView.layer.cornerRadius = 12;
    controlBlurView.clipsToBounds = YES;
    [_videoControlsBar addSubview:controlBlurView];

    [NSLayoutConstraint activateConstraints:@[
        [controlBlurView.topAnchor constraintEqualToAnchor:_videoControlsBar.topAnchor],
        [controlBlurView.bottomAnchor constraintEqualToAnchor:_videoControlsBar.bottomAnchor],
        [controlBlurView.leadingAnchor constraintEqualToAnchor:_videoControlsBar.leadingAnchor],
        [controlBlurView.trailingAnchor constraintEqualToAnchor:_videoControlsBar.trailingAnchor],
    ]];

    // Play/Pause button
    _playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;
    _playPauseButton.tintColor = [UIColor whiteColor];
    [_playPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [_videoControlsBar addSubview:_playPauseButton];

    // Scrubber
    _scrubber = [[UISlider alloc] init];
    _scrubber.translatesAutoresizingMaskIntoConstraints = NO;
    _scrubber.minimumTrackTintColor = [UIColor whiteColor];
    _scrubber.maximumTrackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
    _scrubber.thumbTintColor = [UIColor whiteColor];
    // Use a smaller thumb
    UIImage *thumbImage = [self thumbImageWithSize:CGSizeMake(12, 12)];
    [_scrubber setThumbImage:thumbImage forState:UIControlStateNormal];
    [_scrubber addTarget:self action:@selector(scrubberValueChanged) forControlEvents:UIControlEventValueChanged];
    [_scrubber addTarget:self action:@selector(scrubberTouchBegan) forControlEvents:UIControlEventTouchDown];
    [_scrubber addTarget:self action:@selector(scrubberTouchEnded) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [_videoControlsBar addSubview:_scrubber];

    // Time label
    _timeLabel = [[UILabel alloc] init];
    _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _timeLabel.text = @"0:00 / 0:00";
    _timeLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
    _timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];
    [_videoControlsBar addSubview:_timeLabel];

    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [_videoControlsBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_videoControlsBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_videoControlsBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-(kActionBarHeight + kActionBarPadding + 8)],
        [_videoControlsBar.heightAnchor constraintEqualToConstant:48],

        [_playPauseButton.leadingAnchor constraintEqualToAnchor:_videoControlsBar.leadingAnchor constant:12],
        [_playPauseButton.centerYAnchor constraintEqualToAnchor:_videoControlsBar.centerYAnchor],
        [_playPauseButton.widthAnchor constraintEqualToConstant:28],
        [_playPauseButton.heightAnchor constraintEqualToConstant:28],

        [_scrubber.leadingAnchor constraintEqualToAnchor:_playPauseButton.trailingAnchor constant:8],
        [_scrubber.trailingAnchor constraintEqualToAnchor:_timeLabel.leadingAnchor constant:-8],
        [_scrubber.centerYAnchor constraintEqualToAnchor:_videoControlsBar.centerYAnchor],

        [_timeLabel.trailingAnchor constraintEqualToAnchor:_videoControlsBar.trailingAnchor constant:-12],
        [_timeLabel.centerYAnchor constraintEqualToAnchor:_videoControlsBar.centerYAnchor],
    ]];

    [_timeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
}

- (UIImage *)thumbImageWithSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size.width, size.height)];
    [[UIColor whiteColor] setFill];
    [circle fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)togglePlayPause {
    if (_player.rate > 0) {
        [_player pause];
    } else {
        // If at end, restart
        CMTime duration = _player.currentItem.duration;
        CMTime current = _player.currentTime;
        if (CMTimeCompare(current, CMTimeSubtract(duration, CMTimeMakeWithSeconds(0.5, NSEC_PER_SEC))) >= 0) {
            [_player seekToTime:kCMTimeZero];
        }
        [_player play];
    }
    [self updatePlayPauseIcon];
}

- (void)updatePlayPauseIcon {
    NSString *name = (_player.rate > 0) ? @"pause.fill" : @"play.fill";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    [_playPauseButton setImage:[UIImage systemImageNamed:name withConfiguration:config] forState:UIControlStateNormal];
}

- (void)updateVideoTime {
    CMTime duration = _player.currentItem.duration;
    CMTime current = _player.currentTime;

    if (CMTIME_IS_INDEFINITE(duration) || CMTIME_IS_INVALID(duration)) return;

    Float64 dur = CMTimeGetSeconds(duration);
    Float64 cur = CMTimeGetSeconds(current);

    if (!_scrubber.isTracking) {
        _scrubber.value = (dur > 0) ? (float)(cur / dur) : 0;
    }

    _timeLabel.text = [NSString stringWithFormat:@"%@ / %@",
                       [self formatTime:cur],
                       [self formatTime:dur]];
}

- (NSString *)formatTime:(Float64)seconds {
    if (isnan(seconds) || seconds < 0) seconds = 0;
    int mins = (int)(seconds / 60);
    int secs = (int)seconds % 60;
    return [NSString stringWithFormat:@"%d:%02d", mins, secs];
}

- (void)scrubberValueChanged {
    CMTime duration = _player.currentItem.duration;
    if (CMTIME_IS_INDEFINITE(duration)) return;

    Float64 dur = CMTimeGetSeconds(duration);
    Float64 target = dur * _scrubber.value;
    [_player seekToTime:CMTimeMakeWithSeconds(target, NSEC_PER_SEC) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (void)scrubberTouchBegan {
    [_player pause];
}

- (void)scrubberTouchEnded {
    [_player play];
    [self updatePlayPauseIcon];
}

- (void)playerDidFinishPlaying:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePlayPauseIcon];
    });
}

#pragma mark - Action Bar

- (void)setupActionBar {
    _actionBar = [[UIView alloc] init];
    _actionBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_actionBar];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.layer.cornerRadius = 16.0;
    blurView.layer.cornerCurve = kCACornerCurveContinuous;
    blurView.clipsToBounds = YES;
    [_actionBar addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [_actionBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kActionBarPadding],
        [_actionBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kActionBarPadding],
        [_actionBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [_actionBar.heightAnchor constraintEqualToConstant:kActionBarHeight],
        
        [blurView.leadingAnchor constraintEqualToAnchor:_actionBar.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:_actionBar.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:_actionBar.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:_actionBar.bottomAnchor],
    ]];

    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];

    // Save
    UIImage *saveIcon = [UIImage systemImageNamed:@"arrow.down" withConfiguration:config];
    UIButton *saveBtn = [self actionButtonWithTitle:@"Save" image:saveIcon action:@selector(saveToPhotos)];
    [buttons addObject:saveBtn];

    // Share
    UIImage *shareIcon = [UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:config];
    UIButton *shareBtn = [self actionButtonWithTitle:@"Share" image:shareIcon action:@selector(shareMedia)];
    [buttons addObject:shareBtn];

    // Copy (photo only)
    if (self.mediaType == SCIMediaTypePhoto) {
        UIImage *copyIcon = [UIImage systemImageNamed:@"doc.on.doc" withConfiguration:config];
        UIButton *copyBtn = [self actionButtonWithTitle:@"Copy" image:copyIcon action:@selector(copyMedia)];
        [buttons addObject:copyBtn];
    }

    // Vault
    UIImage *vaultIcon = [UIImage systemImageNamed:@"tray.full" withConfiguration:config];
    UIButton *vaultBtn = [self actionButtonWithTitle:@"Vault" image:vaultIcon action:@selector(saveToVault)];
    [buttons addObject:vaultBtn];

    // Stack them horizontally
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_actionBar addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:_actionBar.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:_actionBar.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:_actionBar.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:_actionBar.trailingAnchor],
    ]];

    // Separators
    for (NSUInteger i = 1; i < buttons.count; i++) {
        UIView *separator = [[UIView alloc] init];
        separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        separator.translatesAutoresizingMaskIntoConstraints = NO;
        separator.userInteractionEnabled = NO;
        [_actionBar addSubview:separator];

        UIButton *prevBtn = buttons[i-1];
        [NSLayoutConstraint activateConstraints:@[
            [separator.leadingAnchor constraintEqualToAnchor:prevBtn.trailingAnchor],
            [separator.centerYAnchor constraintEqualToAnchor:stack.centerYAnchor],
            [separator.heightAnchor constraintEqualToConstant:24],
            [separator.widthAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale]
        ]];
    }
}

- (UIButton *)actionButtonWithTitle:(NSString *)title image:(UIImage *)icon action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.title = title;
        config.image = icon;
        config.imagePadding = 6.0;
        config.baseForegroundColor = [UIColor whiteColor];
        
        NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightMedium]};
        config.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attributes];
        button.configuration = config;
    } else {
        [button setImage:icon forState:UIControlStateNormal];
        [button setTitle:[NSString stringWithFormat:@" %@", title] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        button.tintColor = [UIColor whiteColor];
    }

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Actions

- (NSURL *)activeMediaURL {
    if (self.mediaType == SCIMediaTypePhoto && self.photoURLs.count > 0) {
        NSInteger boundedIndex = MAX(0, MIN(self.currentPhotoIndex, (NSInteger)self.photoURLs.count - 1));
        NSURL *url = self.photoURLs[boundedIndex];
        if (url) {
            return url;
        }
    }

    return self.fileURL;
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveToPhotos {
    NSURL *targetURL = [self activeMediaURL];
    if (self.mediaType == SCIMediaTypePhoto) {
        NSData *imageData = [NSData dataWithContentsOfURL:targetURL];
        UIImage *image = [UIImage imageWithData:imageData];
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
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:targetURL];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showSaveResult:success error:error];
            });
        }];
    }
}

- (void)showSaveResult:(BOOL)success error:(NSError *)error {
    if (success) {
        UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
        [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
        [SCIUtils showToastForDuration:2.0 title:@"Saved to Photos"];
    } else {
        UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
        [haptic notificationOccurred:UINotificationFeedbackTypeError];
        [SCIUtils showToastForDuration:3.0 title:@"Failed to save" subtitle:error.localizedDescription];
    }
}

- (void)shareMedia {
    NSURL *targetURL = [self activeMediaURL];
    UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[targetURL] applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        acVC.popoverPresentationController.sourceView = self.view;
        acVC.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height - 50, 1, 1);
    }
    [self presentViewController:acVC animated:YES completion:nil];
}

- (void)copyMedia {
    if (self.mediaType == SCIMediaTypePhoto) {
        NSData *imageData = [NSData dataWithContentsOfURL:[self activeMediaURL]];
        UIImage *image = [UIImage imageWithData:imageData];
        if (image) {
            [[UIPasteboard generalPasteboard] setImage:image];

            UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
            [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
            [SCIUtils showToastForDuration:1.5 title:@"Copied"];
        }
    }
}

- (void)saveToVault {
    NSURL *targetURL = [self activeMediaURL];
    if (!targetURL) {
        [self showVaultFeedback:NO message:@"No media to save"];
        return;
    }

    SCIVaultMediaType vaultType = (self.mediaType == SCIMediaTypeVideo) ? SCIVaultMediaTypeVideo : SCIVaultMediaTypeImage;

    if (targetURL.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:targetURL.path]) {
        [self vaultSaveLocalFile:targetURL mediaType:vaultType];
        return;
    }

    [self showVaultFeedback:NO message:@"Downloading..."];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:targetURL];
        if (!data.length) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf showVaultFeedback:NO message:@"Download failed"];
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
    SCIVaultFile *file = [SCIVaultFile saveFileToVault:localURL source:SCIVaultSourceOther mediaType:vaultType error:&error];

    UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
    if (file) {
        [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
        [self showVaultFeedback:YES message:@"Saved to Vault"];
    } else {
        [haptic notificationOccurred:UINotificationFeedbackTypeError];
        NSString *msg = error.localizedDescription.length ? error.localizedDescription : @"Failed to save";
        [self showVaultFeedback:NO message:msg];
    }
}

- (void)showVaultFeedback:(BOOL)success message:(NSString *)message {
    for (UIView *sub in self.view.subviews) {
        if (sub.tag == 9991) [sub removeFromSuperview];
    }

    UIView *pill = [[UIView alloc] initWithFrame:CGRectZero];
    pill.tag = 9991;
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    pill.backgroundColor = success ? [[UIColor systemGreenColor] colorWithAlphaComponent:0.9]
                                   : [[UIColor colorWithWhite:0.2 alpha:0.9] colorWithAlphaComponent:0.9];
    pill.layer.cornerRadius = 18;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.clipsToBounds = YES;
    pill.alpha = 0.0;
    [self.view addSubview:pill];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    [pill addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [pill.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [pill.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [pill.heightAnchor constraintEqualToConstant:36],
        [label.centerXAnchor constraintEqualToAnchor:pill.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:pill.centerYAnchor],
        [pill.leadingAnchor constraintEqualToAnchor:label.leadingAnchor constant:-20],
        [pill.trailingAnchor constraintEqualToAnchor:label.trailingAnchor constant:20],
    ]];

    [UIView animateWithDuration:0.25 animations:^{
        pill.alpha = 1.0;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.25 animations:^{
                pill.alpha = 0.0;
            } completion:^(BOOL finished2) {
                [pill removeFromSuperview];
            }];
        });
    }];
}

#pragma mark - Swipe to Dismiss

- (void)setupDismissGesture {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanDismiss:)];
    pan.delegate = self;
    [self.view addGestureRecognizer:pan];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handlePanDismiss:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.view];
    CGPoint velocity = [pan velocityInView:self.view];

    BOOL verticalIntent = fabs(velocity.y) >= fabs(velocity.x);

    if (pan.state == UIGestureRecognizerStateBegan) {
        _isDismissing = verticalIntent;

        if (self.mediaType == SCIMediaTypePhoto && _scrollView.zoomScale > kMinZoom) {
            _isDismissing = NO;
        }

        if (self.photoCollectionView && self.isCarouselItemZoomed) {
            _isDismissing = NO;
        }
    }

    if (!_isDismissing) return;

    if (self.photoCollectionView && fabs(translation.y) < fabs(translation.x)) {
        if (pan.state == UIGestureRecognizerStateChanged) {
            return;
        }
    }

    CGFloat progress = MIN(MAX(fabs(translation.y) / 300.0, 0), 1.0);

    switch (pan.state) {
        case UIGestureRecognizerStateChanged: {
            UIView *contentView = nil;
            if (self.mediaType == SCIMediaTypeVideo) {
                contentView = _playerContainerView;
            } else if (self.photoCollectionView) {
                contentView = self.photoCollectionView;
            } else {
                contentView = _scrollView;
            }

            contentView.transform = CGAffineTransformMakeTranslation(0, translation.y);
            CGFloat scale = 1.0 - progress * 0.2;
            contentView.transform = CGAffineTransformScale(contentView.transform, scale, scale);
            _backgroundBlur.alpha = 1.0 - progress;
            _actionBar.alpha = 1.0 - progress * 2;
            _closeButton.alpha = 1.0 - progress * 2;
            if (self.photoCounterLabel) self.photoCounterLabel.alpha = 1.0 - progress * 2;
            if (_videoControlsBar) _videoControlsBar.alpha = 1.0 - progress * 2;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (progress > 0.3 || fabs(velocity.y) > 800) {
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                // Spring back
                [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0 options:0 animations:^{
                    UIView *contentView = nil;
                    if (self.mediaType == SCIMediaTypeVideo) {
                        contentView = self->_playerContainerView;
                    } else if (self.photoCollectionView) {
                        contentView = self.photoCollectionView;
                    } else {
                        contentView = self->_scrollView;
                    }

                    contentView.transform = CGAffineTransformIdentity;
                    self->_backgroundBlur.alpha = 1;
                    self->_actionBar.alpha = 1;
                    self->_closeButton.alpha = 1;
                    if (self.photoCounterLabel) self.photoCounterLabel.alpha = 1;
                    if (self->_videoControlsBar) self->_videoControlsBar.alpha = 1;
                } completion:nil];
            }
            _isDismissing = NO;
            break;
        }
        default:
            break;
    }
}

@end
