#import "SCIStartupHooks.h"

#import "../Utils.h"

FOUNDATION_EXPORT void SCIInstallLiquidGlassHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallFeedActionButtonHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallReelsActionButtonHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallStoriesActionButtonHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallMessagesActionButtonHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallProfileActionButtonHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallProfilePhotoZoomHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallBackgroundRefreshHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallSeenButtonHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallFollowConfirmHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallCreateGroupButtonControlHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallSharedLinkCleanupHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallHideMetaAIHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallFeedFilteringHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallFeedFilteringFeedHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallNoSuggestedUsersHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallLikeConfirmHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallTweakFeedHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallTweakStoryHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallTweakReelsHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallTweakMessagesHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallTweakGeneralUIHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallTweakLaunchCriticalHooks(void);
FOUNDATION_EXPORT void SCIInstallOpenLinkFromClipboardHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallHideExploreGridHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallHideTrendingSearchesHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallNavigationHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallSettingsShortcutsHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallDisableHapticsHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallCopyDescriptionHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallNoRecentSearchesHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallDetailedColorPickerHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallTeenAppIconsHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallEnhancedMediaResolutionHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallHideMetricsHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallDisableFeedAutoplayHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallPostCommentConfirmHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallHideStoryTrayHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallHideThreadsHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallHideRepostButtonHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallDisableHomeButtonRefreshHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallDisableStorySeenHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallStickerInteractConfirmHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallStoryPollVoteCountsHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallHideReelsHeaderHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallReelsPlaybackHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallDisableScrollingReelsHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallFollowIndicatorHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallDisableDMStorySeenHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallDisableInstantsCreationHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallVisualMsgModifierHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallNoSuggestedChatsHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallChangeThemeConfirmHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallFollowRequestConfirmHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallDisableTypingStatusHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallShhConfirmHooksIfNeeded(void);
FOUNDATION_EXPORT void SCIInstallHideFriendsMapHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallKeepDeletedMessagesHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallCallConfirmHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallDMAudioMsgConfirmHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallNotesCustomizationHooksIfNeeded(void);

void SCIInstallLaunchCriticalHooks(void) {
    SCIInstallTweakLaunchCriticalHooks();
    SCIInstallSettingsShortcutsHooksIfNeeded();
    SCIInstallOpenLinkFromClipboardHooksIfEnabled();
}

void SCIInstallFeedSurfaceHooksIfNeeded(void) {
    SCIInstallTweakFeedHooksIfNeeded();
    SCIInstallFeedFilteringFeedHooksIfEnabled();
    SCIInstallFeedActionButtonHooksIfEnabled();
    SCIInstallBackgroundRefreshHooksIfEnabled();
    SCIInstallLikeConfirmHooksIfNeeded();
    SCIInstallDisableFeedAutoplayHooksIfEnabled();
    SCIInstallPostCommentConfirmHooksIfEnabled();
    SCIInstallHideStoryTrayHooksIfEnabled();
    SCIInstallHideThreadsHooksIfEnabled();
    SCIInstallHideRepostButtonHooksIfEnabled();
    SCIInstallDisableHomeButtonRefreshHooksIfEnabled();
    SCIInstallCopyDescriptionHooksIfEnabled();
    SCIInstallTeenAppIconsHooksIfEnabled();
    SCIInstallHideMetricsHooksIfEnabled();
}

void SCIInstallStorySurfaceHooksIfNeeded(void) {
    SCIInstallTweakStoryHooksIfNeeded();
    SCIInstallFeedFilteringHooksIfEnabled();
    SCIInstallStoriesActionButtonHooksIfEnabled();
    SCIInstallSeenButtonHooksIfNeeded();
    SCIInstallHideMetaAIHooksIfEnabled();
    SCIInstallLikeConfirmHooksIfNeeded();
    SCIInstallDisableStorySeenHooksIfNeeded();
    SCIInstallStickerInteractConfirmHooksIfEnabled();
    SCIInstallStoryPollVoteCountsHooksIfEnabled();
    SCIInstallDetailedColorPickerHooksIfEnabled();
}

