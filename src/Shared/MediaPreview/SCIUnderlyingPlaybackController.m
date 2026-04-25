#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

#import "SCIUnderlyingPlaybackController.h"
#import "../../InstagramHeaders.h"
#import "../../Utils.h"

static NSUInteger const kUnderlyingPlaybackDiscoveryMaxViews = 160;
static NSInteger const kPlaybackPauseReason = 1;
static NSInteger const kPlaybackResumeReason = 0;
static NSInteger const kDirectPlaybackReason = 0;

typedef NS_ENUM(NSInteger, SCIPauseStrategy) {
    SCIPauseStrategyNone = 0,
    SCIPauseStrategyAVPlayer,
    SCIPauseStrategyPauseWithReason,
    SCIPauseStrategyPauseWithReasonCallsiteContext,
    SCIPauseStrategyPausePlayback,
    SCIPauseStrategyPausePlaybackWith,
    SCIPauseStrategyPausePlaybackWithReason,
    SCIPauseStrategyPause,
};

typedef NS_ENUM(NSInteger, SCIResumeStrategy) {
    SCIResumeStrategyNone = 0,
    SCIResumeStrategyAVPlayer,
    SCIResumeStrategyTryResumePlaybackWithReason,
    SCIResumeStrategyTryResumePlayback,
    SCIResumeStrategyResumePlaybackIfNeeded,
    SCIResumeStrategyResumePlayback,
    SCIResumeStrategyStartPlaybackWith,
    SCIResumeStrategyStartPlayback,
    SCIResumeStrategyPlayWithReason,
    SCIResumeStrategyPlayWithReasonCallsiteContext,
    SCIResumeStrategyPlay,
};

typedef NS_ENUM(NSInteger, SCIAudioStrategy) {
    SCIAudioStrategyNone = 0,
    SCIAudioStrategyAVPlayerMuted,
    SCIAudioStrategyAudioEnabledWithReason,
    SCIAudioStrategyAudioEnabledForReason,
    SCIAudioStrategyAudioEnabledReason,
    SCIAudioStrategyAudioEnabledWith,
    SCIAudioStrategyAudioEnabledUserInitiated,
    SCIAudioStrategyAudioEnabled,
    SCIAudioStrategyMuted,
};

@interface SCIPlaybackTargetSession : NSObject

@property (nonatomic, weak) id target;
@property (nonatomic, assign) SCIPauseStrategy pauseStrategy;
@property (nonatomic, assign) SCIResumeStrategy resumeStrategy;
@property (nonatomic, assign) SCIAudioStrategy audioStrategy;
@property (nonatomic, assign) NSInteger pauseReason;
@property (nonatomic, assign) NSInteger resumeReason;
@property (nonatomic, assign) NSInteger audioReason;
@property (nonatomic, assign) BOOL forceResume;
@property (nonatomic, assign) BOOL wasPlayingKnown;
@property (nonatomic, assign) BOOL wasPlaying;
@property (nonatomic, assign) BOOL didPause;
@property (nonatomic, assign) BOOL audioEnabledKnown;
@property (nonatomic, assign) BOOL wasAudioEnabled;
@property (nonatomic, assign) BOOL mutedKnown;
@property (nonatomic, assign) BOOL wasMuted;

@end

@implementation SCIPlaybackTargetSession
@end

