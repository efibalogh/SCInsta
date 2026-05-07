#import "SCIGalleryImportMetadataFormViewController.h"

#import "SCIGallerySaveMetadata.h"
#import "SCIGalleryFile.h"
#import "SCIGalleryOriginController.h"
#import "../../Utils.h"

typedef NS_ENUM(NSInteger, SCIGalleryImportFormRow) {
    SCIGalleryImportFormRowDisplayName = 0,
    SCIGalleryImportFormRowFileStem,
    SCIGalleryImportFormRowSource,
    SCIGalleryImportFormRowUsername,
    SCIGalleryImportFormRowUserPK,
    SCIGalleryImportFormRowProfileURL,
    SCIGalleryImportFormRowMediaPK,
    SCIGalleryImportFormRowMediaCode,
    SCIGalleryImportFormRowMediaURL,
    SCIGalleryImportFormRowPixelWidth,
    SCIGalleryImportFormRowPixelHeight,
    SCIGalleryImportFormRowDuration,
    SCIGalleryImportFormRowGallerySortDate,
    SCIGalleryImportFormRowCount
};

static NSString *SCIFormFormattedGallerySortDate(NSDate * _Nullable date) {
    if (!date) {
        return @"";
    }
    static NSDateFormatter *fmt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateStyle = NSDateFormatterMediumStyle;
        fmt.timeStyle = NSDateFormatterShortStyle;
    });
    return [fmt stringFromDate:date];
}

static NSDate * _Nullable SCIFormParsedGallerySortDate(NSString *raw) {
    NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) {
        return nil;
    }
    static NSArray<NSDateFormatter *> *formatters;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSString *> *patterns = @[
            @"yyyy-MM-dd HH:mm:ss",
            @"yyyy-MM-dd HH:mm",
            @"yyyy-MM-dd",
            @"yyyyMMddHHmmss",
            @"yyyyMMddHHmm",
            @"yyyyMMdd",
        ];
        NSMutableArray<NSDateFormatter *> *a = [NSMutableArray array];
        for (NSString *pat in patterns) {
            NSDateFormatter *f = [[NSDateFormatter alloc] init];
            f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            f.timeZone = [NSTimeZone localTimeZone];
            f.dateFormat = pat;
            [a addObject:f];
        }
        formatters = a;
    });
    for (NSDateFormatter *f in formatters) {
        NSDate *d = [f dateFromString:s];
        if (d) {
            return d;
        }
    }
    return nil;
}

@interface SCIGalleryImportMetadataFormViewController () <UITextFieldDelegate>
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UITextField *> *textFields;
@property (nonatomic, strong) UIButton *sourceMenuButton;
@end

@implementation SCIGalleryImportMetadataFormViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
    self.textFields = [NSMutableDictionary dictionary];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return SCIGalleryImportFormRowCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return [self titleForRow:(SCIGalleryImportFormRow)section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (self.footerStemExplanation.length > 0 && section == SCIGalleryImportFormRowFileStem) {
        return self.footerStemExplanation;
    }
    return [self footerTextForRow:(SCIGalleryImportFormRow)section];
}

- (NSString *)titleForRow:(SCIGalleryImportFormRow)row {
    switch (row) {
        case SCIGalleryImportFormRowDisplayName: return @"Display name";
        case SCIGalleryImportFormRowFileStem: return @"File name key";
        case SCIGalleryImportFormRowSource: return @"Source";
        case SCIGalleryImportFormRowUsername: return @"Username";
        case SCIGalleryImportFormRowUserPK: return @"User id (pk)";
        case SCIGalleryImportFormRowProfileURL: return @"Profile URL";
        case SCIGalleryImportFormRowMediaPK: return @"Media id (pk)";
        case SCIGalleryImportFormRowMediaCode: return @"Shortcode";
        case SCIGalleryImportFormRowMediaURL: return @"Permalink URL";
        case SCIGalleryImportFormRowPixelWidth: return @"Width (px)";
        case SCIGalleryImportFormRowPixelHeight: return @"Height (px)";
        case SCIGalleryImportFormRowDuration: return @"Duration (seconds)";
        case SCIGalleryImportFormRowGallerySortDate: return @"Gallery date";
        default: return @"";
    }
}

