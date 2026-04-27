// Story Mentions — Vault-style bottom sheet listing mentioned users with Follow/Following buttons.
// Triggered by the @ button in story overlays (SeenButtons.x).

#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Networking/SCIInstagramAPI.h"
#import "../../Shared/UI/SCIMediaChrome.h"
#import <objc/runtime.h>
#import <objc/message.h>

// ============ User PK extraction ============

// IGUser stores fields in a Pando-backed dictionary (_fieldCache).
// Standard KVC may return NSNull, so we read the dict directly.
static id SCIMentionFieldCacheValue(id obj, NSString *key) {
    if (!obj || !key) return nil;
    static Ivar fcIvar = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class c = NSClassFromString(@"IGAPIStorableObject");
        if (c) fcIvar = class_getInstanceVariable(c, "_fieldCache");
    });
    if (!fcIvar) return nil;
    NSDictionary *fc = object_getIvar(obj, fcIvar);
    if (!fc || ![fc isKindOfClass:[NSDictionary class]]) return nil;
    id val = fc[key];
    if (!val || [val isKindOfClass:[NSNull class]]) return nil;
    return val;
}

static NSString *SCIMentionUserPK(id userObj) {
    if (!userObj) return nil;
    id pk = SCIMentionFieldCacheValue(userObj, @"strong_id__");
    if (!pk) pk = SCIMentionFieldCacheValue(userObj, @"pk");
    if (!pk) {
        @try {
            Ivar pkIvar = class_getInstanceVariable([userObj class], "_pk");
            if (pkIvar) pk = object_getIvar(userObj, pkIvar);
        } @catch (__unused id e) {}
    }
    return pk ? [NSString stringWithFormat:@"%@", pk] : nil;
}

static void SCIMentionStyleFollowButton(UIButton *btn, BOOL following) {
    [btn setTitle:following ? @"Following" : @"Follow" forState:UIControlStateNormal];
    btn.backgroundColor = following
        ? [SCIUtils SCIColor_InstagramPressedBackground]
        : [SCIUtils SCIColor_Primary];
    UIColor *titleColor = following
        ? [UIColor greenColor]
        : [SCIUtils SCIColor_InstagramPrimaryText];
    [btn setTitleColor:titleColor forState:UIControlStateNormal];
}

// ============ Enhanced mention extraction ============

