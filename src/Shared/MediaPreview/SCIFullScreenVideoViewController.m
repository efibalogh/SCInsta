#import "SCIFullScreenVideoViewController.h"
#import "SCIMediaItem.h"
#import "SCIMediaCacheManager.h"
#import <AVFoundation/AVFoundation.h>
#import "../../Utils.h"

static NSTimeInterval const kPlayerControlOverlayInsetAnimationDuration = 0.25;

@interface SCIFullScreenVideoViewController () <AVPlayerViewControllerDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerViewController *playerViewController;
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UITapGestureRecognizer *singleTapGesture;
@property (nonatomic, strong) NSURL *preparedPlaybackURL;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL hasPreparedPlayer;
@property (nonatomic, assign) BOOL hasStartedPlayback;
@property (nonatomic, assign) BOOL isLoadingThumbnail;
@property (nonatomic, assign) BOOL isObservingPlayerItemStatus;
@property (nonatomic, assign) UIEdgeInsets playerControlOverlayInsets;
@property (nonatomic, assign) NSInteger loadGeneration;

@end

@implementation SCIFullScreenVideoViewController

- (instancetype)initWithMediaItem:(SCIMediaItem *)item {
    self = [super init];
    if (self) {
        _mediaItem = item;
        _playerControlOverlayInsets = UIEdgeInsetsZero;
    }
    return self;
}

- (void)dealloc {
    [self tearDownPlayer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    [self setupThumbnailView];
    [self setupLoadingIndicator];
    [self setupTapGesture];
    if (self.mediaItem.thumbnail) {
        self.thumbnailView.image = self.mediaItem.thumbnail;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self prepareForDisplay];
}

- (UIView *)contentOverlayView {
    return _playerViewController.contentOverlayView;
}

#pragma mark - Setup

- (void)ensurePlayerViewControllerIfNeeded {
    if (_playerViewController) return;

    _playerViewController = [[AVPlayerViewController alloc] init];
    _playerViewController.showsPlaybackControls = YES;
    _playerViewController.allowsPictureInPicturePlayback = NO;
    _playerViewController.delegate = self;
    _playerViewController.view.backgroundColor = [UIColor clearColor];

    [self addChildViewController:_playerViewController];
    _playerViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:_playerViewController.view atIndex:0];
    [_playerViewController didMoveToParentViewController:self];
    _playerViewController.additionalSafeAreaInsets = self.playerControlOverlayInsets;

    [NSLayoutConstraint activateConstraints:@[
        [_playerViewController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_playerViewController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_playerViewController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_playerViewController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)setupThumbnailView {
    _thumbnailView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    _thumbnailView.contentMode = UIViewContentModeScaleAspectFit;
    _thumbnailView.clipsToBounds = YES;
    _thumbnailView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_thumbnailView];

    [NSLayoutConstraint activateConstraints:@[
        [_thumbnailView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_thumbnailView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_thumbnailView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_thumbnailView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)setPlayerControlOverlayInsets:(UIEdgeInsets)insets animated:(BOOL)animated {
    if (UIEdgeInsetsEqualToEdgeInsets(_playerControlOverlayInsets, insets) &&
        (!_playerViewController || UIEdgeInsetsEqualToEdgeInsets(_playerViewController.additionalSafeAreaInsets, insets))) {
        return;
    }

    _playerControlOverlayInsets = insets;
    if (!_playerViewController) {
        return;
    }

    _playerViewController.additionalSafeAreaInsets = insets;

    void (^layout)(void) = ^{
        [self->_playerViewController.view layoutIfNeeded];
    };
    if (animated && self.isViewLoaded && _playerViewController) {
        [UIView animateWithDuration:kPlayerControlOverlayInsetAnimationDuration
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:layout
                         completion:nil];
    } else {
        layout();
    }
}

- (void)setupLoadingIndicator {
    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingIndicator.color = [UIColor whiteColor];
    _loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:_loadingIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [_loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)setupTapGesture {
    _singleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    _singleTapGesture.cancelsTouchesInView = NO;
    _singleTapGesture.delegate = self;
    [self.view addGestureRecognizer:_singleTapGesture];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer != _singleTapGesture) {
        return YES;
    }

    UIView *view = touch.view;
    while (view) {
        if ([view isKindOfClass:[UIControl class]]) {
            return NO;
        }
        if (view == self.view) {
            break;
        }
        view = view.superview;
    }
    return YES;
}

#pragma mark - Thumbnail

- (void)preloadThumbnailIfNeeded {
    if (self.mediaItem.thumbnail) {
        _thumbnailView.image = self.mediaItem.thumbnail;
        return;
    }
    if (self.isLoadingThumbnail) return;

    self.isLoadingThumbnail = YES;
    __weak typeof(self) weakSelf = self;
    [[SCIMediaCacheManager sharedManager] loadThumbnailForVideoItem:self.mediaItem completion:^(UIImage * _Nullable thumb) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        strongSelf.isLoadingThumbnail = NO;
        if (thumb && !strongSelf.hasStartedPlayback) {
            strongSelf.thumbnailView.image = thumb;
        }
    }];
}

#pragma mark - Player Preparation

- (void)preparePlayerWithURL:(NSURL *)url {
    if (!url) return;
    if (_hasPreparedPlayer && [self.preparedPlaybackURL isEqual:url]) return;

    [self tearDownPlayer];
    _hasPreparedPlayer = YES;
    self.preparedPlaybackURL = url;
    self.mediaItem.resolvedFileURL = url;

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    _playerItem = item;
    _player = [AVPlayer playerWithPlayerItem:item];
    _player.muted = [SCIUtils getBoolPref:@"expanded_video_start_muted"];

    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    self.isObservingPlayerItemStatus = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
}

#pragma mark - Preload & Playback

- (void)preloadContent {
    [self preloadThumbnailIfNeeded];
    [[SCIMediaCacheManager sharedManager] prefetchItem:self.mediaItem];
}

- (void)prepareForDisplay {
    [self preloadThumbnailIfNeeded];
    [self ensurePlayerViewControllerIfNeeded];

    NSURL *resolvedURL = [[SCIMediaCacheManager sharedManager] bestAvailableFileURLForItem:self.mediaItem];
    if (_player && _hasPreparedPlayer && resolvedURL && [self.preparedPlaybackURL isEqual:resolvedURL]) {
        [self.loadingIndicator stopAnimating];
        if (_playerItem.status == AVPlayerItemStatusReadyToPlay) {
            _thumbnailView.hidden = YES;
            _thumbnailView.alpha = 0.0;
        }
        if (!_isPlaying) {
            [self play];
        }
        return;
    }

    [self.loadingIndicator startAnimating];

    NSInteger generation = self.loadGeneration + 1;
    self.loadGeneration = generation;

    __weak typeof(self) weakSelf = self;
    [[SCIMediaCacheManager sharedManager] fetchLocalFileURLForItem:self.mediaItem completion:^(NSURL * _Nullable localURL, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.loadGeneration != generation) return;

        if (!localURL || error) {
            [strongSelf.loadingIndicator stopAnimating];
            if ([strongSelf.delegate respondsToSelector:@selector(mediaContent:didFailWithError:)]) {
                NSError *resolvedError = error ?: [NSError errorWithDomain:@"SCIFullScreenVideoViewController"
                                                                      code:-2
                                                                  userInfo:@{NSLocalizedDescriptionKey: @"Playback failed"}];
                [strongSelf.delegate mediaContent:strongSelf didFailWithError:resolvedError];
            }
            return;
        }

        if (strongSelf->_player && strongSelf->_hasPreparedPlayer && [strongSelf.preparedPlaybackURL isEqual:localURL]) {
            [strongSelf.loadingIndicator stopAnimating];
            if (strongSelf->_playerItem.status == AVPlayerItemStatusReadyToPlay) {
                strongSelf->_thumbnailView.hidden = YES;
                strongSelf->_thumbnailView.alpha = 0.0;
            }
            if (!strongSelf->_isPlaying) {
                [strongSelf play];
            }
            return;
        }

        [strongSelf preparePlayerWithURL:localURL];
        if (strongSelf->_playerItem && !strongSelf->_hasStartedPlayback) {
            [strongSelf startPlayback];
        } else if (strongSelf->_player && !strongSelf->_isPlaying) {
            [strongSelf play];
        }
    }];
}

- (void)startPlayback {
    if (_hasStartedPlayback) return;
    _hasStartedPlayback = YES;

    NSError *audioErr = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:&audioErr];
    [session setActive:YES error:&audioErr];

    _playerViewController.player = _player;
    [_player play];
    _isPlaying = YES;

    [self hideThumbnailWhenReady];
}

- (void)hideThumbnailWhenReady {
    if (_playerItem.status == AVPlayerItemStatusReadyToPlay) {
        [self doHideThumbnail];
    }
}

- (void)doHideThumbnail {
    [_loadingIndicator stopAnimating];

    if (_thumbnailView.hidden) return;

    [UIView animateWithDuration:0.2 animations:^{
        self->_thumbnailView.alpha = 0;
    } completion:^(__unused BOOL finished) {
        self->_thumbnailView.hidden = YES;
    }];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"] && object == _playerItem) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_playerItem.status == AVPlayerItemStatusReadyToPlay) {
                [self doHideThumbnail];
            } else if (self->_playerItem.status == AVPlayerItemStatusFailed) {
                [self->_loadingIndicator stopAnimating];
                if ([self.delegate respondsToSelector:@selector(mediaContent:didFailWithError:)]) {
                    NSError *err = self->_playerItem.error ?: [NSError errorWithDomain:@"SCIFullScreenVideoViewController"
                                                                                  code:-1
                                                                              userInfo:@{NSLocalizedDescriptionKey: @"Playback failed"}];
                    [self.delegate mediaContent:self didFailWithError:err];
                }
            }
        });
    }
}

