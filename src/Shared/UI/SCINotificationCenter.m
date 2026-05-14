#import "SCINotificationCenter.h"
#import "../../AssetUtils.h"
#import "../../Utils.h"

#define SCI_NOTIF_CONST(name, value) NSString * const name = @value
SCI_NOTIF_CONST(kSCINotificationDownloadLibrary, "download_library");
SCI_NOTIF_CONST(kSCINotificationDownloadShare, "download_share");
SCI_NOTIF_CONST(kSCINotificationCopyDownloadLink, "copy_download_link");
SCI_NOTIF_CONST(kSCINotificationCopyMedia, "copy_media");
SCI_NOTIF_CONST(kSCINotificationDownloadGallery, "download_gallery");
SCI_NOTIF_CONST(kSCINotificationDownloadAllLibrary, "download_all_library");
SCI_NOTIF_CONST(kSCINotificationDownloadAllShare, "download_all_share");
SCI_NOTIF_CONST(kSCINotificationDownloadAllGallery, "download_all_gallery");
SCI_NOTIF_CONST(kSCINotificationDownloadAllClipboard, "download_all_clipboard");
SCI_NOTIF_CONST(kSCINotificationDownloadAllLinks, "download_all_links");
SCI_NOTIF_CONST(kSCINotificationExpand, "expand");
SCI_NOTIF_CONST(kSCINotificationViewThumbnail, "view_thumbnail");
SCI_NOTIF_CONST(kSCINotificationCopyCaption, "copy_caption");
SCI_NOTIF_CONST(kSCINotificationOpenTopicSettings, "open_topic_settings");
SCI_NOTIF_CONST(kSCINotificationRepost, "repost");

SCI_NOTIF_CONST(kSCINotificationStoryMarkSeen, "story_mark_seen");
SCI_NOTIF_CONST(kSCINotificationDirectVisualMarkSeen, "direct_visual_mark_seen");
SCI_NOTIF_CONST(kSCINotificationThreadMessagesMarkSeen, "thread_messages_mark_seen");

SCI_NOTIF_CONST(kSCINotificationProfileCopyInfo, "profile_copy_info");
SCI_NOTIF_CONST(kSCINotificationProfileViewPicture, "profile_view_picture");
SCI_NOTIF_CONST(kSCINotificationProfileSharePicture, "profile_share_picture");
SCI_NOTIF_CONST(kSCINotificationProfileGalleryPicture, "profile_gallery_picture");
SCI_NOTIF_CONST(kSCINotificationProfileOpenSettings, "profile_open_settings");

SCI_NOTIF_CONST(kSCINotificationMediaPreviewSavePhotos, "media_preview_save_photos");
SCI_NOTIF_CONST(kSCINotificationMediaPreviewSaveGallery, "media_preview_save_gallery");
SCI_NOTIF_CONST(kSCINotificationMediaPreviewShare, "media_preview_share");
SCI_NOTIF_CONST(kSCINotificationMediaPreviewCopy, "media_preview_copy");
SCI_NOTIF_CONST(kSCINotificationMediaPreviewDeleteGallery, "media_preview_delete_gallery");
SCI_NOTIF_CONST(kSCINotificationMediaPreviewOpenGallery, "media_preview_open_gallery");

SCI_NOTIF_CONST(kSCINotificationGalleryOpenOriginal, "gallery_open_original");
SCI_NOTIF_CONST(kSCINotificationGalleryOpenProfile, "gallery_open_profile");
SCI_NOTIF_CONST(kSCINotificationGalleryDeleteFile, "gallery_delete_file");
SCI_NOTIF_CONST(kSCINotificationGalleryDeleteSelected, "gallery_delete_selected");
SCI_NOTIF_CONST(kSCINotificationGalleryBulkDelete, "gallery_bulk_delete");
SCI_NOTIF_CONST(kSCINotificationGalleryImport, "gallery_import");