// Enriched version that also extracts userObj, pk, and profile_pic_url
// (the SeenButtons.x version only extracts username and fullName)
static NSArray<NSDictionary *> *SCIStoryMentionsEnriched(UIView *overlayView) {
    if (!overlayView) return @[];

    // Use the same resolution path as SeenButtons.x
    id media = nil;
    @try {
        // Walk up to find IGStoryViewerViewController or IGStoryItemMediaView
        UIView *v = overlayView;
        for (NSInteger i = 0; i < 25 && v; i++, v = v.superview) {
            // Try the media view first
            SEL mediaSel = NSSelectorFromString(@"media");
            if ([v respondsToSelector:mediaSel]) {
                id candidate = ((id(*)(id,SEL))objc_msgSend)(v, mediaSel);
                if (candidate && [candidate respondsToSelector:NSSelectorFromString(@"reelMentions")]) {
                    media = candidate;
                    break;
                }
            }
        }

        // Fallback: try the view controller hierarchy
        if (!media) {
            UIResponder *r = overlayView;
            while (r) {
                if ([r isKindOfClass:[UIViewController class]]) {
                    UIViewController *vc = (UIViewController *)r;
                    // Try currentStoryItem
                    SEL csi = NSSelectorFromString(@"currentStoryItem");
                    if ([vc respondsToSelector:csi]) {
                        id item = ((id(*)(id,SEL))objc_msgSend)(vc, csi);
                        if ([item respondsToSelector:NSSelectorFromString(@"reelMentions")]) {
                            media = item;
                            break;
                        }
                    }
                    // Try currentItem
                    SEL ci = NSSelectorFromString(@"currentItem");
                    if ([vc respondsToSelector:ci]) {
                        id item = ((id(*)(id,SEL))objc_msgSend)(vc, ci);
                        if ([item respondsToSelector:NSSelectorFromString(@"reelMentions")]) {
                            media = item;
                            break;
                        }
                    }
                }
                r = r.nextResponder;
            }
        }
    } @catch (__unused id e) {}

    if (!media) return @[];

    SEL mentionsSel = NSSelectorFromString(@"reelMentions");
    if (![media respondsToSelector:mentionsSel]) return @[];
    id mentionsCollection = ((id(*)(id,SEL))objc_msgSend)(media, mentionsSel);

    NSArray *mentions = nil;
    if ([mentionsCollection isKindOfClass:[NSArray class]]) {
        mentions = (NSArray *)mentionsCollection;
    } else if ([mentionsCollection isKindOfClass:[NSSet class]]) {
        mentions = [(NSSet *)mentionsCollection allObjects];
    } else if ([mentionsCollection isKindOfClass:[NSOrderedSet class]]) {
        mentions = [(NSOrderedSet *)mentionsCollection array];
    }
    if (mentions.count == 0) return @[];

    NSMutableArray<NSDictionary *> *userInfos = [NSMutableArray array];
    for (id mention in mentions) {
        id user = nil;
        @try { user = [mention valueForKey:@"user"]; } @catch (__unused id e) {}
        if (!user) continue;

        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[@"userObj"] = user;

        NSString *username = SCIMentionFieldCacheValue(user, @"username");
        if (username.length) info[@"username"] = username;

        NSString *fullName = SCIMentionFieldCacheValue(user, @"full_name");
        if (fullName.length) info[@"fullName"] = fullName;

        NSString *picStr = SCIMentionFieldCacheValue(user, @"profile_pic_url");
        if (picStr.length) {
            NSURL *picURL = [NSURL URLWithString:picStr];
            if (picURL) info[@"picURL"] = picURL;
        }

        if (info.count > 1) [userInfos addObject:info]; // must have userObj + at least one other field
    }
    return userInfos;
}

// ============ Bottom sheet VC ============

#define kSCIMentionAvatarSize 52.0
#define kSCIMentionRowHeight  72.0
#define kSCIMentionRowInset   16.0
#define kSCIMentionRowCornerRadius 12.0

@interface SCIStoryMentionsVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray<NSDictionary *> *userInfos;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSString *currentUsername;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *friendshipStatuses;
@property (nonatomic, weak) UIView *storyOverlayView; // for resuming playback on dismiss
@end

