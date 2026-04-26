// Rewrites Instagram's copied share links into a cleaner canonical form.

#import "../../Utils.h"
#import <objc/runtime.h>
#import <substrate.h>

static BOOL SCIShouldSanitizeCopiedShareLinks(void) {
    return [SCIUtils getBoolPref:@"remove_user_from_copied_share_link"];
}

static void SCIPollClipboardAndSanitize(NSInteger countBefore, int polls, double interval) {
    __block BOOL done = NO;
    for (int i = 0; i < polls; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((interval + (i * interval)) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (done) return;
            if ([UIPasteboard generalPasteboard].changeCount == countBefore) return;

            NSString *string = [UIPasteboard generalPasteboard].string;
            NSURL *url = string.length > 0 ? [NSURL URLWithString:string] : nil;
            NSURL *sanitized = [SCIUtils sanitizedInstagramShareURL:url];
            if (sanitized.absoluteString.length > 0 && ![sanitized.absoluteString isEqualToString:string]) {
                [UIPasteboard generalPasteboard].string = sanitized.absoluteString;
            }
            done = YES;
        });
    }
}

static void (*orig_shareToClipboardFromVC)(id, SEL, id);
static void replaced_shareToClipboardFromVC(id self, SEL _cmd, id vc) {
    if (!SCIShouldSanitizeCopiedShareLinks()) {
        orig_shareToClipboardFromVC(self, _cmd, vc);
        return;
    }
    NSInteger countBefore = [UIPasteboard generalPasteboard].changeCount;
    orig_shareToClipboardFromVC(self, _cmd, vc);
    SCIPollClipboardAndSanitize(countBefore, 30, 0.05);
}

__attribute__((constructor)) static void SCISharedLinkCleanupInit(void) {
    Class cls = NSClassFromString(@"IGExternalShareOptionsViewController");
    SEL selector = NSSelectorFromString(@"_shareToClipboardFromVC:");
    if (!cls || !class_getInstanceMethod(cls, selector)) {
        return;
    }
    MSHookMessageEx(cls, selector, (IMP)replaced_shareToClipboardFromVC, (IMP *)&orig_shareToClipboardFromVC);
}