void SCIInstallReelsSurfaceHooksIfNeeded(void) {
    SCIInstallTweakReelsHooksIfNeeded();
    SCIInstallReelsActionButtonHooksIfEnabled();
    SCIInstallFeedFilteringHooksIfEnabled();
    SCIInstallLikeConfirmHooksIfNeeded();
    SCIInstallReelsPlaybackHooksIfNeeded();
    SCIInstallHideReelsHeaderHooksIfEnabled();
    SCIInstallDisableScrollingReelsHooksIfEnabled();
    SCIInstallHideRepostButtonHooksIfEnabled();
    SCIInstallHideMetricsHooksIfEnabled();
}

void SCIInstallMessagesSurfaceHooksIfNeeded(void) {
    SCIInstallTweakMessagesHooksIfNeeded();
    SCIInstallMessagesActionButtonHooksIfEnabled();
    SCIInstallSeenButtonHooksIfNeeded();
    SCIInstallCreateGroupButtonControlHooksIfEnabled();
    SCIInstallHideMetaAIHooksIfEnabled();
    SCIInstallDisableDMStorySeenHooksIfNeeded();
    SCIInstallDisableInstantsCreationHooksIfEnabled();
    SCIInstallVisualMsgModifierHooksIfEnabled();
    SCIInstallNoSuggestedChatsHooksIfEnabled();
    SCIInstallChangeThemeConfirmHooksIfEnabled();
    SCIInstallFollowRequestConfirmHooksIfEnabled();
    SCIInstallDisableTypingStatusHooksIfEnabled();
    SCIInstallShhConfirmHooksIfNeeded();
    SCIInstallHideFriendsMapHooksIfEnabled();
    SCIInstallKeepDeletedMessagesHooksIfEnabled();
    SCIInstallCallConfirmHooksIfEnabled();
    SCIInstallDMAudioMsgConfirmHooksIfEnabled();
    SCIInstallNotesCustomizationHooksIfNeeded();
    SCIInstallNoRecentSearchesHooksIfEnabled();
    SCIInstallDetailedColorPickerHooksIfEnabled();
}

void SCIInstallProfileSurfaceHooksIfNeeded(void) {
    SCIInstallProfileActionButtonHooksIfEnabled();
    SCIInstallProfilePhotoZoomHooksIfEnabled();
    SCIInstallFollowConfirmHooksIfNeeded();
    SCIInstallNoSuggestedUsersHooksIfEnabled();
    SCIInstallFollowIndicatorHooksIfEnabled();
    SCIInstallSettingsShortcutsHooksIfNeeded();
}

void SCIInstallGeneralUIHooksIfNeeded(void) {
    SCIInstallTweakGeneralUIHooksIfNeeded();
    SCIInstallLiquidGlassHooksIfEnabled();
    SCIInstallSharedLinkCleanupHooksIfEnabled();
    SCIInstallHideMetaAIHooksIfEnabled();
    SCIInstallNoSuggestedUsersHooksIfEnabled();
    SCIInstallOpenLinkFromClipboardHooksIfEnabled();
    SCIInstallHideExploreGridHooksIfEnabled();
    SCIInstallHideTrendingSearchesHooksIfEnabled();
    SCIInstallNavigationHooksIfNeeded();
    SCIInstallSettingsShortcutsHooksIfNeeded();
    SCIInstallDisableHapticsHooksIfEnabled();
    SCIInstallCopyDescriptionHooksIfEnabled();
    SCIInstallNoRecentSearchesHooksIfEnabled();
    SCIInstallEnhancedMediaResolutionHooksIfEnabled();
}

void SCIInstallEnabledFeatureHooks(void) {
    SCIInstallLaunchCriticalHooks();
    SCIInstallGeneralUIHooksIfNeeded();
    SCIInstallFeedSurfaceHooksIfNeeded();
    SCIInstallStorySurfaceHooksIfNeeded();
    SCIInstallReelsSurfaceHooksIfNeeded();
    SCIInstallMessagesSurfaceHooksIfNeeded();
    SCIInstallProfileSurfaceHooksIfNeeded();
}
