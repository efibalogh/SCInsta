#import <substrate.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "InstagramHeaders.h"
#import "Tweak.h"
#import "Utils.h"
#import "App/SCIFlexLoader.h"
#import "Shared/ActionButton/ActionButtonCore.h"

///////////////////////////////////////////////////////////

// Screenshot handlers

#define VOID_HANDLESCREENSHOT(orig) [SCIUtils getBoolPref:@"remove_screenshot_alert"] ? nil : orig;
#define NONVOID_HANDLESCREENSHOT(orig) return VOID_HANDLESCREENSHOT(orig)

///////////////////////////////////////////////////////////

// * Tweak version *
NSString *SCIVersionString = @"v1.2.0-dev";

// Variables that work across features
__weak id SCIPendingDirectVisualMessageToMarkSeen = nil;
NSString *SCIForcedStorySeenMediaPK = nil;
BOOL SCIForceMarkStoryAsSeen = NO;
BOOL SCIForceStoryAutoAdvance = NO;

static NSString *SCIIdentifierStringFromValue(id value) {
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *string = (NSString *)value;
        return string.length > 0 ? string : nil;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *string = [value stringValue];
        return string.length > 0 ? string : nil;
    }
    return nil;
}

static id SCIValueForSelectorOrKey(id object, NSString *name) {
    if (!object || name.length == 0) return nil;

    SEL selector = NSSelectorFromString(name);
    if ([object respondsToSelector:selector]) {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    }

    @try {
        return [object valueForKey:name];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *SCIStoryMediaIdentifierFromObject(id object, NSInteger depth) {
    if (!object || depth > 3) return nil;

    for (NSString *name in @[@"pk", @"mediaPK", @"mediaPk", @"mediaID", @"mediaId", @"id", @"itemID", @"itemId"]) {
        NSString *identifier = SCIIdentifierStringFromValue(SCIValueForSelectorOrKey(object, name));
        if (identifier.length > 0) return identifier;
    }

    for (NSString *name in @[@"media", @"mediaItem", @"storyItem", @"item", @"model"]) {
        id nested = SCIValueForSelectorOrKey(object, name);
        if (nested && nested != object) {
            NSString *identifier = SCIStoryMediaIdentifierFromObject(nested, depth + 1);
            if (identifier.length > 0) return identifier;
        }
    }

    return nil;
}

NSString *SCIStoryMediaIdentifier(id media) {
    return SCIStoryMediaIdentifierFromObject(media, 0);
}

static void SCIShowPendingRepostFeedbackIfNeeded(SCIActionButtonSource source) {
    NSDictionary<NSString *, NSString *> *feedback = SCIConsumePendingRepostFeedback(source);
    if (!feedback) return;
    NSString *iconResource = feedback[@"iconResource"] ?: @"ig_icon_reshare_outline_24";
    SCINotify(kSCINotificationRepost, feedback[@"title"] ?: @"Tapped repost button", nil, iconResource, SCINotificationToneForIconResource(iconResource));
}

@interface _UISheetDetent : NSObject
+ (instancetype)_mediumDetent;
+ (instancetype)_largeDetent;
@end

@interface _UISheetPresentationController : NSObject
@property (nonatomic, assign, setter=_setPresentsAtStandardHalfHeight:) BOOL _presentsAtStandardHalfHeight;
@property (nonatomic, copy, setter=_setDetents:) NSArray *_detents;
@property (nonatomic, assign, setter=_setIndexOfCurrentDetent:) NSInteger _indexOfCurrentDetent;
@property (nonatomic, assign, setter=_setPrefersScrollingExpandsToLargerDetentWhenScrolledToEdge:) BOOL _prefersScrollingExpandsToLargerDetentWhenScrolledToEdge;
@property (nonatomic, assign, setter=_setIndexOfLastUndimmedDetent:) NSInteger _indexOfLastUndimmedDetent;
@end

static const void *kSCIFlexThreeFingerGestureKey = &kSCIFlexThreeFingerGestureKey;

// MARK: Liquid glass

%group SCITweakLaunchCriticalHooks

%hook IGDSLauncherConfig
- (_Bool)isLiquidGlassInAppNotificationEnabled {
    return [SCIUtils sci_liquidGlassLauncherPrefKey:@"liquid_glass_in_app_notifications" orig:%orig];
}
- (_Bool)isLiquidGlassContextMenuEnabled{
    return [SCIUtils sci_liquidGlassLauncherPrefKey:@"liquid_glass_context_menus" orig:%orig];
}
- (_Bool)isLiquidGlassToastEnabled {
    return [SCIUtils sci_liquidGlassLauncherPrefKey:@"liquid_glass_toasts" orig:%orig];
}
- (_Bool)isLiquidGlassToastPeekEnabled {
    return [SCIUtils sci_liquidGlassLauncherPrefKey:@"liquid_glass_toast_peek" orig:%orig];
}
- (_Bool)isLiquidGlassAlertDialogEnabled {
    return [SCIUtils sci_liquidGlassLauncherPrefKey:@"liquid_glass_alert_dialogs" orig:%orig];
}
- (_Bool)isLiquidGlassIconBarButtonEnabled {
    return [SCIUtils sci_liquidGlassLauncherPrefKey:@"liquid_glass_icon_bar_buttons" orig:%orig];
}
- (_Bool)canUseInternalLiquidGlassDebugger {
    return [SCIUtils sci_liquidGlassLauncherPrefKey:@"liquid_glass_internal_debugger" orig:%orig];
}
%end

// MARK: Bug reports

// Disable sending modded insta bug reports
%hook IGWindow
- (void)showDebugMenu {
    return;
}
%end

%hook IGBugReportUploader
- (id)initWithNetworker:(id)arg1
         pandoGraphQLService:(id)arg2
             analyticsLogger:(id)arg3
                userDefaults:(id)arg4
         launcherSetProvider:(id)arg5
shouldPersistLastBugReportId:(id)arg6
{
    return nil;
}
%end

%end

// MARK: Screenshots

%group SCITweakPrivacyHooks

// Disable anti-screenshot feature on visual messages
%hook IGStoryViewerContainerView
- (void)setShouldBlockScreenshot:(BOOL)arg1 viewModel:(id)arg2 { VOID_HANDLESCREENSHOT(%orig); }
%end

// Disable screenshot logging/detection
%hook IGDirectVisualMessageViewerSession
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 { NONVOID_HANDLESCREENSHOT(%orig); }
%end

%hook IGDirectVisualMessageReplayService
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 { NONVOID_HANDLESCREENSHOT(%orig); }
%end

%hook IGDirectVisualMessageReportService
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 { NONVOID_HANDLESCREENSHOT(%orig); }
%end

%hook IGDirectVisualMessageScreenshotSafetyLogger
- (id)initWithUserSession:(id)arg1 entryPoint:(NSInteger)arg2 {
    if ([SCIUtils getBoolPref:@"remove_screenshot_alert"]) {
        NSLog(@"[SCInsta] Disable visual message screenshot safety logger");
        return nil;
    }

    return %orig;
}
%end

%hook IGScreenshotObserver
- (id)initForController:(id)arg1 { NONVOID_HANDLESCREENSHOT(%orig); }
%end

%hook IGScreenshotObserverDelegate
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 { VOID_HANDLESCREENSHOT(%orig); }
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 { VOID_HANDLESCREENSHOT(%orig); }
%end

%hook IGDirectMediaViewerViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 { VOID_HANDLESCREENSHOT(%orig); }
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 { VOID_HANDLESCREENSHOT(%orig); }
%end

%hook IGStoryViewerViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 { VOID_HANDLESCREENSHOT(%orig); }
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 { VOID_HANDLESCREENSHOT(%orig); }
%end

%hook IGSundialFeedViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 { VOID_HANDLESCREENSHOT(%orig); }
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 { VOID_HANDLESCREENSHOT(%orig); }
%end

%hook IGDirectVisualMessageViewerController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 { VOID_HANDLESCREENSHOT(%orig); }
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 { VOID_HANDLESCREENSHOT(%orig); }
%end

%end

/////////////////////////////////////////////////////////////////////////////

// MARK: Hide items

// Direct suggested chats (in search bar)
BOOL showSearchSectionLabelForTag(NSInteger tag) {
    if (
        (tag == 18 && [SCIUtils getBoolPref:@"hide_meta_ai_direct"]) // AI
        || (tag == 20 && [SCIUtils getBoolPref:@"hide_meta_ai_direct"]) // Ask Meta AI
        || (tag == 2 && [SCIUtils getBoolPref:@"hide_suggested_users_direct"]) // More suggestions
        || (tag == 13 && [SCIUtils getBoolPref:@"no_suggested_chats"]) // Suggested channels
    ) {
        return false;
    }

    return true;
}

%group SCITweakMessagesHooks

%hook IGDirectInboxSearchSectionPartitioningComponent
- (id)initWithSectionTitle:(id)arg1
             maxRecipients:(NSInteger)maxRecipients
               filterBlock:(id)arg3
                comparator:(id)arg4
          expandedSections:(id)arg5
                      type:(NSInteger)arg6
  recipientListSectionType:(NSInteger)tag
{
    if (showSearchSectionLabelForTag(tag)) {
        return %orig(arg1, maxRecipients, arg3, arg4, arg5, arg6, tag);
    }
    else {
        return %orig(arg1, 0, arg3, arg4, arg5, arg6, tag);
    }
}
%end

%hook IGDirectInboxSearchListAdapterDataSource
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig();
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Section headers
        if ([obj isKindOfClass:%c(IGLabelItemViewModel)]) {

            NSNumber *tag = [obj valueForKey:@"tag"];
            if (tag && !showSearchSectionLabelForTag([tag intValue])) {
                shouldHide = YES;
            }
            
        }

        // AI agents section
        else if (
            [obj isKindOfClass:%c(IGDirectInboxSearchAIAgentsPillsSectionViewModel)]
         || [obj isKindOfClass:%c(IGDirectInboxSearchAIAgentsSuggestedPromptViewModel)]
         || [obj isKindOfClass:%c(IGDirectInboxSearchAIAgentsSuggestedPromptLoggingViewModel)]
        ) {

            if ([SCIUtils getBoolPref:@"hide_meta_ai_direct"]) {
                NSLog(@"[SCInsta] Hiding suggested chats (ai agents)");

                shouldHide = YES;
            }

        }

        // Recipients list
        else if ([obj isKindOfClass:%c(IGDirectRecipientCellViewModel)]) {

            // Broadcast channels
            if ([[obj recipient] isBroadcastChannel]) {
                if ([SCIUtils getBoolPref:@"no_suggested_chats"]) {
                    NSLog(@"[SCInsta] Hiding suggested chats (broadcast channels recipient)");

                    shouldHide = YES;
                }
            }
            
            // Meta AI (special section types)
            else if (([obj sectionType] == 20) || [obj sectionType] == 18) {
                if ([SCIUtils getBoolPref:@"hide_meta_ai_direct"]) {
                    NSLog(@"[SCInsta] Hiding meta ai suggested chats (meta ai recipient)");

                    shouldHide = YES;
                }
            }

            // Meta AI (catch-all)
            else if ([[[obj recipient] threadName] isEqualToString:@"Meta AI"]) {
                if ([SCIUtils getBoolPref:@"hide_meta_ai_direct"]) {
                    NSLog(@"[SCInsta] Hiding meta ai suggested chats (meta ai recipient)");

                    shouldHide = YES;
                }
            }
        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }

    }

    return [filteredObjs copy];
}
%end

