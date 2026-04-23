#import "SCIFullScreenVideoViewController.h"
#import "SCIMediaItem.h"
#import <AVFoundation/AVFoundation.h>
#import "../Utils.h"

static NSCache<NSString *, UIImage *> *SCIFullScreenVideoThumbnailCache(void) {
    static NSCache<NSString *, UIImage *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.name = @"com.scinsta.fullscreen-video-thumbnail-cache";
        cache.countLimit = 48;
    });
    return cache;
}

static NSString *SCIVideoThumbnailCacheKeyForURL(NSURL *url) {
    return url.absoluteString ?: url.path;
}

@interface SCIFullScreenVideoViewController () <AVPlayerViewControllerDelegate>

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerViewController *playerViewController;
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL hasPreparedPlayer;
@property (nonatomic, assign) BOOL hasStartedPlayback;
@property (nonatomic, assign) BOOL isLoadingThumbnail;
@property (nonatomic, assign) BOOL isObservingPlayerItemStatus;

@end

@implementation SCIFullScreenVideoViewController

- (instancetype)initWithMediaItem:(SCIMediaItem *)item {
    self = [super init];
    if (self) {
        _mediaItem = item;
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

    [NSLayoutConstraint activateConstraints:@[
        [_playerViewController.view.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:44.0],
        [_playerViewController.view.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-44.0],
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

#pragma mark - Thumbnail

- (void)preloadThumbnailIfNeeded {
    if (self.mediaItem.thumbnail) {
        _thumbnailView.image = self.mediaItem.thumbnail;
        return;
    }

    NSURL *url = self.mediaItem.fileURL;
    if (!url) return;

    NSString *cacheKey = SCIVideoThumbnailCacheKeyForURL(url);
    UIImage *cachedThumbnail = cacheKey.length ? [SCIFullScreenVideoThumbnailCache() objectForKey:cacheKey] : nil;
    if (cachedThumbnail) {
        self.mediaItem.thumbnail = cachedThumbnail;
        _thumbnailView.image = cachedThumbnail;
        return;
    }

    if (self.isLoadingThumbnail) return;

    self.isLoadingThumbnail = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        AVAsset *asset = [AVAsset assetWithURL:url];
        AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        gen.appliesPreferredTrackTransform = YES;
        gen.maximumSize = CGSizeMake(640, 640);

        NSError *error = nil;
        CGImageRef cgImage = [gen copyCGImageAtTime:kCMTimeZero actualTime:NULL error:&error];
        UIImage *thumb = cgImage ? [UIImage imageWithCGImage:cgImage] : nil;
        if (cgImage) {
            CGImageRelease(cgImage);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            strongSelf.isLoadingThumbnail = NO;
            if (!thumb) return;

            strongSelf.mediaItem.thumbnail = thumb;
            if (cacheKey.length) {
                [SCIFullScreenVideoThumbnailCache() setObject:thumb forKey:cacheKey];
            }
            if (!strongSelf.hasStartedPlayback) {
                strongSelf.thumbnailView.image = thumb;
            }
        });
    });
}

#pragma mark - Player Preparation

- (void)ensurePlayerPrepared {
    if (_hasPreparedPlayer) return;
    _hasPreparedPlayer = YES;

    NSURL *url = self.mediaItem.fileURL;
    if (!url) return;

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
}

- (void)prepareForDisplay {
    [self preloadThumbnailIfNeeded];
    [self ensurePlayerPrepared];
    [self ensurePlayerViewControllerIfNeeded];

    if (_playerItem && !_hasStartedPlayback) {
        [self startPlayback];
    } else if (_player && !_isPlaying) {
        [self play];
    }
}

- (void)startPlayback {
    if (_hasStartedPlayback) return;
    _hasStartedPlayback = YES;

    [_loadingIndicator startAnimating];
    [self ensurePlayerViewControllerIfNeeded];

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
        return;
    }
    // Will be called from KVO when status changes
}

- (void)doHideThumbnail {
    [_loadingIndicator stopAnimating];

    if (_thumbnailView.hidden) return;

    [UIView animateWithDuration:0.2 animations:^{
        self->_thumbnailView.alpha = 0;
    } completion:^(BOOL finished) {
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
                    NSError *err = self->_playerItem.error ?: [NSError errorWithDomain:@"SCIFullScreenVideoViewController" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Playback failed"}];
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

- (void)play {
    [_player play];
    _isPlaying = YES;
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
    _hasPreparedPlayer = NO;
    _hasStartedPlayback = NO;
    _isPlaying = NO;
}

- (void)cleanup {
    [self tearDownPlayer];
    [_loadingIndicator stopAnimating];
    _thumbnailView.hidden = NO;
    _thumbnailView.alpha = 1.0;
    _thumbnailView.image = self.mediaItem.thumbnail;
}

@end
