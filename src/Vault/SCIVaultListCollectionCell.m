#import "SCIVaultListCollectionCell.h"
#import "SCIVaultFile.h"

@interface SCIVaultListCollectionCell ()

@property (nonatomic, strong) SCIVaultFile *file;

@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIImageView *rowTypeIcon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *technicalLabel;
@property (nonatomic, strong) UIView *pillBackground;
@property (nonatomic, strong) UILabel *pillLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIImageView *favoriteIcon;
@property (nonatomic, strong) UIImageView *moreIcon;

@end

@implementation SCIVaultListCollectionCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.contentView.backgroundColor = [UIColor clearColor];

    self.thumbnailView = [[UIImageView alloc] init];
    self.thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    self.thumbnailView.clipsToBounds = YES;
    self.thumbnailView.layer.cornerRadius = 6;
    self.thumbnailView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [self.contentView addSubview:self.thumbnailView];

    self.rowTypeIcon = [[UIImageView alloc] init];
    self.rowTypeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.rowTypeIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.rowTypeIcon.tintColor = [UIColor secondaryLabelColor];
    [self.contentView addSubview:self.rowTypeIcon];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.titleLabel];

    self.technicalLabel = [[UILabel alloc] init];
    self.technicalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.technicalLabel.font = [UIFont systemFontOfSize:12];
    self.technicalLabel.textColor = [UIColor secondaryLabelColor];
    self.technicalLabel.numberOfLines = 1;
    self.technicalLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.technicalLabel];

    self.pillBackground = [[UIView alloc] init];
    self.pillBackground.translatesAutoresizingMaskIntoConstraints = NO;
    self.pillBackground.backgroundColor = [UIColor tertiarySystemFillColor];
    self.pillBackground.layer.cornerRadius = 5;
    self.pillBackground.clipsToBounds = YES;
    [self.contentView addSubview:self.pillBackground];

    self.pillLabel = [[UILabel alloc] init];
    self.pillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.pillLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    self.pillLabel.textColor = [UIColor secondaryLabelColor];
    self.pillLabel.numberOfLines = 1;
    [self.pillBackground addSubview:self.pillLabel];

    self.dateLabel = [[UILabel alloc] init];
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.font = [UIFont systemFontOfSize:11];
    self.dateLabel.textColor = [UIColor tertiaryLabelColor];
    self.dateLabel.numberOfLines = 1;
    self.dateLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.dateLabel];

    UIImageSymbolConfiguration *favCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
    self.favoriteIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.fill" withConfiguration:favCfg]];
    self.favoriteIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.favoriteIcon.tintColor = [UIColor systemPinkColor];
    self.favoriteIcon.hidden = YES;
    [self.contentView addSubview:self.favoriteIcon];

    UIImageSymbolConfiguration *moreCfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
    self.moreIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis" withConfiguration:moreCfg]];
    self.moreIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.moreIcon.tintColor = [UIColor tertiaryLabelColor];
    [self.contentView addSubview:self.moreIcon];

    UILayoutGuide *margin = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.thumbnailView.leadingAnchor constraintEqualToAnchor:margin.leadingAnchor constant:8],
        [self.thumbnailView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.thumbnailView.widthAnchor constraintEqualToConstant:56],
        [self.thumbnailView.heightAnchor constraintEqualToConstant:56],

        [self.moreIcon.trailingAnchor constraintEqualToAnchor:margin.trailingAnchor constant:-4],
        [self.moreIcon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:12],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.thumbnailView.topAnchor constant:-1],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.favoriteIcon.leadingAnchor constant:-4],

        [self.rowTypeIcon.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.rowTypeIcon.centerYAnchor constraintEqualToAnchor:self.technicalLabel.centerYAnchor],
        [self.rowTypeIcon.widthAnchor constraintEqualToConstant:14],
        [self.rowTypeIcon.heightAnchor constraintEqualToConstant:14],

        [self.technicalLabel.leadingAnchor constraintEqualToAnchor:self.rowTypeIcon.trailingAnchor constant:4],
        [self.technicalLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3],
        [self.technicalLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.moreIcon.leadingAnchor constant:-8],

        [self.pillBackground.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.pillBackground.topAnchor constraintEqualToAnchor:self.technicalLabel.bottomAnchor constant:4],
        [self.pillLabel.leadingAnchor constraintEqualToAnchor:self.pillBackground.leadingAnchor constant:8],
        [self.pillLabel.trailingAnchor constraintEqualToAnchor:self.pillBackground.trailingAnchor constant:-8],
        [self.pillLabel.topAnchor constraintEqualToAnchor:self.pillBackground.topAnchor constant:3],
        [self.pillLabel.bottomAnchor constraintEqualToAnchor:self.pillBackground.bottomAnchor constant:-3],

        [self.dateLabel.leadingAnchor constraintEqualToAnchor:self.pillBackground.trailingAnchor constant:8],
        [self.dateLabel.centerYAnchor constraintEqualToAnchor:self.pillBackground.centerYAnchor],
        [self.dateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.moreIcon.leadingAnchor constant:-8],

        [self.favoriteIcon.trailingAnchor constraintEqualToAnchor:self.moreIcon.leadingAnchor constant:-6],
        [self.favoriteIcon.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
    ]];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.thumbnailView.image = nil;
    self.titleLabel.text = nil;
    self.technicalLabel.text = nil;
    self.pillLabel.text = nil;
    self.dateLabel.text = nil;
    self.favoriteIcon.hidden = YES;
    self.file = nil;
}

- (void)configureWithVaultFile:(SCIVaultFile *)file {
    self.file = file;
    self.titleLabel.text = [file listPrimaryTitle];
    self.technicalLabel.text = [file listTechnicalLine];
    self.pillLabel.text = [file shortSourceLabel];
    self.dateLabel.text = [file listDownloadDateString];

    BOOL isVideo = (file.mediaType == SCIVaultMediaTypeVideo);
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium];
    self.rowTypeIcon.image = [UIImage systemImageNamed:(isVideo ? @"video.fill" : @"photo.fill") withConfiguration:cfg];

    self.favoriteIcon.hidden = !file.isFavorite;

    UIImage *thumb = [SCIVaultFile loadThumbnailForFile:file];
    if (thumb) {
        self.thumbnailView.image = thumb;
    } else {
        __weak typeof(self) weakSelf = self;
        [SCIVaultFile generateThumbnailForFile:file completion:^(BOOL ok) {
            if (!ok) return;
            if (weakSelf.file != file) return;
            UIImage *img = [SCIVaultFile loadThumbnailForFile:file];
            if (img) weakSelf.thumbnailView.image = img;
        }];
    }
}

@end