// Direct suggested chats (thread creation view)
%hook IGDirectThreadCreationViewController
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig();
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Meta AI suggested user in direct new message view
        if ([SCIUtils getBoolPref:@"hide_meta_ai_direct"]) {
            
            if ([obj isKindOfClass:%c(IGDirectCreateChatCellViewModel)]) {

                // "AI Chats"
                if ([[obj valueForKey:@"title"] isEqualToString:@"AI chats"]) {
                    NSLog(@"[SCInsta] Hiding meta ai: direct thread creation ai chats section");

                    shouldHide = YES;
                }

            }

            else if ([obj isKindOfClass:%c(IGDirectRecipientCellViewModel)]) {

                // Meta AI suggested user
                if ([[[obj recipient] threadName] isEqualToString:@"Meta AI"]) {
                    NSLog(@"[SCInsta] Hiding meta ai: direct thread creation ai suggestion");

                    shouldHide = YES;
                }

            }
            
        }

        // Invite friends to insta contacts upsell
        if ([SCIUtils getBoolPref:@"hide_suggested_users_direct"]) {
            if ([obj isKindOfClass:%c(IGContactInvitesSearchUpsellViewModel)]) {
                NSLog(@"[SCInsta] Hiding suggested users: invite contacts upsell");

                shouldHide = YES;
            }
        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }
    }

    return [filteredObjs copy];
}
%end