@implementation SCIStoryMentionsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramBackground];
    self.title = @"Mentions";

    // Resolve current user to hide the Follow button for yourself
    @try {
        id window = [[UIApplication sharedApplication] keyWindow];
        if ([window respondsToSelector:@selector(userSession)])
            self.currentUsername = ((IGUserSession *)[window valueForKey:@"userSession"]).user.username;
    } @catch (__unused id e) {}

    // Table view
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = kSCIMentionRowHeight;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 12, 0);
    self.tableView.showsVerticalScrollIndicator = NO;

    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Bulk-fetch friendship statuses in one round trip
    self.friendshipStatuses = [NSMutableDictionary dictionary];
    NSMutableArray *pks = [NSMutableArray array];
    for (NSDictionary *info in self.userInfos) {
        NSString *pk = SCIMentionUserPK(info[@"userObj"]);
        if (pk.length) [pks addObject:pk];
    }
    if (pks.count) {
        __weak typeof(self) weakSelf = self;
        [SCIInstagramAPI fetchFriendshipStatusesForPKs:pks completion:^(NSDictionary *statuses, NSError *error) {
            if (!statuses.count) return;
            [weakSelf.friendshipStatuses addEntriesFromDictionary:statuses];
            [weakSelf.tableView reloadData];
        }];
    }

    // Empty state
    if (self.userInfos.count == 0) {
        UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:[SCIUtils sci_resourceImageNamed:@"mention" template:YES]];
        emptyIcon.tintColor = [SCIUtils SCIColor_InstagramTertiaryText];
        emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = @"No mentions in this story";
        emptyLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        emptyLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;

        UIStackView *empty = [[UIStackView alloc] initWithArrangedSubviews:@[emptyIcon, emptyLabel]];
        empty.axis = UILayoutConstraintAxisVertical;
        empty.spacing = 12;
        empty.alignment = UIStackViewAlignmentCenter;
        empty.translatesAutoresizingMaskIntoConstraints = NO;

        [self.view addSubview:empty];
        [NSLayoutConstraint activateConstraints:@[
            [empty.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
            [empty.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor],
        ]];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController) {
        SCIApplyMediaChromeNavigationBar(self.navigationController.navigationBar);
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // Resume story playback when mentions sheet is dismissed
    if (!self.storyOverlayView) return;
    UIResponder *r = self.storyOverlayView;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            SEL sel = NSSelectorFromString(@"tryResumePlayback");
            if ([r respondsToSelector:sel]) {
                ((void(*)(id,SEL))objc_msgSend)(r, sel);
                break;
            }
        }
        r = r.nextResponder;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.userInfos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *rid = @"SCIMention";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];

    UIImageView *avatar;
    UILabel *nameLabel, *subLabel;
    UIButton *followBtn;
    UIActivityIndicatorView *spinner;
    UIView *cardView;
    static const NSInteger kCdTag = 200, kAvTag = 201, kNmTag = 202, kSbTag = 203, kFlTag = 204, kSpTag = 205;

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
        cell.backgroundColor = [UIColor clearColor];
        cell.contentView.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        cardView = [[UIView alloc] init];
        cardView.tag = kCdTag;
        cardView.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
        cardView.layer.cornerRadius = kSCIMentionRowCornerRadius;
        cardView.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:cardView];

        avatar = [[UIImageView alloc] init];
        avatar.tag = kAvTag;
        avatar.layer.cornerRadius = kSCIMentionAvatarSize / 2.0;
        avatar.clipsToBounds = YES;
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        avatar.backgroundColor = [SCIUtils SCIColor_InstagramSeparator];
        avatar.translatesAutoresizingMaskIntoConstraints = NO;

        nameLabel = [[UILabel alloc] init];
        nameLabel.tag = kNmTag;
        nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        nameLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
        nameLabel.translatesAutoresizingMaskIntoConstraints = NO;

        subLabel = [[UILabel alloc] init];
        subLabel.tag = kSbTag;
        subLabel.font = [UIFont systemFontOfSize:14];
        subLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
        subLabel.translatesAutoresizingMaskIntoConstraints = NO;

        followBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        followBtn.tag = kFlTag;
        followBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        followBtn.layer.cornerRadius = 12;
        followBtn.clipsToBounds = YES;
        followBtn.translatesAutoresizingMaskIntoConstraints = NO;

        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        spinner.tag = kSpTag;
        spinner.hidesWhenStopped = YES;
        spinner.translatesAutoresizingMaskIntoConstraints = NO;

        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[nameLabel, subLabel]];
        text.axis = UILayoutConstraintAxisVertical;
        text.spacing = 2;
        text.translatesAutoresizingMaskIntoConstraints = NO;

        [cardView addSubview:avatar];
        [cardView addSubview:text];
        [cardView addSubview:followBtn];
        [followBtn addSubview:spinner];

        [NSLayoutConstraint activateConstraints:@[
            [cardView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],
            [cardView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:kSCIMentionRowInset],
            [cardView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-kSCIMentionRowInset],
            [cardView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4],
            [avatar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:16],
            [avatar.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
            [avatar.widthAnchor constraintEqualToConstant:kSCIMentionAvatarSize],
            [avatar.heightAnchor constraintEqualToConstant:kSCIMentionAvatarSize],
            [text.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:14],
            [text.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
            [text.trailingAnchor constraintLessThanOrEqualToAnchor:followBtn.leadingAnchor constant:-10],
            [followBtn.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-12],
            [followBtn.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
            [followBtn.widthAnchor constraintGreaterThanOrEqualToConstant:90],
            [followBtn.heightAnchor constraintEqualToConstant:32],
            [spinner.centerXAnchor constraintEqualToAnchor:followBtn.centerXAnchor],
            [spinner.centerYAnchor constraintEqualToAnchor:followBtn.centerYAnchor],
        ]];
    } else {
        cardView   = [cell.contentView viewWithTag:kCdTag];
        avatar    = [cell.contentView viewWithTag:kAvTag];
        nameLabel = [cell.contentView viewWithTag:kNmTag];
        subLabel  = [cell.contentView viewWithTag:kSbTag];
        followBtn = [cell.contentView viewWithTag:kFlTag];
        spinner   = [followBtn viewWithTag:kSpTag];
    }

    cardView.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];

    NSDictionary *info = self.userInfos[indexPath.row];
    NSString *username = info[@"username"] ?: @"Unknown";
    NSString *fullName = info[@"fullName"];
    NSURL *picURL = info[@"picURL"];

    nameLabel.text = username;
    subLabel.text = fullName ?: @"";
    subLabel.hidden = !fullName.length;

    // Default avatar
    avatar.image = [SCIUtils sci_resourceImageNamed:@"profile" template:YES];
    avatar.tintColor = [SCIUtils SCIColor_InstagramTertiaryText];

    // Async avatar fetch
    if (picURL) {
        NSURL *url = [picURL copy];
        NSInteger row = indexPath.row;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (!data) return;
            UIImage *img = [UIImage imageWithData:data];
            if (!img) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                UITableViewCell *c = [tableView cellForRowAtIndexPath:
                    [NSIndexPath indexPathForRow:row inSection:0]];
                if (!c) return;
                UIImageView *av = [c.contentView viewWithTag:kAvTag];
                if (av) { av.image = img; av.tintColor = nil; }
            });
        });
    }

    // Follow button state
    [followBtn removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [spinner stopAnimating];
    spinner.color = [UIColor whiteColor];

    BOOL isMe = self.currentUsername && [username isEqualToString:self.currentUsername];
    if (isMe) {
        followBtn.hidden = YES;
    } else {
        followBtn.hidden = NO;
        id userObj = info[@"userObj"];

        BOOL following = NO;
        NSString *pk = SCIMentionUserPK(userObj);
        NSDictionary *status = pk ? self.friendshipStatuses[pk] : nil;
        if ([status isKindOfClass:[NSDictionary class]]) {
            following = [status[@"following"] boolValue];
        }
        SCIMentionStyleFollowButton(followBtn, following);

        objc_setAssociatedObject(followBtn, "userObj", userObj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [followBtn addTarget:self action:@selector(sci_followTapped:) forControlEvents:UIControlEventTouchUpInside];
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 4.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor clearColor];
    return view;
}

#pragma mark - Follow/Unfollow

- (void)sci_followTapped:(UIButton *)sender {
    id userObj = objc_getAssociatedObject(sender, "userObj");
    if (!userObj) return;
    NSString *pk = SCIMentionUserPK(userObj);
    if (!pk.length) return;

    BOOL currentlyFollowing = [[sender titleForState:UIControlStateNormal] isEqualToString:@"Following"];

    void (^doIt)(void) = ^{
        UIActivityIndicatorView *spinner = [sender viewWithTag:205];
        NSString *savedTitle = [sender titleForState:UIControlStateNormal];
        [sender setTitle:@"" forState:UIControlStateNormal];
        sender.userInteractionEnabled = NO;
        [spinner startAnimating];

        __weak typeof(self) weakSelf = self;
        SCIAPICompletion done = ^(NSDictionary *response, NSError *error) {
            [spinner stopAnimating];
            sender.userInteractionEnabled = YES;
            BOOL ok = (response && [response[@"status"] isEqualToString:@"ok"]);
            if (ok) {
                SCIMentionStyleFollowButton(sender, !currentlyFollowing);
                NSMutableDictionary *s = [weakSelf.friendshipStatuses[pk] mutableCopy] ?: [NSMutableDictionary dictionary];
                s[@"following"] = @(!currentlyFollowing);
                weakSelf.friendshipStatuses[pk] = [s copy];
            } else {
                [sender setTitle:savedTitle forState:UIControlStateNormal];
            }
        };

        if (currentlyFollowing) [SCIInstagramAPI unfollowUserPK:pk completion:done];
        else                    [SCIInstagramAPI followUserPK:pk   completion:done];
    };

    if (!currentlyFollowing && [SCIUtils getBoolPref:@"follow_confirm"]) {
        [SCIUtils showConfirmation:doIt];
    } else if (currentlyFollowing && [SCIUtils getBoolPref:@"unfollow_confirm"]) {
        [SCIUtils showConfirmation:doIt title:@"Unfollow?"];
    } else {
        doIt();
    }
}

#pragma mark - Row tap → open profile

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *info = self.userInfos[indexPath.row];
    NSString *username = info[@"username"];
    if (!username) return;
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
        NSString *encodedUsername = [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        if (!encodedUsername.length) return;
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"instagram://user?username=%@", encodedUsername]];
        if (url && [[UIApplication sharedApplication] canOpenURL:url])
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }];
}