static id SCIObjectForSelectorName(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;

    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static id SCIKVCObject(id target, NSString *key) {
    if (!target || key.length == 0) return nil;

    @try {
        return [target valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL SCIBoolValueForSelector(id target, NSString *selectorName, BOOL *outValue) {
    NSNumber *number = [SCIUtils numericValueForObj:target selectorName:selectorName];
    if (!number) return NO;

    if (outValue) {
        *outValue = number.boolValue;
    }
    return YES;
}

static BOOL SCIDoubleValueForSelector(id target, NSString *selectorName, double *outValue) {
    NSNumber *number = [SCIUtils numericValueForObj:target selectorName:selectorName];
    if (!number) return NO;

    if (outValue) {
        *outValue = number.doubleValue;
    }
    return YES;
}

static BOOL SCIStringContainsAnyKeyword(NSString *value, NSArray<NSString *> *keywords) {
    if (value.length == 0) return NO;

    for (NSString *keyword in keywords) {
        if ([value rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static BOOL SCIAVPlayerIsPlaying(AVPlayer *player) {
    if (!player) return NO;
    return (player.rate > 0.0) || (player.timeControlStatus == AVPlayerTimeControlStatusPlaying);
}

static NSString *SCIPlaybackObjectKey(id object) {
    return object ? [NSString stringWithFormat:@"%p", object] : nil;
}

static NSArray<NSString *> *SCIPlaybackRelatedSelectorNames(void) {
    static NSArray<NSString *> *selectors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        selectors = @[
            @"mediaView",
            @"videoView",
            @"videoPlaybackView",
            @"playbackView",
            @"playerView",
            @"pageMediaView",
            @"viewerContainerView",
            @"embeddedView",
            @"audioPlayer",
            @"feedAudioPlayer",
            @"player",
            @"videoPlayer",
            @"playerController",
            @"playbackController",
            @"stateController",
            @"currentVisibleCell",
            @"visibleCell",
            @"currentCell",
        ];
    });
    return selectors;
}

static UIViewController *SCIAncestorViewControllerForView(UIView *view) {
    if (!view) return nil;

    id candidate = SCIObjectForSelectorName(view, @"_viewControllerForAncestor");
    if ([candidate isKindOfClass:[UIViewController class]]) {
        return (UIViewController *)candidate;
    }

    return [SCIUtils viewControllerForAncestralView:view];
}

static UIViewController *SCIFindAncestorViewController(UIViewController *controller, NSString *classNameFragment) {
    UIViewController *walker = controller;
    while (walker) {
        NSString *currentName = NSStringFromClass([walker class]);
        if ([currentName rangeOfString:classNameFragment options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return walker;
        }
        walker = walker.parentViewController;
    }
    return nil;
}

static BOOL SCIObjectIsInPreviewHierarchy(id object, UIView *previewView) {
    if (!object || !previewView) return NO;
    if (object == previewView) return YES;

    if ([object isKindOfClass:[UIView class]]) {
        UIView *view = (UIView *)object;
        return view == previewView || [view isDescendantOfView:previewView];
    }

    if ([object isKindOfClass:[UIViewController class]]) {
        UIView *view = ((UIViewController *)object).view;
        return view && (view == previewView || [view isDescendantOfView:previewView]);
    }

    return NO;
}

static void SCICollectAVPlayersFromLayer(CALayer *layer, CALayer *excludedLayer, NSMutableSet<AVPlayer *> *players) {
    if (!layer || !players || layer == excludedLayer) return;

    if ([layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayer *player = ((AVPlayerLayer *)layer).player;
        if (player) {
            [players addObject:player];
        }
    }

    for (CALayer *sublayer in layer.sublayers) {
        SCICollectAVPlayersFromLayer(sublayer, excludedLayer, players);
    }
}

static NSArray<AVPlayer *> *SCIVisibleAVPlayersExcludingView(UIView *excludedView) {
    UIApplication *app = [UIApplication sharedApplication];
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
    }

    if (windows.count == 0) {
        [windows addObjectsFromArray:app.windows];
    }

    NSMutableSet<AVPlayer *> *players = [NSMutableSet set];
    CALayer *excludedLayer = excludedView.layer;
    for (UIWindow *window in windows) {
        SCICollectAVPlayersFromLayer(window.layer, excludedLayer, players);
    }

    return players.allObjects;
}

static void SCIInvokeNoArg(id target, SEL selector) {
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
}

static void SCIInvokeReason(id target, SEL selector, NSInteger reason) {
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(target, selector, reason);
}

static void SCIInvokeReasonCallsiteContext(id target, SEL selector, NSInteger reason) {
    ((void (*)(id, SEL, NSInteger, id))objc_msgSend)(target, selector, reason, nil);
}

static void SCIInvokeBool(id target, SEL selector, BOOL value) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(target, selector, value);
}

static void SCIInvokeBoolReason(id target, SEL selector, BOOL value, NSInteger reason) {
    ((void (*)(id, SEL, BOOL, NSInteger))objc_msgSend)(target, selector, value, reason);
}

static void SCIInvokeBoolUserInitiated(id target, SEL selector, BOOL value, BOOL userInitiated) {
    ((void (*)(id, SEL, BOOL, BOOL))objc_msgSend)(target, selector, value, userInitiated);
}

@interface SCIUnderlyingPlaybackController ()

@property (nonatomic, assign) SCIFullScreenPlaybackSource playbackSource;
@property (nonatomic, weak) UIView *playbackSourceView;
@property (nonatomic, weak) UIViewController *playbackSourceController;
@property (nonatomic, strong) NSMutableDictionary<NSString *, SCIPlaybackTargetSession *> *underlyingPlaybackSessions;
@property (nonatomic, assign) BOOL didAttemptWindowPlayerDiscovery;

@end

@implementation SCIUnderlyingPlaybackController

- (instancetype)initWithPlaybackSource:(SCIFullScreenPlaybackSource)playbackSource
                            sourceView:(UIView *)sourceView
                            controller:(UIViewController *)controller {
    self = [super init];
    if (!self) return nil;

    _playbackSource = playbackSource;
    _playbackSourceView = sourceView;
    _playbackSourceController = controller;
    _underlyingPlaybackSessions = [NSMutableDictionary dictionary];
    return self;
}

- (void)beginSuppressionExcludingPreviewView:(UIView *)previewView {
    [self refreshUnderlyingPlaybackSessionsExcludingPreviewView:previewView];
    [self applyUnderlyingPlaybackSuppression];
}

- (void)refreshAndApplySuppressionExcludingPreviewView:(UIView *)previewView {
    [self refreshUnderlyingPlaybackSessionsExcludingPreviewView:previewView];
    [self applyUnderlyingPlaybackSuppression];
}

- (void)restorePlaybackIfNeeded {
    NSArray<SCIPlaybackTargetSession *> *sessions = self.underlyingPlaybackSessions.allValues.copy;
    for (SCIPlaybackTargetSession *session in sessions) {
        if (!session.target) continue;
        [self restoreAudioStateForSession:session];
        [self resumeSessionIfNeeded:session];
    }

    [self.underlyingPlaybackSessions removeAllObjects];
    self.didAttemptWindowPlayerDiscovery = NO;
}

- (BOOL)hasSuppressedSessions {
    return self.underlyingPlaybackSessions.count > 0;
}

#pragma mark - Discovery

- (BOOL)readPlayingStateForTarget:(id)target outPlaying:(BOOL *)outPlaying {
    if ([target isKindOfClass:[AVPlayer class]]) {
        if (outPlaying) {
            *outPlaying = SCIAVPlayerIsPlaying((AVPlayer *)target);
        }
        return YES;
    }

    BOOL boolValue = NO;
    if (SCIBoolValueForSelector(target, @"isPlaying", &boolValue) ||
        SCIBoolValueForSelector(target, @"playing", &boolValue)) {
        if (outPlaying) {
            *outPlaying = boolValue;
        }
        return YES;
    }

    if (SCIBoolValueForSelector(target, @"isPaused", &boolValue) ||
        SCIBoolValueForSelector(target, @"paused", &boolValue) ||
        SCIBoolValueForSelector(target, @"playbackPaused", &boolValue)) {
        if (outPlaying) {
            *outPlaying = !boolValue;
        }
        return YES;
    }

    double rate = 0.0;
    if (SCIDoubleValueForSelector(target, @"rate", &rate)) {
        if (outPlaying) {
            *outPlaying = rate > 0.001;
        }
        return YES;
    }

    return NO;
}

- (BOOL)readAudioEnabledStateForTarget:(id)target outAudioEnabled:(BOOL *)outAudioEnabled {
    BOOL enabled = NO;
    if (SCIBoolValueForSelector(target, @"isAudioEnabled", &enabled) ||
        SCIBoolValueForSelector(target, @"audioEnabled", &enabled) ||
        SCIBoolValueForSelector(target, @"videoViewAudioIsEnabled", &enabled)) {
        if (outAudioEnabled) {
            *outAudioEnabled = enabled;
        }
        return YES;
    }
    return NO;
}

- (BOOL)readMutedStateForTarget:(id)target outMuted:(BOOL *)outMuted {
    if ([target isKindOfClass:[AVPlayer class]]) {
        if (outMuted) {
            *outMuted = ((AVPlayer *)target).muted;
        }
        return YES;
    }

    BOOL muted = NO;
    if (SCIBoolValueForSelector(target, @"isMuted", &muted) ||
        SCIBoolValueForSelector(target, @"muted", &muted)) {
        if (outMuted) {
            *outMuted = muted;
        }
        return YES;
    }
    return NO;
}

- (UIViewController *)contextAncestorController {
    UIViewController *controller = self.playbackSourceController;
    UIViewController *sourceController = SCIAncestorViewControllerForView(self.playbackSourceView);
    if (sourceController) {
        controller = sourceController;
    }
    return controller;
}

- (UIView *)playbackDiscoveryRootView {
    UIView *candidate = self.playbackSourceView;
    UIView *bestContainer = nil;
    NSInteger depth = 0;
    NSArray<NSString *> *keywords = @[@"Cell", @"Media", @"Video", @"Story", @"Viewer", @"Sundial", @"Carousel", @"Feed", @"Reel", @"Photo"];

    while (candidate && depth < 10) {
        NSString *className = NSStringFromClass([candidate class]);
        if ([candidate isKindOfClass:[UICollectionViewCell class]] ||
            [candidate isKindOfClass:[UITableViewCell class]] ||
            SCIStringContainsAnyKeyword(className, keywords)) {
            bestContainer = candidate;
        }
        candidate = candidate.superview;
        depth++;
    }

    if (bestContainer) return bestContainer;
    if (self.playbackSourceController.view) return self.playbackSourceController.view;
    return self.playbackSourceView;
}

- (void)registerCandidateObject:(id)candidate forceResume:(BOOL)forceResume {
    [self registerCandidateObject:candidate forceResume:forceResume excludingPreviewView:nil];
}

- (void)registerCandidateObject:(id)candidate
                    forceResume:(BOOL)forceResume
           excludingPreviewView:(UIView *)previewView {
    if (!candidate || SCIObjectIsInPreviewHierarchy(candidate, previewView)) return;

    NSString *key = SCIPlaybackObjectKey(candidate);
    if (key.length == 0 || self.underlyingPlaybackSessions[key] != nil) return;

    SCIPlaybackTargetSession *session = [[SCIPlaybackTargetSession alloc] init];
    session.target = candidate;
    session.pauseReason = kPlaybackPauseReason;
    session.resumeReason = kPlaybackResumeReason;
    session.audioReason = kPlaybackPauseReason;
    session.forceResume = forceResume;

    if ([candidate isKindOfClass:[AVPlayer class]]) {
        AVPlayer *player = (AVPlayer *)candidate;
        BOOL wasPlaying = SCIAVPlayerIsPlaying(player);
        if (!forceResume && !wasPlaying) return;

        session.pauseStrategy = SCIPauseStrategyAVPlayer;
        session.resumeStrategy = SCIResumeStrategyAVPlayer;
        session.audioStrategy = SCIAudioStrategyAVPlayerMuted;
        session.wasPlayingKnown = YES;
        session.wasPlaying = wasPlaying;
        session.mutedKnown = YES;
        session.wasMuted = player.muted;
        self.underlyingPlaybackSessions[key] = session;
        return;
    }

    if ([candidate respondsToSelector:NSSelectorFromString(@"pauseWithReason:")]) {
        session.pauseStrategy = SCIPauseStrategyPauseWithReason;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"pauseWithReason:callsiteContext:")]) {
        session.pauseStrategy = SCIPauseStrategyPauseWithReasonCallsiteContext;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"pausePlaybackWithReason:")]) {
        session.pauseStrategy = SCIPauseStrategyPausePlaybackWithReason;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"pausePlaybackWith:")]) {
        session.pauseStrategy = SCIPauseStrategyPausePlaybackWith;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"pausePlayback")]) {
        session.pauseStrategy = SCIPauseStrategyPausePlayback;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"pause")]) {
        session.pauseStrategy = SCIPauseStrategyPause;
    }

    if ([candidate respondsToSelector:NSSelectorFromString(@"tryResumePlaybackWithReason:")]) {
        session.resumeStrategy = SCIResumeStrategyTryResumePlaybackWithReason;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"tryResumePlayback")]) {
        session.resumeStrategy = SCIResumeStrategyTryResumePlayback;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"resumePlaybackIfNeeded")]) {
        session.resumeStrategy = SCIResumeStrategyResumePlaybackIfNeeded;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"resumePlayback")]) {
        session.resumeStrategy = SCIResumeStrategyResumePlayback;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"startPlaybackWith:")]) {
        session.resumeStrategy = SCIResumeStrategyStartPlaybackWith;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"startPlayback")]) {
        session.resumeStrategy = SCIResumeStrategyStartPlayback;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"playWithReason:")]) {
        session.resumeStrategy = SCIResumeStrategyPlayWithReason;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"playWithReason:callsiteContext:")]) {
        session.resumeStrategy = SCIResumeStrategyPlayWithReasonCallsiteContext;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"play")]) {
        session.resumeStrategy = SCIResumeStrategyPlay;
    }

    if (session.pauseStrategy == SCIPauseStrategyNone || session.resumeStrategy == SCIResumeStrategyNone) {
        return;
    }

    BOOL wasPlaying = NO;
    session.wasPlayingKnown = [self readPlayingStateForTarget:candidate outPlaying:&wasPlaying];
    session.wasPlaying = wasPlaying;

    BOOL wasAudioEnabled = NO;
    session.audioEnabledKnown = [self readAudioEnabledStateForTarget:candidate outAudioEnabled:&wasAudioEnabled];
    session.wasAudioEnabled = wasAudioEnabled;

    BOOL wasMuted = NO;
    session.mutedKnown = [self readMutedStateForTarget:candidate outMuted:&wasMuted];
    session.wasMuted = wasMuted;

    BOOL isRelevant = forceResume || (session.wasPlayingKnown && session.wasPlaying);
    if (!isRelevant) return;

    if ([candidate respondsToSelector:NSSelectorFromString(@"setAudioEnabled:withReason:")] && session.audioEnabledKnown) {
        session.audioStrategy = SCIAudioStrategyAudioEnabledWithReason;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"setAudioEnabled:forReason:")] && session.audioEnabledKnown) {
        session.audioStrategy = SCIAudioStrategyAudioEnabledForReason;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"setAudioEnabled:reason:")] && session.audioEnabledKnown) {
        session.audioStrategy = SCIAudioStrategyAudioEnabledReason;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"setAudioEnabled:with:")] && session.audioEnabledKnown) {
        session.audioStrategy = SCIAudioStrategyAudioEnabledWith;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"setAudioEnabled:userInitiated:")] && session.audioEnabledKnown) {
        session.audioStrategy = SCIAudioStrategyAudioEnabledUserInitiated;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"setAudioEnabled:")] && session.audioEnabledKnown) {
        session.audioStrategy = SCIAudioStrategyAudioEnabled;
    } else if ([candidate respondsToSelector:NSSelectorFromString(@"setMuted:")] && session.mutedKnown) {
        session.audioStrategy = SCIAudioStrategyMuted;
    }

    self.underlyingPlaybackSessions[key] = session;
}

