#import "SCIFullScreenImageViewController.h"
#import "SCIMediaItem.h"

static CGFloat const kMaxZoom = 5.0;
static CGFloat const kMinZoom = 1.0;
static CGFloat const kZoomEpsilon = 0.02;

@interface SCIFullScreenImageViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIView *errorView;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapGesture;

@end

@implementation SCIFullScreenImageViewController

- (instancetype)initWithMediaItem:(SCIMediaItem *)item {
    self = [super init];
    if (self) {
        _mediaItem = item;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    [self setupScrollView];
    [self setupImageView];
    [self setupLoadingIndicator];
    [self setupErrorView];
    [self setupGestures];
    [self loadImage];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateImageViewFrame];
}

#pragma mark - Setup

- (void)setupScrollView {
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.delegate = self;
    _scrollView.minimumZoomScale = kMinZoom;
    _scrollView.maximumZoomScale = kMaxZoom;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.bouncesZoom = YES;
    _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:_scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)setupImageView {
    _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.clipsToBounds = YES;
    [_scrollView addSubview:_imageView];
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

- (void)setupErrorView {
    _errorView = [[UIView alloc] initWithFrame:CGRectZero];
    _errorView.translatesAutoresizingMaskIntoConstraints = NO;
    _errorView.hidden = YES;
    [self.view addSubview:_errorView];

    _errorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _errorLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    _errorLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _errorLabel.textAlignment = NSTextAlignmentCenter;
    _errorLabel.numberOfLines = 0;
    [_errorView addSubview:_errorLabel];

    _retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_retryButton setTitle:@"Retry" forState:UIControlStateNormal];
    [_retryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _retryButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _retryButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    _retryButton.layer.cornerRadius = 18;
    [_retryButton addTarget:self action:@selector(retryLoading) forControlEvents:UIControlEventTouchUpInside];
    [_errorView addSubview:_retryButton];

    [NSLayoutConstraint activateConstraints:@[
        [_errorView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_errorView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_errorView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40],

        [_errorLabel.topAnchor constraintEqualToAnchor:_errorView.topAnchor],
        [_errorLabel.leadingAnchor constraintEqualToAnchor:_errorView.leadingAnchor],
        [_errorLabel.trailingAnchor constraintEqualToAnchor:_errorView.trailingAnchor],

        [_retryButton.topAnchor constraintEqualToAnchor:_errorLabel.bottomAnchor constant:16],
        [_retryButton.centerXAnchor constraintEqualToAnchor:_errorView.centerXAnchor],
        [_retryButton.widthAnchor constraintEqualToConstant:100],
        [_retryButton.heightAnchor constraintEqualToConstant:36],
        [_retryButton.bottomAnchor constraintEqualToAnchor:_errorView.bottomAnchor],
    ]];
}

- (void)setupGestures {
    _doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    _doubleTapGesture.numberOfTapsRequired = 2;
    [_scrollView addGestureRecognizer:_doubleTapGesture];

    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [singleTap requireGestureRecognizerToFail:_doubleTapGesture];
    [_scrollView addGestureRecognizer:singleTap];
}

#pragma mark - Image Loading

- (void)loadImage {
    if (self.mediaItem.image) {
        [self displayImage:self.mediaItem.image];
        return;
    }

    NSURL *url = self.mediaItem.fileURL;
    if (!url) {
        [self showError:@"No image URL"];
        return;
    }

    [_loadingIndicator startAnimating];
    _errorView.hidden = YES;

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        UIImage *image = data ? [UIImage imageWithData:data] : nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            [strongSelf.loadingIndicator stopAnimating];
            if (image) {
                [strongSelf displayImage:image];
            } else {
                [strongSelf showError:@"Failed to load image"];
            }
        });
    });
}

- (void)retryLoading {
    [self loadImage];
}

- (void)displayImage:(UIImage *)image {
    _imageView.image = image;
    _scrollView.hidden = NO;
    _errorView.hidden = YES;
    [_scrollView setZoomScale:kMinZoom animated:NO];
    [self updateImageViewFrame];
}

- (void)showError:(NSString *)message {
    _errorLabel.text = message;
    _errorView.hidden = NO;
    _scrollView.hidden = YES;

    if ([self.delegate respondsToSelector:@selector(mediaContent:didFailWithError:)]) {
        NSError *error = [NSError errorWithDomain:@"SCIFullScreenImageViewController" code:-1 userInfo:@{NSLocalizedDescriptionKey: message}];
        [self.delegate mediaContent:self didFailWithError:error];
    }
}

#pragma mark - Frame Management

/// Centers the zoomed image inside the scroll view using frame origin (stable with `UIScrollView` zoom).
- (void)sci_recenterZoomedImage {
    CGSize boundsSize = _scrollView.bounds.size;
    CGRect frame = _imageView.frame;

    CGFloat horizontal = frame.size.width < boundsSize.width ? (boundsSize.width - frame.size.width) * 0.5 : 0.0;
    CGFloat vertical = frame.size.height < boundsSize.height ? (boundsSize.height - frame.size.height) * 0.5 : 0.0;

    _imageView.frame = CGRectMake(horizontal, vertical, frame.size.width, frame.size.height);
}

- (void)updateImageViewFrame {
    UIImage *image = _imageView.image;
    if (!image) return;

    CGSize boundsSize = _scrollView.bounds.size;
    if (boundsSize.width <= 0 || boundsSize.height <= 0) return;

    BOOL atMinimumZoom = (_scrollView.zoomScale <= kMinZoom + kZoomEpsilon);

    if (atMinimumZoom) {
        CGSize imageSize = image.size;
        CGFloat widthRatio = boundsSize.width / imageSize.width;
        CGFloat heightRatio = boundsSize.height / imageSize.height;
        CGFloat ratio = MIN(widthRatio, heightRatio);

        CGFloat newWidth = imageSize.width * ratio;
        CGFloat newHeight = imageSize.height * ratio;

        _imageView.frame = CGRectMake(0, 0, newWidth, newHeight);
        _scrollView.contentSize = CGSizeMake(newWidth, newHeight);
        [self sci_recenterZoomedImage];
    } else {
        [self sci_recenterZoomedImage];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self sci_recenterZoomedImage];
}

#pragma mark - Gestures

- (BOOL)isZoomed {
    return _scrollView.zoomScale > kMinZoom + kZoomEpsilon;
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    if (self.isZoomed) {
        [_scrollView setZoomScale:kMinZoom animated:YES];
    } else {
        CGPoint point = [recognizer locationInView:_imageView];
        CGFloat newZoom = kMaxZoom / 2.0;
        CGSize scrollSize = _scrollView.bounds.size;
        CGFloat w = scrollSize.width / newZoom;
        CGFloat h = scrollSize.height / newZoom;
        CGRect zoomRect = CGRectMake(point.x - w / 2.0, point.y - h / 2.0, w, h);
        [_scrollView zoomToRect:zoomRect animated:YES];
    }
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    if ([self.delegate respondsToSelector:@selector(mediaContentDidTap:)]) {
        [self.delegate mediaContentDidTap:self];
    }
}

- (void)resetZoomIfNeeded {
    if (!self.isZoomed) {
        [_scrollView setZoomScale:kMinZoom animated:NO];
        [self sci_recenterZoomedImage];
    }
}

- (void)forceResetZoom {
    [_scrollView setZoomScale:kMinZoom animated:NO];
    [self updateImageViewFrame];
}

#pragma mark - Cleanup

- (void)cleanup {
    _imageView.image = nil;
}

@end
