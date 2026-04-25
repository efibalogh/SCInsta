#import "SCIVaultGridCell.h"
#import "SCIVaultFile.h"
#import "../../Utils.h"

@interface SCIVaultGridCell ()

@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIImageView *videoBadge;
@property (nonatomic, strong) UIImageView *favoriteBadge;

@end

@implementation SCIVaultGridCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.clipsToBounds = YES;
        self.contentView.layer.cornerRadius = 6.0;
        self.contentView.backgroundColor = [UIColor secondarySystemBackgroundColor];

        _thumbnailView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
        _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbnailView.clipsToBounds = YES;
        [self.contentView addSubview:_thumbnailView];

        _videoBadge = [[UIImageView alloc] initWithFrame:CGRectZero];
        _videoBadge.translatesAutoresizingMaskIntoConstraints = NO;
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
        _videoBadge.image = [UIImage systemImageNamed:@"play.fill" withConfiguration:cfg];
        _videoBadge.tintColor = [UIColor whiteColor];
        _videoBadge.hidden = YES;

        UIView *videoBadgeBG = [[UIView alloc] initWithFrame:CGRectZero];
        videoBadgeBG.translatesAutoresizingMaskIntoConstraints = NO;
        videoBadgeBG.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        videoBadgeBG.layer.cornerRadius = 10;
        videoBadgeBG.tag = 100;
        videoBadgeBG.hidden = YES;
        [self.contentView addSubview:videoBadgeBG];
        [videoBadgeBG addSubview:_videoBadge];

        _favoriteBadge = [[UIImageView alloc] initWithFrame:CGRectZero];
        _favoriteBadge.translatesAutoresizingMaskIntoConstraints = NO;
        UIImageSymbolConfiguration *favCfg = [UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightBold];
        UIImage *favImg = [SCIUtils sci_resourceImageNamed:@"heart_filled" template:YES maxPointSize:16];
        if (!favImg) {
            favImg = [UIImage systemImageNamed:@"heart.fill" withConfiguration:favCfg];
        }
        _favoriteBadge.image = favImg;
        _favoriteBadge.contentMode = UIViewContentModeScaleAspectFit;
        _favoriteBadge.tintColor = [UIColor systemPinkColor];
        _favoriteBadge.hidden = YES;
        [self.contentView addSubview:_favoriteBadge];

        [NSLayoutConstraint activateConstraints:@[
            [_thumbnailView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_thumbnailView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [_thumbnailView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_thumbnailView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],

            [videoBadgeBG.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:6],
            [videoBadgeBG.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
            [videoBadgeBG.widthAnchor constraintEqualToConstant:20],
            [videoBadgeBG.heightAnchor constraintEqualToConstant:20],

            [_videoBadge.centerXAnchor constraintEqualToAnchor:videoBadgeBG.centerXAnchor],
            [_videoBadge.centerYAnchor constraintEqualToAnchor:videoBadgeBG.centerYAnchor],

            [_favoriteBadge.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
            [_favoriteBadge.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-6],
            [_favoriteBadge.widthAnchor constraintEqualToConstant:16],
            [_favoriteBadge.heightAnchor constraintEqualToConstant:16],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.thumbnailView.image = nil;
    self.videoBadge.hidden = YES;
    [self.contentView viewWithTag:100].hidden = YES;
    self.favoriteBadge.hidden = YES;
}

- (void)configureWithVaultFile:(SCIVaultFile *)file {
    UIImage *thumb = [SCIVaultFile loadThumbnailForFile:file];
    if (thumb) {
        self.thumbnailView.image = thumb;
    } else {
        self.thumbnailView.image = nil;
        __weak typeof(self) weakSelf = self;
        [SCIVaultFile generateThumbnailForFile:file completion:^(BOOL success) {
            if (success && weakSelf) {
                UIImage *newThumb = [UIImage imageWithContentsOfFile:[file thumbnailPath]];
                if (newThumb) {
                    weakSelf.thumbnailView.image = newThumb;
                }
            }
        }];
    }

    BOOL isVideo = (file.mediaType == SCIVaultMediaTypeVideo);
    self.videoBadge.hidden = !isVideo;
    [self.contentView viewWithTag:100].hidden = !isVideo;

    self.favoriteBadge.hidden = !file.isFavorite;
}

@end