// Direct suggested chats (inbox view)
%hook IGDirectInboxListAdapterDataSource
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig();
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Section header
        if ([obj isKindOfClass:%c(IGDirectInboxHeaderCellViewModel)]) {
            
            // "Suggestions" header
            if ([[obj title] isEqualToString:@"Suggestions"]) {
                if ([SCIUtils getBoolPref:@"hide_suggested_users_direct"]) {
                    NSLog(@"[SCInsta] Hiding suggested chats (header: messages tab)");

                    shouldHide = YES;
                }
            }

            // "Accounts to follow/message" header
            else if ([[obj title] hasPrefix:@"Accounts to"]) {
                if ([SCIUtils getBoolPref:@"hide_suggested_users_direct"]) {
                    NSLog(@"[SCInsta] Hiding suggested users: (header: inbox view)");

                    shouldHide = YES;
                }
            }

        }

        // Suggested recipients
        else if ([obj isKindOfClass:%c(IGDirectInboxSuggestedThreadCellViewModel)]) {
            if ([SCIUtils getBoolPref:@"hide_suggested_users_direct"]) {
                NSLog(@"[SCInsta] Hiding suggested chats (recipients: channels tab)");

                shouldHide = YES;
            }
        }

        // "Accounts to follow" recipients
        else if ([obj isKindOfClass:%c(IGDiscoverPeopleItemConfiguration)] || [obj isKindOfClass:%c(IGDiscoverPeopleConnectionItemConfiguration)]) {
            if ([SCIUtils getBoolPref:@"hide_suggested_users_direct"]) {
                NSLog(@"[SCInsta] Hiding suggested chats: (recipients: inbox view)");

                shouldHide = YES;
            }
        }

        // Hide notes tray
        else if ([obj isKindOfClass:%c(IGDirectNotesTrayRowViewModel)]) {
            if ([SCIUtils getBoolPref:@"hide_notes_tray"]) {
                NSLog(@"[SCInsta] Hiding notes tray");

                shouldHide = YES;
            }
        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }

    }

    return [filteredObjs copy];
}
%end