- (NSString *)footerTextForRow:(SCIGalleryImportFormRow)row {
    switch (row) {
        case SCIGalleryImportFormRowDisplayName:
            return @"Optional label shown in the gallery list instead of the file name.";
        case SCIGalleryImportFormRowFileStem:
            return @"Used only in the saved filename when the imported name is useless (UUID, generic export). Not Instagram’s shortcode — use Shortcode below for posts.";
        case SCIGalleryImportFormRowSource:
            return @"Feed, Story, Reels, etc. Choosing Reels makes shortcode open as /reel/…; Feed uses /p/… when building a link from shortcode.";
        case SCIGalleryImportFormRowUsername:
            return @"Account handle without @. Used for Open profile and, if Profile URL is empty, to fill an instagram:// profile link.";
        case SCIGalleryImportFormRowUserPK:
            return @"Numeric Instagram user id when you have it (some tweaks export this).";
        case SCIGalleryImportFormRowProfileURL:
            return @"https or instagram:// profile link. Open profile uses this or Username.";
        case SCIGalleryImportFormRowMediaPK:
            return @"Numeric media id. Used as fallback to open the post when permalink is missing.";
        case SCIGalleryImportFormRowMediaCode:
            return @"The code in the URL (e.g. ABCde123). With Permalink empty, Open original can build https://instagram.com/p/ or /reel/ from Source + shortcode.";
        case SCIGalleryImportFormRowMediaURL:
            return @"Full post URL (https or instagram://). Prefer this when you copied a share link from Instagram.";
        case SCIGalleryImportFormRowPixelWidth:
        case SCIGalleryImportFormRowPixelHeight:
            return @"Leave empty to detect from the file. Override only if probing is wrong.";
        case SCIGalleryImportFormRowDuration:
            return @"Video length in seconds. Leave empty to probe; override for broken files.";
        case SCIGalleryImportFormRowGallerySortDate:
            return @"Used for the gallery “downloaded” line and sorting. In tweak-style names, we prefer a leading epoch token (save-time), and fall back to trailing compact digits when needed. Clear to use the device import time.";
        default:
            return @"";
    }
}

- (NSString *)stringValueForRow:(SCIGalleryImportFormRow)row {
    SCIGallerySaveMetadata *m = self.metadata;
    switch (row) {
        case SCIGalleryImportFormRowDisplayName: return m.customName ?: @"";
        case SCIGalleryImportFormRowFileStem: return m.importFileNameStem ?: @"";
        case SCIGalleryImportFormRowUsername: return m.sourceUsername ?: @"";
        case SCIGalleryImportFormRowUserPK: return m.sourceUserPK ?: @"";
        case SCIGalleryImportFormRowProfileURL: return m.sourceProfileURLString ?: @"";
        case SCIGalleryImportFormRowMediaPK: return m.sourceMediaPK ?: @"";
        case SCIGalleryImportFormRowMediaCode: return m.sourceMediaCode ?: @"";
        case SCIGalleryImportFormRowMediaURL: return m.sourceMediaURLString ?: @"";
        case SCIGalleryImportFormRowPixelWidth: return m.pixelWidth > 0 ? [NSString stringWithFormat:@"%d", (int)m.pixelWidth] : @"";
        case SCIGalleryImportFormRowPixelHeight: return m.pixelHeight > 0 ? [NSString stringWithFormat:@"%d", (int)m.pixelHeight] : @"";
        case SCIGalleryImportFormRowDuration: return m.durationSeconds > 0.05 ? [NSString stringWithFormat:@"%.3f", m.durationSeconds] : @"";
        case SCIGalleryImportFormRowGallerySortDate: return SCIFormFormattedGallerySortDate(m.importCapturedDate);
        default: return @"";
    }
}

- (void)applyString:(NSString *)value forRow:(SCIGalleryImportFormRow)row {
    NSString *t = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    SCIGallerySaveMetadata *m = self.metadata;
    switch (row) {
        case SCIGalleryImportFormRowDisplayName:
            m.customName = t.length ? t : nil;
            break;
        case SCIGalleryImportFormRowFileStem:
            m.importFileNameStem = t.length ? t : nil;
            break;
        case SCIGalleryImportFormRowUsername: {
            m.sourceUsername = t.length ? t : nil;
            if (t.length > 0) {
                [SCIGalleryOriginController populateProfileMetadata:m username:t user:nil];
            }
            break;
        }
        case SCIGalleryImportFormRowUserPK:
            m.sourceUserPK = t.length ? t : nil;
            break;
        case SCIGalleryImportFormRowProfileURL:
            m.sourceProfileURLString = t.length ? t : nil;
            break;
        case SCIGalleryImportFormRowMediaPK:
            m.sourceMediaPK = t.length ? t : nil;
            break;
        case SCIGalleryImportFormRowMediaCode:
            m.sourceMediaCode = t.length ? t : nil;
            break;
        case SCIGalleryImportFormRowMediaURL:
            m.sourceMediaURLString = t.length ? t : nil;
            break;
        case SCIGalleryImportFormRowPixelWidth:
            m.pixelWidth = t.length ? (int32_t)[t intValue] : 0;
            break;
        case SCIGalleryImportFormRowPixelHeight:
            m.pixelHeight = t.length ? (int32_t)[t intValue] : 0;
            break;
        case SCIGalleryImportFormRowDuration:
            m.durationSeconds = t.length ? [t doubleValue] : 0;
            break;
        case SCIGalleryImportFormRowGallerySortDate:
            m.importCapturedDate = t.length ? SCIFormParsedGallerySortDate(t) : nil;
            break;
        default:
            break;
    }
}