- (void)registerRelatedTargetsFromObject:(id)object
                             forceResume:(BOOL)forceResume
                                   depth:(NSInteger)depth
                                 visited:(NSMutableSet<NSString *> *)visited
                    excludingPreviewView:(UIView *)previewView {
    if (!object || depth < 0) return;

    NSString *objectKey = SCIPlaybackObjectKey(object);
    if (objectKey.length > 0 && [visited containsObject:objectKey]) return;
    if (objectKey.length > 0) {
        [visited addObject:objectKey];
    }

    [self registerCandidateObject:object forceResume:forceResume excludingPreviewView:previewView];

    if (depth == 0) return;

    for (NSString *selectorName in SCIPlaybackRelatedSelectorNames()) {
        id related = SCIObjectForSelectorName(object, selectorName);
        if (!related) {
            related = SCIKVCObject(object, selectorName);
        }
        if (related) {
            [self registerRelatedTargetsFromObject:related
                                       forceResume:forceResume
                                             depth:depth - 1
                                           visited:visited
                              excludingPreviewView:previewView];
        }
    }
}

- (void)registerRelatedTargetsFromObject:(id)object
                             forceResume:(BOOL)forceResume
                                   depth:(NSInteger)depth
                    excludingPreviewView:(UIView *)previewView {
    NSMutableSet<NSString *> *visited = [NSMutableSet set];
    [self registerRelatedTargetsFromObject:object
                               forceResume:forceResume
                                     depth:depth
                                   visited:visited
                      excludingPreviewView:previewView];
}