SCI_NOTIF_CONST(kSCINotificationSettingsExport, "settings_export");
SCI_NOTIF_CONST(kSCINotificationSettingsImport, "settings_import");
SCI_NOTIF_CONST(kSCINotificationSettingsClearCache, "settings_clear_cache");
SCI_NOTIF_CONST(kSCINotificationCopyDescription, "copy_description");
SCI_NOTIF_CONST(kSCINotificationShareLongPressCopyLink, "share_long_press_copy_link");
SCI_NOTIF_CONST(kSCINotificationMediaEncodingLogs, "media_encoding_logs");
SCI_NOTIF_CONST(kSCINotificationFlexUnavailable, "flex_unavailable");
#undef SCI_NOTIF_CONST

NSString * const kSCINotificationPillDurationKey = @"notification_pill_duration";
NSString * const kSCINotificationPillGlowEnabledKey = @"notification_pill_glow_enabled";

static NSString * const kSCINotificationPrefix = @"notification_";
static NSString * const kSCINotificationHapticPrefix = @"notification_haptic_";
static CGFloat const kSCINotificationStackSpacing = 8.0;
static CGFloat const kSCINotificationTopMargin = 8.0;
static NSTimeInterval const kSCINotificationInsertDuration = 0.55;
static NSTimeInterval const kSCINotificationDefaultPillDuration = 1.5;
static NSTimeInterval const kSCINotificationMinPillDuration = 0.5;
static NSTimeInterval const kSCINotificationMaxPillDuration = 5.0;
static NSUInteger const kSCINotificationMaxQueuedToasts = 3;

@interface SCINotificationSlot : NSObject
@property (nonatomic, strong) SCINotificationPillView *pill;
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL progress;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation SCINotificationSlot
@end

@interface SCINotificationOverlayRootViewController : UIViewController
@end

@implementation SCINotificationOverlayRootViewController
- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    view.backgroundColor = UIColor.clearColor;
    self.view = view;
}
@end

@interface SCINotificationPassthroughWindow : UIWindow
@end

@implementation SCINotificationPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) return nil;
    return hit;
}
@end

static NSDictionary *SCINotificationItem(NSString *identifier, NSString *title, NSString *iconName) {
    return @{@"identifier": identifier ?: @"", @"title": title ?: @"", @"iconName": iconName ?: @"info"};
}

NSString *SCINotificationDefaultsKey(NSString *identifier) {
    return [kSCINotificationPrefix stringByAppendingString:identifier ?: @""];
}

NSString *SCINotificationHapticDefaultsKey(NSString *identifier) {
    return [kSCINotificationHapticPrefix stringByAppendingString:identifier ?: @""];
}

