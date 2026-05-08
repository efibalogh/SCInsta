#import <objc/message.h>
#import <substrate.h>

#import "../../Utils.h"

static void (*orig_inboxRefreshControl)(id, SEL, id) = NULL;
static void replaced_inboxRefreshControl(id self, SEL _cmd, id arg) {
    if (![SCIUtils getBoolPref:@"dm_refresh_confirm"]) {
        if (orig_inboxRefreshControl) orig_inboxRefreshControl(self, _cmd, arg);
        return;
    }
    [SCIUtils showConfirmation:^{
        if (orig_inboxRefreshControl) orig_inboxRefreshControl(self, _cmd, arg);
    } title:@"Confirm Messages Refresh"
      message:@"Are you sure you want to refresh your inbox?"];
}

static void SCIHookDMRefreshSelector(Class cls, SEL selector) {
    if (!cls || !class_getInstanceMethod(cls, selector)) return;
    MSHookMessageEx(cls, selector, (IMP)replaced_inboxRefreshControl, (IMP *)&orig_inboxRefreshControl);
}

extern "C" void SCIInstallDMRefreshConfirmHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"IGDirectInboxViewController");
        if (!cls) cls = NSClassFromString(@"IGDirectInboxContainerViewController");
        SCIHookDMRefreshSelector(cls, NSSelectorFromString(@"refreshControlDidRefresh:"));
        SCIHookDMRefreshSelector(cls, NSSelectorFromString(@"refreshControlValueChanged:"));
        SCIHookDMRefreshSelector(cls, NSSelectorFromString(@"_didPullToRefresh:"));
    });
}