@end

// ============ Presentation entry point ============

extern void SCIPauseStoryPlaybackFromOverlaySubview(UIView *);
extern void SCIResumeStoryPlaybackFromOverlaySubview(UIView *);

@interface SCIStoryMentionsVC (StoryPlayback)
@end

@implementation SCIStoryMentionsVC (StoryPlayback)

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.storyOverlayView) {
        SCIResumeStoryPlaybackFromOverlaySubview(self.storyOverlayView);
    }
}

@end

void SCIPresentStoryMentionsSheet(UIView *overlayView) {
    NSArray<NSDictionary *> *enriched = SCIStoryMentionsEnriched(overlayView);

    // If no enriched data, still show the sheet with empty state
    UIViewController *presenter = [SCIUtils nearestViewControllerForView:overlayView];
    if (!presenter) return;
    
    SCIPauseStoryPlaybackFromOverlaySubview(overlayView);

    SCIStoryMentionsVC *vc = [[SCIStoryMentionsVC alloc] init];
    vc.userInfos = enriched;
    vc.storyOverlayView = overlayView;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;

    // if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;

        // Custom compact detent: sized to fit a small number of rows (header + rows + bottom inset)
        // CGFloat headerHeight = 58.0; // title + separator
        // CGFloat contentHeight = MIN(enriched.count, 4) * kSCIMentionRowHeight; // up to 4 rows compact
        // if (enriched.count == 0) contentHeight = 120.0; // empty state
        // CGFloat compactHeight = headerHeight + contentHeight + 34.0; // bottom safe area

        // if (@available(iOS 16.0, *)) {
        //     UISheetPresentationControllerDetent *compactDetent =
        //         [UISheetPresentationControllerDetent customDetentWithIdentifier:@"compact"
        //                                                               resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> ctx) {
        //             return MIN(compactHeight, ctx.maximumDetentValue * 0.9);
        //         }];
        //     sheet.detents = @[compactDetent, UISheetPresentationControllerDetent.largeDetent];
        // } else {
            sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent];
        // }

        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        sheet.prefersEdgeAttachedInCompactHeight = YES;
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = YES;
        if (@available(iOS 15.0, *)) {
            sheet.prefersGrabberVisible = YES;
        }
    // }

    [presenter presentViewController:nav animated:YES completion:nil];
}