NSArray<NSDictionary *> *SCINotificationPreferenceSections(void) {
    return @[
        @{@"title": @"Action Buttons", @"items": @[
            SCINotificationItem(kSCINotificationDownloadLibrary, @"Save to Photos", @"download"),
            SCINotificationItem(kSCINotificationDownloadShare, @"Share", @"share"),
            SCINotificationItem(kSCINotificationCopyDownloadLink, @"Copy Download URL", @"link"),
            SCINotificationItem(kSCINotificationCopyMedia, @"Copy Media", @"copy"),
            SCINotificationItem(kSCINotificationDownloadGallery, @"Save to Gallery", @"media"),
            SCINotificationItem(kSCINotificationDownloadAllLibrary, @"Save All to Photos", @"download"),
            SCINotificationItem(kSCINotificationDownloadAllShare, @"Share All", @"share"),
            SCINotificationItem(kSCINotificationDownloadAllGallery, @"Save All to Gallery", @"media"),
            SCINotificationItem(kSCINotificationDownloadAllClipboard, @"Copy All Media", @"copy"),
            SCINotificationItem(kSCINotificationDownloadAllLinks, @"Copy Download URLs", @"link"),
            SCINotificationItem(kSCINotificationExpand, @"Expand", @"expand"),
            SCINotificationItem(kSCINotificationViewThumbnail, @"View Thumbnail", @"photo_gallery"),
            SCINotificationItem(kSCINotificationCopyCaption, @"Copy Caption", @"caption"),
            SCINotificationItem(kSCINotificationOpenTopicSettings, @"Open Topic Settings", @"settings"),
            SCINotificationItem(kSCINotificationRepost, @"Repost", @"repost"),
        ]},
        @{@"title": @"Stories & Messages", @"items": @[
            SCINotificationItem(kSCINotificationStoryMarkSeen, @"Mark Story as Seen", @"story"),
            SCINotificationItem(kSCINotificationDirectVisualMarkSeen, @"Mark Visual Message as Seen", @"messages"),
            SCINotificationItem(kSCINotificationThreadMessagesMarkSeen, @"Mark Messages as Seen", @"messages"),
        ]},
        @{@"title": @"Profile", @"items": @[
            SCINotificationItem(kSCINotificationProfileCopyInfo, @"Copy Profile Info", @"copy"),
            SCINotificationItem(kSCINotificationProfileViewPicture, @"View Picture", @"photo"),
            SCINotificationItem(kSCINotificationProfileSharePicture, @"Share Picture", @"share"),
            SCINotificationItem(kSCINotificationProfileGalleryPicture, @"Save Picture to Gallery", @"media"),
            SCINotificationItem(kSCINotificationProfileOpenSettings, @"Open Profile Settings", @"settings"),
        ]},
        @{@"title": @"Media", @"items": @[
            SCINotificationItem(kSCINotificationMediaPreviewSavePhotos, @"Save to Photos", @"download"),
            SCINotificationItem(kSCINotificationMediaPreviewSaveGallery, @"Save to Gallery", @"media"),
            SCINotificationItem(kSCINotificationMediaPreviewShare, @"Share", @"share"),
            SCINotificationItem(kSCINotificationMediaPreviewCopy, @"Copy Media", @"copy"),
            SCINotificationItem(kSCINotificationMediaPreviewDeleteGallery, @"Delete Media", @"trash"),
            SCINotificationItem(kSCINotificationMediaPreviewOpenGallery, @"Open Media", @"media"),
            SCINotificationItem(kSCINotificationMediaEncodingLogs, @"Encoding Logs", @"caption"),
        ]},
        @{@"title": @"Gallery", @"items": @[
            SCINotificationItem(kSCINotificationGalleryOpenOriginal, @"Open Original Post", @"external_link"),
            SCINotificationItem(kSCINotificationGalleryOpenProfile, @"Open Profile", @"profile"),
            SCINotificationItem(kSCINotificationGalleryDeleteFile, @"Delete File", @"media"),
            SCINotificationItem(kSCINotificationGalleryDeleteSelected, @"Delete Selected Files", @"circle_check"),
            SCINotificationItem(kSCINotificationGalleryBulkDelete, @"Bulk Delete", @"trash"),
            SCINotificationItem(kSCINotificationGalleryImport, @"Import Files", @"arrow_down"),
        ]},
        @{@"title": @"Settings & Tools", @"items": @[
            SCINotificationItem(kSCINotificationSettingsExport, @"Export Settings", @"arrow_up"),
            SCINotificationItem(kSCINotificationSettingsImport, @"Import Settings", @"arrow_down"),
            SCINotificationItem(kSCINotificationSettingsClearCache, @"Clear Cache", @"trash"),
            SCINotificationItem(kSCINotificationCopyDescription, @"Copy Description", @"copy"),
            SCINotificationItem(kSCINotificationShareLongPressCopyLink, @"Long Press Send to Copy Link", @"link"),
            SCINotificationItem(kSCINotificationFlexUnavailable, @"FLEX Unavailable", @"warning"),
        ]},
    ];
}

static BOOL SCINotificationIdentifierIsRegistered(NSString *identifier) {
    if (identifier.length == 0) return NO;
    static NSSet<NSString *> *registeredIdentifiers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
        for (NSDictionary *section in SCINotificationPreferenceSections()) {
            for (NSDictionary *item in section[@"items"] ?: @[]) {
                NSString *itemIdentifier = item[@"identifier"];
                if (itemIdentifier.length > 0) {
                    [identifiers addObject:itemIdentifier];
                }
            }
        }
        registeredIdentifiers = [identifiers copy];
    });
    return [registeredIdentifiers containsObject:identifier];
}

NSDictionary<NSString *, id> *SCINotificationDefaultPreferences(void) {
    NSMutableDictionary *defaults = [@{
        kSCINotificationPillGlowEnabledKey: @YES,
        kSCINotificationPillDurationKey: @(kSCINotificationDefaultPillDuration),
    } mutableCopy];
    for (NSDictionary *section in SCINotificationPreferenceSections()) {
        for (NSDictionary *item in section[@"items"] ?: @[]) {
            defaults[SCINotificationDefaultsKey(item[@"identifier"])] = @YES;
            defaults[SCINotificationHapticDefaultsKey(item[@"identifier"])] = @YES;
        }
    }
    return defaults;
}