- (UIMenu *)menuForSourceSelection {
    NSMutableArray<UIAction *> *actions = [NSMutableArray array];
    NSArray<NSNumber *> *sources = @[
        @(SCIGallerySourceFeed), @(SCIGallerySourceStories), @(SCIGallerySourceReels),
        @(SCIGallerySourceProfile), @(SCIGallerySourceDMs), @(SCIGallerySourceThumbnail), @(SCIGallerySourceOther)
    ];
    for (NSNumber *num in sources) {
        SCIGallerySource src = (SCIGallerySource)num.intValue;
        NSString *title = [SCIGalleryFile labelForSource:src];
        BOOL checked = ((SCIGallerySource)self.metadata.source == src);
        UIAction *a = [UIAction actionWithTitle:title
                                          image:nil
                                     identifier:nil
                                        handler:^(__unused UIAction *action) {
            self.metadata.source = (int16_t)src;
            [self.sourceMenuButton setTitle:[SCIGalleryFile labelForSource:src] forState:UIControlStateNormal];
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:SCIGalleryImportFormRowSource] withRowAnimation:UITableViewRowAnimationNone];
        }];
        a.state = checked ? UIMenuElementStateOn : UIMenuElementStateOff;
        [actions addObject:a];
    }
    return [UIMenu menuWithTitle:@"" children:actions];
}

- (UITableViewCell *)sourceSelectionCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:[SCIGalleryFile labelForSource:(SCIGallerySource)self.metadata.source] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [btn setTitleColor:[SCIUtils SCIColor_InstagramPrimaryText] forState:UIControlStateNormal];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    btn.menu = [self menuForSourceSelection];
    btn.showsMenuAsPrimaryAction = YES;
    self.sourceMenuButton = btn;

    [cell.contentView addSubview:btn];
    UILayoutGuide *g = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:g.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],
        [cell.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];

    return cell;
}

- (UITableViewCell *)textFieldCellForSection:(NSInteger)section row:(SCIGalleryImportFormRow)row {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];

    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectZero];
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    tf.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    tf.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    tf.text = [self stringValueForRow:row];
    tf.placeholder = @"Optional";
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.delegate = self;
    tf.tag = row;
    tf.userInteractionEnabled = YES;

    if (row == SCIGalleryImportFormRowPixelWidth || row == SCIGalleryImportFormRowPixelHeight) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
    } else if (row == SCIGalleryImportFormRowDuration) {
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    } else if (row == SCIGalleryImportFormRowProfileURL || row == SCIGalleryImportFormRowMediaURL) {
        tf.keyboardType = UIKeyboardTypeURL;
    } else if (row == SCIGalleryImportFormRowGallerySortDate) {
        tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        tf.placeholder = @"e.g. yyyy-MM-dd HH:mm or yyyyMMddHHmmss";
    } else {
        tf.keyboardType = UIKeyboardTypeDefault;
    }

    [cell.contentView addSubview:tf];
    self.textFields[@(section)] = tf;

    UILayoutGuide *g = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [tf.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [tf.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [tf.topAnchor constraintEqualToAnchor:g.topAnchor constant:4],
        [tf.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-4],
        [cell.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];

    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    SCIGalleryImportFormRow row = (SCIGalleryImportFormRow)indexPath.section;
    if (row == SCIGalleryImportFormRowSource) {
        return [self sourceSelectionCell];
    }
    return [self textFieldCellForSection:indexPath.section row:row];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self applyString:textField.text forRow:(SCIGalleryImportFormRow)textField.tag];
}

@end