%end

%group SCITweakGeneralUIHooks

// Explore page results
%hook IGSearchListKitDataSource
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *originalObjs = %orig();
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Meta AI
        if ([SCIUtils getBoolPref:@"hide_meta_ai_explore"]) {

            // Section header 
            if ([obj isKindOfClass:%c(IGLabelItemViewModel)]) {

                // "Ask Meta AI" search results header
                if ([[obj valueForKey:@"labelTitle"] isEqualToString:@"Ask Meta AI"]) {
                    shouldHide = YES;
                }

            }

            // Empty search bar upsell view
            else if ([obj isKindOfClass:%c(IGSearchNullStateUpsellViewModel)]) {
                shouldHide = YES;
            }

            // Meta AI search suggestions
            else if ([obj isKindOfClass:%c(IGSearchResultNestedGroupViewModel)]) {
                shouldHide = YES;
            }

            // Meta AI suggested search results
            else if ([obj isKindOfClass:%c(IGSearchResultViewModel)]) {

                // itemType 6 is meta ai suggestions
                if ([obj itemType] == 6) {
                    if ([SCIUtils getBoolPref:@"hide_meta_ai_explore"]) {
                        shouldHide = YES;
                    }
                    
                }

                // Meta AI user account in search results
                else if ([[[obj title] string] isEqualToString:@"meta.ai"]) {
                    if ([SCIUtils getBoolPref:@"hide_meta_ai_explore"]) {
                        shouldHide = YES;
                    }
                }

            }
            
        }

        // No suggested users
        if ([SCIUtils getBoolPref:@"hide_suggested_users_search"]) {

            // Section header 
            if ([obj isKindOfClass:%c(IGLabelItemViewModel)]) {

                // "Suggested for you" search results header
                if ([[obj valueForKey:@"labelTitle"] isEqualToString:@"Suggested for you"]) {
                    shouldHide = YES;
                }

            }

            // Instagram users
            else if ([obj isKindOfClass:%c(IGDiscoverPeopleItemConfiguration)]) {
                shouldHide = YES;
            }

            // See all suggested users
            else if ([obj isKindOfClass:%c(IGSeeAllItemConfiguration)] && ((IGSeeAllItemConfiguration *)obj).destination == 4) {
                shouldHide = YES;
            }

        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }

    }

    return [filteredObjs copy];
}
%end