BOOL SCINotificationIsEnabled(NSString *identifier) {
    if (!SCINotificationIdentifierIsRegistered(identifier)) return NO;
    return [NSUserDefaults.standardUserDefaults boolForKey:SCINotificationDefaultsKey(identifier)];
}

NSTimeInterval SCINotificationPillDuration(void) {
    NSTimeInterval duration = [NSUserDefaults.standardUserDefaults doubleForKey:kSCINotificationPillDurationKey];
    if (duration <= 0.0) duration = kSCINotificationDefaultPillDuration;
    return MIN(kSCINotificationMaxPillDuration, MAX(kSCINotificationMinPillDuration, duration));
}

void SCINotificationTriggerHaptic(NSString *identifier, SCINotificationTone tone) {
    if (!SCINotificationIdentifierIsRegistered(identifier)) return;
    if ([SCIUtils getBoolPref:@"disable_haptics"]) return;
    if (![NSUserDefaults.standardUserDefaults boolForKey:SCINotificationHapticDefaultsKey(identifier)]) return;

    dispatch_block_t trigger = ^{
        switch (tone) {
            case SCINotificationToneSuccess: {
                UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
                [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
                break;
            }
            case SCINotificationToneError: {
                UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
                [haptic notificationOccurred:UINotificationFeedbackTypeError];
                break;
            }
            case SCINotificationToneInfo:
            default: {
                UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                [haptic impactOccurred];
                break;
            }
        }
    };

    if (NSThread.isMainThread) trigger();
    else dispatch_async(dispatch_get_main_queue(), trigger);
}

SCINotificationTone SCINotificationToneForIconResource(NSString *iconResource) {
    if ([iconResource isEqualToString:@"error_filled"] ||
        [iconResource isEqualToString:@"error_circle_filled"]) return SCINotificationToneError;
    if ([iconResource isEqualToString:@"circle_check_filled"] ||
        [iconResource isEqualToString:@"copy_filled"]) {
        return SCINotificationToneSuccess;
    }
    return SCINotificationToneInfo;
}

static NSString *SCINotificationIconResourceForTone(NSString *iconResource, SCINotificationTone tone) {
    switch (tone) {
        case SCINotificationToneSuccess:
            return @"circle_check_filled";
        case SCINotificationToneError:
            return @"error_filled";
        case SCINotificationToneInfo:
        default:
            return iconResource.length ? iconResource : @"info_filled";
    }
}

@interface SCINotificationCenter ()
@property (nonatomic, strong) NSMutableArray<SCINotificationSlot *> *visible;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *queue;
@property (nonatomic, strong) SCINotificationPassthroughWindow *overlayWindow;
@property (nonatomic, strong) SCINotificationOverlayRootViewController *overlayRoot;
- (void)notifyIdentifier:(NSString *)identifier
                   title:(NSString *)title
                subtitle:(NSString *)subtitle
            iconResource:(NSString *)iconResource
                    tone:(SCINotificationTone)tone
           triggerHaptic:(BOOL)triggerHaptic;
@end

@implementation SCINotificationCenter

+ (instancetype)shared {
    static SCINotificationCenter *center;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [SCINotificationCenter new];
    });
    return center;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _visible = [NSMutableArray array];
    _queue = [NSMutableArray array];
    return self;
}

- (UIWindow *)primaryWindow {
    UIViewController *topController = topMostController();
    if (topController.view.window && !topController.view.window.hidden) return topController.view.window;
    if (UIApplication.sharedApplication.keyWindow && !UIApplication.sharedApplication.keyWindow.hidden) return UIApplication.sharedApplication.keyWindow;
    for (UIWindow *window in UIApplication.sharedApplication.windows.reverseObjectEnumerator) {
        if (!window.hidden && window.alpha > 0.01 && window.windowLevel <= UIWindowLevelAlert) return window;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

- (UIWindowScene *)windowScene {
    UIWindow *window = [self primaryWindow];
    if ([window.windowScene isKindOfClass:UIWindowScene.class]) return window.windowScene;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) return (UIWindowScene *)scene;
    }
    return nil;
}