#pragma mark - Notifications

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    _isPlaying = NO;
}

#pragma mark - Controls

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) return;
    if ([self.delegate respondsToSelector:@selector(mediaContentDidTap:)]) {
        [self.delegate mediaContentDidTap:self];
    }
}

- (void)play {
    if (_player) {
        [_player play];
        _isPlaying = YES;
        return;
    }
    [self prepareForDisplay];
}

- (void)pause {
    [_player pause];
    _isPlaying = NO;
}

- (void)stop {
    [_player pause];
    [_player seekToTime:kCMTimeZero];
    _isPlaying = NO;
}

#pragma mark - Cleanup

- (void)tearDownPlayer {
    if (self.playerItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
    if (self.isObservingPlayerItemStatus && self.playerItem) {
        [self.playerItem removeObserver:self forKeyPath:@"status" context:nil];
        self.isObservingPlayerItemStatus = NO;
    }

    [_player pause];
    _playerViewController.player = nil;
    _player = nil;
    _playerItem = nil;
    _preparedPlaybackURL = nil;
    _hasPreparedPlayer = NO;
    _hasStartedPlayback = NO;
    _isPlaying = NO;
}

- (void)cleanup {
    self.loadGeneration++;
    [self tearDownPlayer];
    [_loadingIndicator stopAnimating];
    _thumbnailView.hidden = NO;
    _thumbnailView.alpha = 1.0;
    _thumbnailView.image = self.mediaItem.thumbnail;
}

@end
