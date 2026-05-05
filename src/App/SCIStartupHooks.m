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
FOUNDATION_EXPORT void SCIInstallNoSuggestedUsersHooksIfEnabled(void);
FOUNDATION_EXPORT void SCIInstallLikeConfirmHooksIfNeeded(void);

void SCIInstallEnabledFeatureHooks(void) {
    SCIInstallLiquidGlassHooksIfEnabled();
    SCIInstallFeedActionButtonHooksIfEnabled();
    SCIInstallReelsActionButtonHooksIfEnabled();
    SCIInstallStoriesActionButtonHooksIfEnabled();
    SCIInstallMessagesActionButtonHooksIfEnabled();
    SCIInstallProfileActionButtonHooksIfEnabled();
    SCIInstallProfilePhotoZoomHooksIfEnabled();
    SCIInstallBackgroundRefreshHooksIfEnabled();
    SCIInstallSeenButtonHooksIfNeeded();
    SCIInstallFollowConfirmHooksIfNeeded();
    SCIInstallCreateGroupButtonControlHooksIfEnabled();
    SCIInstallSharedLinkCleanupHooksIfEnabled();
    SCIInstallHideMetaAIHooksIfEnabled();
    SCIInstallFeedFilteringHooksIfEnabled();
    SCIInstallNoSuggestedUsersHooksIfEnabled();
    SCIInstallLikeConfirmHooksIfNeeded();
}