%end

%group SCITweakFeedHooks

// Story tray
%hook IGMainStoryTrayDataSource
- (id)allItemsForTrayUsingCachedValue:(BOOL)cached {
    NSArray *originalObjs = %orig(cached);
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (IGStoryTrayViewModel *obj in originalObjs) {
        BOOL shouldHide = NO;

        if ([SCIUtils getBoolPref:@"hide_suggested_users_feed"]) {
            if ([obj isKindOfClass:%c(IGStoryTrayViewModel)]) {
                NSNumber *type = [((IGStoryTrayViewModel *)obj) valueForKey:@"type"];
                
                // 8/9 looks to be the types for recommended stories
                if ([type isEqual:@(8)] || [type isEqual:@(9)]) {
                    NSLog(@"[SCInsta] Hiding suggested users: story tray");

                    shouldHide = YES;

                }
            }
        }

        if ([SCIUtils getBoolPref:@"hide_ads_feed"]) {
            // "New!" account id is 3538572169
            if ([obj isKindOfClass:%c(IGStoryTrayViewModel)] && (obj.isUnseenNux == YES || [obj.pk isEqualToString:@"3538572169"])) {
                NSLog(@"[SCInsta] Removing ads: story tray");

                shouldHide = YES;
            }
        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }
    }

    return [filteredObjs copy];
}
%end

// Story tray expanded footer (Suggested accounts to follow)
%hook IGStoryTraySectionController
- (void)storyTrayControllerShowSUPOGEducationBump {
    if ([SCIUtils getBoolPref:@"hide_suggested_users_feed"]) return;

    return %orig();
}
%end

%end

%group SCITweakGeneralMenuHooks

// Modern IGDS app menus
%hook IGDSMenu
- (id)initWithMenuItems:(NSArray<IGDSMenuItem *> *)originalObjs edr:(BOOL)edr headerLabelText:(id)headerLabelText {
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        BOOL shouldHide = NO;

        // Meta AI
        if (
            [[obj valueForKey:@"title"] isEqualToString:@"AI images"]
            || [[obj valueForKey:@"title"] isEqualToString:@"Meta AI"]
        ) {
            
            if ([SCIUtils getBoolPref:@"hide_meta_ai_global"]) {
                NSLog(@"[SCInsta] Hiding meta ai from IGDS menu");

                shouldHide = YES;
            }

        }

        // Populate new objs array
        if (!shouldHide) {
            [filteredObjs addObject:obj];
        }

    }

    return %orig([filteredObjs copy], edr, headerLabelText);
}
%end

%end

/////////////////////////////////////////////////////////////////////////////

// MARK: Confirm buttons

%group SCITweakFeedConfirmHooks

%hook IGFeedItemUFICell
- (void)UFIButtonBarDidTapOnLike:(id)arg1 {
    %orig;
}

- (void)UFIButtonBarDidTapOnRepost:(id)arg1 {
    if ([SCIUtils getBoolPref:@"repost_confirm_feed"]) {
        NSLog(@"[SCInsta] Confirm repost triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
            SCIShowPendingRepostFeedbackIfNeeded(SCIActionButtonSourceFeed);
        } cancelHandler:^{
            SCIConsumePendingRepostFeedback(SCIActionButtonSourceFeed);
        } title:@"Confirm Repost"
          message:@"Are you sure you want to repost this post?"];
    }
    else {
        %orig;
        SCIShowPendingRepostFeedbackIfNeeded(SCIActionButtonSourceFeed);
        return;
    }
}

- (void)UFIButtonBarDidLongPressOnRepost:(id)arg1 {
    if ([SCIUtils getBoolPref:@"repost_confirm_feed"]) {
        NSLog(@"[SCInsta] Confirm repost triggered (long press ignored)");
    }
    else {
        return %orig;
    }
}
- (void)UFIButtonBarDidLongPressOnRepost:(id)arg1 withGestureRecognizer:(id)arg2 {
    if ([SCIUtils getBoolPref:@"repost_confirm_feed"]) {
        NSLog(@"[SCInsta] Confirm repost triggered (long press ignored)");
    }
    else {
        return %orig;
    }
}
%end

%end

%group SCITweakReelsConfirmHooks

%hook IGSundialViewerVerticalUFI
- (void)_didTapLikeButton:(id)arg1 {
    %orig;
}