- (void)registerTargetsFromViewHierarchy:(UIView *)root
                             forceResume:(BOOL)forceResume
                    excludingPreviewView:(UIView *)previewView {
    if (!root || SCIObjectIsInPreviewHierarchy(root, previewView)) return;

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    NSUInteger inspectedCount = 0;
    while (queue.count > 0 && inspectedCount < kUnderlyingPlaybackDiscoveryMaxViews) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (!view || SCIObjectIsInPreviewHierarchy(view, previewView)) continue;

        [self registerCandidateObject:view forceResume:forceResume excludingPreviewView:previewView];
        [self registerRelatedTargetsFromObject:view
                                   forceResume:forceResume
                                         depth:1
                          excludingPreviewView:previewView];

        for (UIView *subview in view.subviews) {
            if (subview) {
                [queue addObject:subview];
            }
        }

        inspectedCount++;
    }
}

- (void)registerVisibleAVPlayersExcludingPreviewView:(UIView *)previewView {
    for (AVPlayer *player in SCIVisibleAVPlayersExcludingView(previewView)) {
        [self registerCandidateObject:player forceResume:NO excludingPreviewView:previewView];
    }
}

- (void)registerStoryPlaybackTargetsExcludingPreviewView:(UIView *)previewView {
    UIViewController *controller = [self contextAncestorController];
    UIViewController *storyController = SCIFindAncestorViewController(controller, @"StoryViewer");
    if (!storyController && [NSStringFromClass([controller class]) rangeOfString:@"Story" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        storyController = controller;
    }
    if (storyController) {
        [self registerCandidateObject:storyController forceResume:YES excludingPreviewView:previewView];
        [self registerRelatedTargetsFromObject:storyController
                                   forceResume:NO
                                         depth:2
                          excludingPreviewView:previewView];
    }
}

- (UIView *)directMediaViewFromController:(UIViewController *)controller {
    if (!controller) return nil;

    id viewerContainer = [SCIUtils getIvarForObj:controller name:"_viewerContainerView"];
    if (!viewerContainer) {
        viewerContainer = SCIKVCObject(controller, @"viewerContainerView");
    }

    id mediaView = SCIObjectForSelectorName(viewerContainer, @"mediaView");
    if (!mediaView) {
        mediaView = SCIKVCObject(viewerContainer, @"mediaView");
    }

    return [mediaView isKindOfClass:[UIView class]] ? (UIView *)mediaView : nil;
}

- (void)registerDirectPlaybackTargetsExcludingPreviewView:(UIView *)previewView {
    UIViewController *controller = [self contextAncestorController];
    UIViewController *directController = SCIFindAncestorViewController(controller, @"DirectVisualMessageViewerController");
    if (!directController && [NSStringFromClass([controller class]) rangeOfString:@"DirectVisualMessage" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        directController = controller;
    }

    UIView *mediaView = [self directMediaViewFromController:directController];
    if (mediaView) {
        [self registerCandidateObject:mediaView forceResume:YES excludingPreviewView:previewView];
        SCIPlaybackTargetSession *session = self.underlyingPlaybackSessions[SCIPlaybackObjectKey(mediaView)];
        session.pauseReason = kDirectPlaybackReason;
        session.resumeReason = kDirectPlaybackReason;
        session.audioReason = kDirectPlaybackReason;
        [self registerRelatedTargetsFromObject:mediaView
                                   forceResume:NO
                                         depth:2
                          excludingPreviewView:previewView];
    } else if (directController) {
        [self registerCandidateObject:directController forceResume:YES excludingPreviewView:previewView];
        SCIPlaybackTargetSession *session = self.underlyingPlaybackSessions[SCIPlaybackObjectKey(directController)];
        session.pauseReason = kDirectPlaybackReason;
        session.resumeReason = kDirectPlaybackReason;
        session.audioReason = kDirectPlaybackReason;
        [self registerRelatedTargetsFromObject:directController
                                   forceResume:NO
                                         depth:2
                          excludingPreviewView:previewView];
    }
}

- (void)registerContextControllerTargetsForceResume:(BOOL)forceResume
                               excludingPreviewView:(UIView *)previewView {
    UIViewController *controller = self.playbackSourceController;
    UIViewController *sourceController = [self contextAncestorController];
    if (sourceController) {
        controller = sourceController;
    }

    if (controller) {
        [self registerCandidateObject:controller forceResume:forceResume excludingPreviewView:previewView];
        [self registerRelatedTargetsFromObject:controller
                                   forceResume:NO
                                         depth:2
                          excludingPreviewView:previewView];
    }
}

- (void)refreshUnderlyingPlaybackSessionsExcludingPreviewView:(UIView *)previewView {
    switch (self.playbackSource) {
        case SCIFullScreenPlaybackSourceStories:
            [self registerStoryPlaybackTargetsExcludingPreviewView:previewView];
            break;
        case SCIFullScreenPlaybackSourceDirect:
            [self registerDirectPlaybackTargetsExcludingPreviewView:previewView];
            break;
        case SCIFullScreenPlaybackSourceFeed:
        case SCIFullScreenPlaybackSourceReels:
            [self registerContextControllerTargetsForceResume:NO excludingPreviewView:previewView];
            [self registerTargetsFromViewHierarchy:[self playbackDiscoveryRootView]
                                       forceResume:NO
                              excludingPreviewView:previewView];
            break;
        case SCIFullScreenPlaybackSourceUnknown:
        default:
            [self registerContextControllerTargetsForceResume:NO excludingPreviewView:previewView];
            [self registerTargetsFromViewHierarchy:[self playbackDiscoveryRootView]
                                       forceResume:NO
                              excludingPreviewView:previewView];
            break;
    }

    BOOL shouldAttemptWindowPlayerDiscovery = !self.didAttemptWindowPlayerDiscovery &&
        (self.playbackSource == SCIFullScreenPlaybackSourceUnknown || 
         self.playbackSource == SCIFullScreenPlaybackSourceFeed ||
         self.playbackSource == SCIFullScreenPlaybackSourceReels ||
         self.underlyingPlaybackSessions.count == 0);
    if (shouldAttemptWindowPlayerDiscovery) {
        self.didAttemptWindowPlayerDiscovery = YES;
        [self registerVisibleAVPlayersExcludingPreviewView:previewView];
    }
}

#pragma mark - Apply / Restore

- (void)applyPauseForSession:(SCIPlaybackTargetSession *)session {
    id target = session.target;
    if (!target) return;

    switch (session.pauseStrategy) {
        case SCIPauseStrategyAVPlayer:
            [(AVPlayer *)target pause];
            break;
        case SCIPauseStrategyPauseWithReason:
            SCIInvokeReason(target, NSSelectorFromString(@"pauseWithReason:"), session.pauseReason);
            break;
        case SCIPauseStrategyPauseWithReasonCallsiteContext:
            SCIInvokeReasonCallsiteContext(target, NSSelectorFromString(@"pauseWithReason:callsiteContext:"), session.pauseReason);
            break;
        case SCIPauseStrategyPausePlayback:
            SCIInvokeNoArg(target, NSSelectorFromString(@"pausePlayback"));
            break;
        case SCIPauseStrategyPausePlaybackWith:
            SCIInvokeReason(target, NSSelectorFromString(@"pausePlaybackWith:"), session.pauseReason);
            break;
        case SCIPauseStrategyPausePlaybackWithReason:
            SCIInvokeReason(target, NSSelectorFromString(@"pausePlaybackWithReason:"), session.pauseReason);
            break;
        case SCIPauseStrategyPause:
            SCIInvokeNoArg(target, NSSelectorFromString(@"pause"));
            break;
        case SCIPauseStrategyNone:
        default:
            break;
    }

    session.didPause = YES;
}

- (void)applyAudioSuppressionForSession:(SCIPlaybackTargetSession *)session {
    id target = session.target;
    if (!target) return;

    switch (session.audioStrategy) {
        case SCIAudioStrategyAVPlayerMuted:
            ((AVPlayer *)target).muted = YES;
            break;
        case SCIAudioStrategyAudioEnabledWithReason:
            SCIInvokeBoolReason(target, NSSelectorFromString(@"setAudioEnabled:withReason:"), NO, session.audioReason);
            break;
        case SCIAudioStrategyAudioEnabledForReason:
            SCIInvokeBoolReason(target, NSSelectorFromString(@"setAudioEnabled:forReason:"), NO, session.audioReason);
            break;
        case SCIAudioStrategyAudioEnabledReason:
            SCIInvokeBoolReason(target, NSSelectorFromString(@"setAudioEnabled:reason:"), NO, session.audioReason);
            break;
        case SCIAudioStrategyAudioEnabledWith:
            SCIInvokeBoolReason(target, NSSelectorFromString(@"setAudioEnabled:with:"), NO, session.audioReason);
            break;
        case SCIAudioStrategyAudioEnabledUserInitiated:
            SCIInvokeBoolUserInitiated(target, NSSelectorFromString(@"setAudioEnabled:userInitiated:"), NO, NO);
            break;
        case SCIAudioStrategyAudioEnabled:
            SCIInvokeBool(target, NSSelectorFromString(@"setAudioEnabled:"), NO);
            break;
        case SCIAudioStrategyMuted:
            SCIInvokeBool(target, NSSelectorFromString(@"setMuted:"), YES);
            break;
        case SCIAudioStrategyNone:
        default:
            break;
    }
}

- (void)applyUnderlyingPlaybackSuppression {
    for (SCIPlaybackTargetSession *session in self.underlyingPlaybackSessions.allValues) {
        if (!session.target) continue;
        [self applyPauseForSession:session];
        [self applyAudioSuppressionForSession:session];
    }
}

- (void)restoreAudioStateForSession:(SCIPlaybackTargetSession *)session {
    id target = session.target;
    if (!target) return;

    switch (session.audioStrategy) {
        case SCIAudioStrategyAVPlayerMuted:
            ((AVPlayer *)target).muted = session.wasMuted;
            break;
        case SCIAudioStrategyAudioEnabledWithReason:
            SCIInvokeBoolReason(target, NSSelectorFromString(@"setAudioEnabled:withReason:"), session.wasAudioEnabled, session.audioReason);
            break;
        case SCIAudioStrategyAudioEnabledForReason:
            SCIInvokeBoolReason(target, NSSelectorFromString(@"setAudioEnabled:forReason:"), session.wasAudioEnabled, session.audioReason);
            break;
        case SCIAudioStrategyAudioEnabledReason:
            SCIInvokeBoolReason(target, NSSelectorFromString(@"setAudioEnabled:reason:"), session.wasAudioEnabled, session.audioReason);
            break;
        case SCIAudioStrategyAudioEnabledWith:
            SCIInvokeBoolReason(target, NSSelectorFromString(@"setAudioEnabled:with:"), session.wasAudioEnabled, session.audioReason);
            break;
        case SCIAudioStrategyAudioEnabledUserInitiated:
            SCIInvokeBoolUserInitiated(target, NSSelectorFromString(@"setAudioEnabled:userInitiated:"), session.wasAudioEnabled, NO);
            break;
        case SCIAudioStrategyAudioEnabled:
            SCIInvokeBool(target, NSSelectorFromString(@"setAudioEnabled:"), session.wasAudioEnabled);
            break;
        case SCIAudioStrategyMuted:
            SCIInvokeBool(target, NSSelectorFromString(@"setMuted:"), session.wasMuted);
            break;
        case SCIAudioStrategyNone:
        default:
            break;
    }
}

- (void)resumeSessionIfNeeded:(SCIPlaybackTargetSession *)session {
    id target = session.target;
    if (!target) return;

    BOOL shouldResume = session.forceResume || (session.wasPlayingKnown && session.wasPlaying);
    if (!session.didPause || !shouldResume) return;

    switch (session.resumeStrategy) {
        case SCIResumeStrategyAVPlayer:
            [(AVPlayer *)target play];
            break;
        case SCIResumeStrategyTryResumePlaybackWithReason:
            SCIInvokeReason(target, NSSelectorFromString(@"tryResumePlaybackWithReason:"), session.resumeReason);
            break;
        case SCIResumeStrategyTryResumePlayback:
            SCIInvokeNoArg(target, NSSelectorFromString(@"tryResumePlayback"));
            break;
        case SCIResumeStrategyResumePlaybackIfNeeded:
            SCIInvokeNoArg(target, NSSelectorFromString(@"resumePlaybackIfNeeded"));
            break;
        case SCIResumeStrategyResumePlayback:
            SCIInvokeNoArg(target, NSSelectorFromString(@"resumePlayback"));
            break;
        case SCIResumeStrategyStartPlaybackWith:
            SCIInvokeReason(target, NSSelectorFromString(@"startPlaybackWith:"), session.resumeReason);
            break;
        case SCIResumeStrategyStartPlayback:
            SCIInvokeNoArg(target, NSSelectorFromString(@"startPlayback"));
            break;
        case SCIResumeStrategyPlayWithReason:
            SCIInvokeReason(target, NSSelectorFromString(@"playWithReason:"), session.resumeReason);
            break;
        case SCIResumeStrategyPlayWithReasonCallsiteContext:
            SCIInvokeReasonCallsiteContext(target, NSSelectorFromString(@"playWithReason:callsiteContext:"), session.resumeReason);
            break;
        case SCIResumeStrategyPlay:
            SCIInvokeNoArg(target, NSSelectorFromString(@"play"));
            break;
        case SCIResumeStrategyNone:
        default:
            break;
    }
}

@end