- (UIView *)hostView {
    UIWindowScene *scene = [self windowScene];
    if (!scene) return [self primaryWindow] ?: topMostController().view;
    if (!self.overlayWindow || self.overlayWindow.windowScene != scene) {
        self.overlayRoot = [SCINotificationOverlayRootViewController new];
        self.overlayWindow = [[SCINotificationPassthroughWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.rootViewController = self.overlayRoot;
        self.overlayWindow.backgroundColor = UIColor.clearColor;
        self.overlayWindow.opaque = NO;
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 100.0;
        self.overlayWindow.frame = scene.coordinateSpace.bounds;
    }
    self.overlayRoot.view.frame = self.overlayWindow.bounds;
    self.overlayWindow.hidden = NO;
    return self.overlayRoot.view;
}

- (void)cleanupIfEmpty {
    if (self.visible.count > 0 || self.queue.count > 0) return;
    self.overlayWindow.hidden = YES;
    self.overlayWindow.rootViewController = nil;
    self.overlayWindow = nil;
    self.overlayRoot = nil;
}

- (void)onMain:(dispatch_block_t)block {
    if (!block) return;
    if (NSThread.isMainThread) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

- (CGFloat)offsetForIndex:(NSUInteger)index {
    CGFloat offset = kSCINotificationTopMargin;
    for (NSUInteger i = 0; i < index && i < self.visible.count; i++) {
        SCINotificationPillView *pill = self.visible[i].pill;
        CGFloat height = CGRectGetHeight(pill.bounds);
        if (height < 1.0) height = 52.0;
        offset += height + kSCINotificationStackSpacing;
    }
    return offset;
}

- (void)relayoutAnimated:(BOOL)animated {
    UIView *host = self.overlayRoot.view;
    for (NSUInteger i = 0; i < self.visible.count; i++) {
        self.visible[i].topConstraint.constant = [self offsetForIndex:i];
    }
    void (^layout)(void) = ^{ [host layoutIfNeeded]; };
    if (animated) {
        [UIView animateWithDuration:0.32 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:layout completion:nil];
    } else {
        layout();
    }
}

- (void)insertPill:(SCINotificationPillView *)pill identifier:(NSString *)identifier progress:(BOOL)progress {
    UIView *host = [self hostView];
    [host addSubview:pill];
    NSLayoutConstraint *top = [pill.topAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.topAnchor constant:-90.0];
    [pill setPresentationTopConstraint:top];
    [NSLayoutConstraint activateConstraints:@[
        top,
        [pill.centerXAnchor constraintEqualToAnchor:host.centerXAnchor],
    ]];

    SCINotificationSlot *slot = [SCINotificationSlot new];
    slot.pill = pill;
    slot.topConstraint = top;
    slot.identifier = identifier ?: @"";
    slot.progress = progress;
    [self.visible addObject:slot];

    __weak typeof(self) weakSelf = self;
    __weak SCINotificationSlot *weakSlot = slot;
    pill.onDidDismiss = ^{
        __strong typeof(weakSelf) self = weakSelf;
        SCINotificationSlot *strongSlot = weakSlot;
        if (!self || !strongSlot) return;
        [strongSlot.timer invalidate];
        [self.visible removeObject:strongSlot];
        [self relayoutAnimated:YES];
        [self drainQueue];
        [self cleanupIfEmpty];
    };

    [host layoutIfNeeded];
    pill.alpha = 0.0;
    pill.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -24.0), CGAffineTransformMakeScale(0.88, 0.88));
    top.constant = [self offsetForIndex:self.visible.count - 1];
    [UIView animateWithDuration:kSCINotificationInsertDuration delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.85 options:UIViewAnimationOptionCurveEaseOut animations:^{
        pill.alpha = 1.0;
        pill.transform = CGAffineTransformIdentity;
        [self relayoutAnimated:NO];
    } completion:nil];

    if (!progress) {
        slot.timer = [NSTimer scheduledTimerWithTimeInterval:SCINotificationPillDuration() repeats:NO block:^(__unused NSTimer *timer) {
            SCINotificationSlot *strongSlot = weakSlot;
            if (strongSlot.pill.superview) [strongSlot.pill dismiss];
        }];
    }
}

- (void)drainQueue {
    while (self.queue.count > 0) {
        NSUInteger visibleToasts = 0;
        for (SCINotificationSlot *slot in self.visible) {
            if (!slot.progress) visibleToasts++;
        }
        if (visibleToasts >= kSCINotificationMaxQueuedToasts) return;
        NSDictionary *next = self.queue.firstObject;
        [self.queue removeObjectAtIndex:0];
        [self notifyIdentifier:next[@"identifier"]
                         title:next[@"title"]
                      subtitle:next[@"subtitle"]
                  iconResource:next[@"icon"]
                          tone:[next[@"tone"] unsignedIntegerValue]
                 triggerHaptic:NO];
    }
}

- (void)notifyIdentifier:(NSString *)identifier
                   title:(NSString *)title
                subtitle:(NSString *)subtitle
            iconResource:(NSString *)iconResource
                    tone:(SCINotificationTone)tone {
    [self notifyIdentifier:identifier title:title subtitle:subtitle iconResource:iconResource tone:tone triggerHaptic:YES];
}

- (void)notifyIdentifier:(NSString *)identifier
                   title:(NSString *)title
                subtitle:(NSString *)subtitle
            iconResource:(NSString *)iconResource
                    tone:(SCINotificationTone)tone
           triggerHaptic:(BOOL)triggerHaptic {
    if (triggerHaptic) {
        SCINotificationTriggerHaptic(identifier, tone);
    }
    if (!SCINotificationIsEnabled(identifier)) return;
    [self onMain:^{
        NSUInteger visibleToasts = 0;
        for (SCINotificationSlot *slot in self.visible) {
            if (!slot.progress) visibleToasts++;
        }
        if (visibleToasts >= kSCINotificationMaxQueuedToasts) {
            [self.queue addObject:@{
                @"identifier": identifier ?: @"",
                @"title": title ?: @"",
                @"subtitle": subtitle ?: @"",
                @"icon": SCINotificationIconResourceForTone(iconResource, tone) ?: @"",
                @"tone": @(tone),
            }];
            return;
        }
        NSString *resolvedIconResource = SCINotificationIconResourceForTone(iconResource, tone);
        UIImage *icon = resolvedIconResource.length
            ? [SCIAssetUtils instagramIconNamed:resolvedIconResource pointSize:16.0 renderingMode:UIImageRenderingModeAlwaysTemplate]
            : nil;
        SCINotificationPillView *pill = [SCINotificationPillView toastPillWithTitle:title subtitle:subtitle icon:icon tone:tone];
        [self insertPill:pill identifier:identifier progress:NO];
    }];
}

- (SCINotificationPillView *)beginProgressForIdentifier:(NSString *)identifier
                                              title:(NSString *)title
                                           onCancel:(void (^)(void))onCancel {
    if (!SCINotificationIsEnabled(identifier)) return nil;
    __block SCINotificationPillView *pill = nil;
    dispatch_block_t create = ^{
        pill = [SCINotificationPillView progressPill];
        [pill updateProgressTitle:title ?: @"Downloading..." subtitle:nil];
        pill.onCancel = onCancel;
        NSString *progressIdentifier = [identifier copy];
        pill.onTonePresented = ^(SCINotificationTone tone) {
            SCINotificationTriggerHaptic(progressIdentifier, tone);
        };
        [self insertPill:pill identifier:identifier progress:YES];
    };
    if (NSThread.isMainThread) create();
    else dispatch_sync(dispatch_get_main_queue(), create);
    return pill;
}

@end

void SCINotify(NSString *identifier,
               NSString *title,
               NSString *subtitle,
               NSString *iconResource,
               SCINotificationTone tone) {
    [[SCINotificationCenter shared] notifyIdentifier:identifier title:title subtitle:subtitle iconResource:iconResource tone:tone];
}

SCINotificationPillView *SCINotifyProgress(NSString *identifier, NSString *title, void (^onCancel)(void)) {
    return [[SCINotificationCenter shared] beginProgressForIdentifier:identifier title:title onCancel:onCancel];
}