- (void)_didLongPressLikeButton:(id)arg1 {
    %orig;
}

- (void)_didTapRepostButton {
    if ([SCIUtils getBoolPref:@"repost_confirm_reels"]) {
        NSLog(@"[SCInsta] Confirm repost triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
            SCIShowPendingRepostFeedbackIfNeeded(SCIActionButtonSourceReels);
        } cancelHandler:^{
            SCIConsumePendingRepostFeedback(SCIActionButtonSourceReels);
        } title:@"Confirm Reel Repost"
          message:@"Are you sure you want to repost this reel?"];
    }
    else {
        %orig;
        SCIShowPendingRepostFeedbackIfNeeded(SCIActionButtonSourceReels);
        return;
    }
}

- (void)_didTapRepostButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"repost_confirm_reels"]) {
        NSLog(@"[SCInsta] Confirm repost triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
            SCIShowPendingRepostFeedbackIfNeeded(SCIActionButtonSourceReels);
        } cancelHandler:^{
            SCIConsumePendingRepostFeedback(SCIActionButtonSourceReels);
        } title:@"Confirm Reel Repost"
          message:@"Are you sure you want to repost this reel?"];
    }
    else {
        %orig;
        SCIShowPendingRepostFeedbackIfNeeded(SCIActionButtonSourceReels);
        return;
    }
}

- (void)_didLongPressRepostButton:(id)arg1 {
    if ([SCIUtils getBoolPref:@"repost_confirm_reels"]) {
        NSLog(@"[SCInsta] Confirm repost triggered (long press ignored)");
    }
    else {
        return %orig;
    }
}
%end

%end

/////////////////////////////////////////////////////////////////////////////

// FLEX explorer gesture handler
%group SCITweakRootUIHooks

%hook IGRootViewController
- (void)viewDidLoad {
    %orig;

    if (objc_getAssociatedObject(self.view, kSCIFlexThreeFingerGestureKey)) {
        return;
    }

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sci_handleFlexGesture:)];
    longPress.minimumPressDuration = 1.5;
    longPress.numberOfTouchesRequired = 3;
    longPress.cancelsTouchesInView = NO;
    longPress.delaysTouchesBegan = NO;
    longPress.delaysTouchesEnded = NO;
    [self.view addGestureRecognizer:longPress];
    objc_setAssociatedObject(self.view, kSCIFlexThreeFingerGestureKey, longPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%new - (void)sci_handleFlexGesture:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    if ([SCIUtils getBoolPref:@"flex_instagram"]) {
        SCIFlexShowExplorer(@"three_finger");
    }
}
%end

%end

%group SCITweakFlexEarlyCompatibilityHooks

%hook UIWindow
- (BOOL)_shouldCreateContextAsSecure {
    Class flexWindowClass = SCIFlexWindowClass();
    if (flexWindowClass && [self isKindOfClass:flexWindowClass]) {
        return YES;
    }
    return %orig;
}
%end

%hook _UISheetPresentationController
- (id)initWithPresentedViewController:(id)present presentingViewController:(id)presenter {
    self = %orig;
    if ([present isKindOfClass:%c(FLEXNavigationController)]) {
        if ([self respondsToSelector:@selector(_setPresentsAtStandardHalfHeight:)]) {
            self._presentsAtStandardHalfHeight = YES;
        } else {
            self._detents = @[[%c(_UISheetDetent) _mediumDetent], [%c(_UISheetDetent) _largeDetent]];
        }
        self._indexOfCurrentDetent = 1;
        self._prefersScrollingExpandsToLargerDetentWhenScrolledToEdge = NO;
        self._indexOfLastUndimmedDetent = 1;
    }

    return self;
}
%end

%end

%group SCITweakFlexLoadedCompatibilityHooks

%hook FLEXExplorerViewController
- (BOOL)_canShowWhileLocked {
    return YES;
}
%end

%end

// Disable safe mode (defaults reset upon subsequent crashes)
%group SCITweakSafeModeHooks

%hook IGSafeModeChecker
- (id)initWithInstacrashCounterProvider:(void *)provider crashThreshold:(unsigned long long)threshold {
    if ([SCIUtils getBoolPref:@"disable_safe_mode"]) return nil;

    return %orig(provider, threshold);
}
- (unsigned long long)crashCount {
    if ([SCIUtils getBoolPref:@"disable_safe_mode"]) {
        return 0;
    }

    return %orig;
}
%end

%end

static BOOL SCIPrefEnabled(NSString *key) {
    return [SCIUtils getBoolPref:key];
}

static BOOL SCIAnyPrefEnabled(NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        if (SCIPrefEnabled(key)) {
            return YES;
        }
    }

    return NO;
}

static void SCIInstallTweakPrivacyHooksIfNeeded(void) {
    if (!SCIPrefEnabled(@"remove_screenshot_alert")) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCITweakPrivacyHooks);
    });
}

static BOOL SCIAnyFlexOpeningPrefEnabled(void) {
    return SCIAnyPrefEnabled(@[
        @"flex_app_launch",
        @"flex_app_start",
        @"flex_instagram"
    ]);
}

static void SCIInstallTweakFlexSupportHooksIfNeeded(void) {
    if (!SCIAnyFlexOpeningPrefEnabled()) {
        return;
    }

    static dispatch_once_t flexEarlyOnceToken;
    dispatch_once(&flexEarlyOnceToken, ^{
        %init(SCITweakFlexEarlyCompatibilityHooks);
    });

    if (SCIPrefEnabled(@"flex_instagram")) {
        static dispatch_once_t rootOnceToken;
        dispatch_once(&rootOnceToken, ^{
            %init(SCITweakRootUIHooks);
        });
    }
}

void SCIInstallFlexLoadedCompatibilityHooksIfNeeded(void) {
    static dispatch_once_t flexLoadedOnceToken;
    dispatch_once(&flexLoadedOnceToken, ^{
        %init(SCITweakFlexLoadedCompatibilityHooks);
    });
}

void SCIInstallTweakLaunchCriticalHooks(void) {
    static dispatch_once_t launchOnceToken;
    dispatch_once(&launchOnceToken, ^{
        %init(SCITweakLaunchCriticalHooks);
    });

    static dispatch_once_t safeModeOnceToken;
    dispatch_once(&safeModeOnceToken, ^{
        %init(SCITweakSafeModeHooks);
    });

    SCIInstallTweakFlexSupportHooksIfNeeded();
}

void SCIInstallTweakFeedHooksIfNeeded(void) {
    if (SCIAnyPrefEnabled(@[
        @"hide_ads_feed",
        @"hide_suggested_users_feed"
    ])) {
        static dispatch_once_t feedOnceToken;
        dispatch_once(&feedOnceToken, ^{
            %init(SCITweakFeedHooks);
        });
    }

    if (SCIAnyPrefEnabled(@[
        @"repost_confirm_feed"
    ])) {
        static dispatch_once_t confirmOnceToken;
        dispatch_once(&confirmOnceToken, ^{
            %init(SCITweakFeedConfirmHooks);
        });
    }
}

void SCIInstallTweakStoryHooksIfNeeded(void) {
    SCIInstallTweakPrivacyHooksIfNeeded();
    SCIInstallTweakFeedHooksIfNeeded();
}

void SCIInstallTweakReelsHooksIfNeeded(void) {
    SCIInstallTweakPrivacyHooksIfNeeded();

    if (!SCIAnyPrefEnabled(@[
        @"repost_confirm_reels"
    ])) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCITweakReelsConfirmHooks);
    });
}

void SCIInstallTweakMessagesHooksIfNeeded(void) {
    SCIInstallTweakPrivacyHooksIfNeeded();

    if (!SCIAnyPrefEnabled(@[
        @"hide_meta_ai_direct",
        @"hide_suggested_users_direct",
        @"no_suggested_chats",
        @"hide_notes_tray"
    ])) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCITweakMessagesHooks);
    });
}

void SCIInstallTweakGeneralUIHooksIfNeeded(void) {
    if (SCIAnyPrefEnabled(@[
        @"hide_meta_ai_explore",
        @"hide_suggested_users_search"
    ])) {
        static dispatch_once_t generalOnceToken;
        dispatch_once(&generalOnceToken, ^{
            %init(SCITweakGeneralUIHooks);
        });
    }

    if (SCIPrefEnabled(@"hide_meta_ai_global")) {
        static dispatch_once_t menuOnceToken;
        dispatch_once(&menuOnceToken, ^{
            %init(SCITweakGeneralMenuHooks);
        });
    }

    SCIInstallTweakFlexSupportHooksIfNeeded();
}
