#import <objc/runtime.h>
#import <objc/message.h>

#import "../../Utils.h"

static const void *kSCIStoryPollSignatureAssocKey = &kSCIStoryPollSignatureAssocKey;

static id SCIStoryPollSectionControllerFromOverlay(UIView *overlayView) {
    NSArray<NSString *> *selectors = @[@"mediaOverlayDelegate", @"retryDelegate", @"tappableOverlayDelegate", @"buttonDelegate"];
    Class sectionControllerClass = NSClassFromString(@"IGStoryFullscreenSectionController");

    for (NSString *selectorName in selectors) {
        id delegate = [SCIUtils getIvarForObj:overlayView name:selectorName.UTF8String];
        if (!delegate) {
            SEL selector = NSSelectorFromString(selectorName);
            if ([overlayView respondsToSelector:selector]) {
                delegate = ((id (*)(id, SEL))objc_msgSend)(overlayView, selector);
            }
        }
        if (!delegate) continue;
        if (!sectionControllerClass || [delegate isKindOfClass:sectionControllerClass]) return delegate;
    }

    return nil;
}

static id SCIStoryPollMediaFromOverlay(UIView *overlayView) {
    id sectionController = SCIStoryPollSectionControllerFromOverlay(overlayView);
    id media = nil;
    if (sectionController && [sectionController respondsToSelector:@selector(currentStoryItem)]) {
        media = ((id (*)(id, SEL))objc_msgSend)(sectionController, @selector(currentStoryItem));
    }
    if (!media) {
        UIViewController *controller = [SCIUtils viewControllerForAncestralView:overlayView];
        if ([controller respondsToSelector:@selector(currentStoryItem)]) {
            media = ((id (*)(id, SEL))objc_msgSend)(controller, @selector(currentStoryItem));
        }
    }
    return media;
}

static NSArray *SCIStoryPollArray(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;
    SEL selector = NSSelectorFromString(selectorName);
    id value = nil;
    if ([target respondsToSelector:selector]) {
        value = ((id (*)(id, SEL))objc_msgSend)(target, selector);
    }
    if (!value) {
        @try {
            value = [target valueForKey:selectorName];
        } @catch (__unused NSException *exception) {
            value = nil;
        }
    }
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSNumber *SCIStoryPollCountNumber(id tally) {
    for (NSString *selectorName in @[@"totalCount", @"count", @"countValue"]) {
        SEL selector = NSSelectorFromString(selectorName);
        id value = nil;
        if ([tally respondsToSelector:selector]) {
            value = ((id (*)(id, SEL))objc_msgSend)(tally, selector);
        }
        if ([value respondsToSelector:@selector(integerValue)]) {
            return @([value integerValue]);
        }
    }
    return nil;
}

static NSArray<UIView *> *SCIStoryPollOptionViews(UIView *root) {
    if (!root) return nil;

    id optionViews = [SCIUtils getIvarForObj:root name:"_optionViews"];
    if (![optionViews isKindOfClass:[NSArray class]] && [root respondsToSelector:NSSelectorFromString(@"optionViews")]) {
        optionViews = ((id (*)(id, SEL))objc_msgSend)(root, NSSelectorFromString(@"optionViews"));
    }
    if ([optionViews isKindOfClass:[NSArray class]] && [(NSArray *)optionViews count] > 0) {
        return optionViews;
    }

    for (UIView *subview in root.subviews) {
        NSArray<UIView *> *found = SCIStoryPollOptionViews(subview);
        if (found.count > 0) return found;
    }
    return nil;
}

static UILabel *SCIStoryPollLabelForOptionView(UIView *optionView) {
    if (!optionView) return nil;
    if ([optionView isKindOfClass:[UILabel class]]) return (UILabel *)optionView;
    for (UIView *subview in optionView.subviews) {
        UILabel *label = SCIStoryPollLabelForOptionView(subview);
        if (label) return label;
    }
    return nil;
}

static NSString *SCIStoryPollBaseText(NSString *text) {
    if (text.length == 0) return @"";
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@"\u00ad"];
    NSString *base = parts.firstObject ?: text;
    return [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static void SCIApplyStoryPollVoteCountsIfNeeded(UIView *overlayView) {
    if (![SCIUtils getBoolPref:@"story_poll_vote_counts"] || !overlayView.window) return;

    id media = SCIStoryPollMediaFromOverlay(overlayView);
    NSArray *storyPolls = SCIStoryPollArray(media, @"_private_storyPolls");
    if (storyPolls.count == 0) {
        storyPolls = SCIStoryPollArray(media, @"storyPolls");
    }
    id storyPoll = storyPolls.firstObject;
    if (!storyPoll) return;

    id pollSticker = nil;
    if ([storyPoll respondsToSelector:NSSelectorFromString(@"pollSticker")]) {
        pollSticker = ((id (*)(id, SEL))objc_msgSend)(storyPoll, NSSelectorFromString(@"pollSticker"));
    }
    NSArray *tallies = SCIStoryPollArray(pollSticker, @"tallies");
    NSArray<UIView *> *optionViews = SCIStoryPollOptionViews(overlayView);
    if (tallies.count == 0 || optionViews.count == 0) return;

    NSString *signature = [NSString stringWithFormat:@"%p-%p-%lu-%lu", media, storyPoll, (unsigned long)optionViews.count, (unsigned long)tallies.count];
    NSString *previousSignature = objc_getAssociatedObject(overlayView, kSCIStoryPollSignatureAssocKey);
    if ([previousSignature isEqualToString:signature]) return;

    NSUInteger count = MIN(optionViews.count, tallies.count);
    for (NSUInteger idx = 0; idx < count; idx++) {
        UILabel *label = SCIStoryPollLabelForOptionView(optionViews[idx]);
        NSNumber *votes = SCIStoryPollCountNumber(tallies[idx]);
        if (!label || !votes) continue;

        NSString *baseText = SCIStoryPollBaseText(label.text);
        if (baseText.length == 0) continue;
        label.text = [NSString stringWithFormat:@"%@\u00ad (%ld votes)", baseText, (long)votes.integerValue];
    }

    objc_setAssociatedObject(overlayView, kSCIStoryPollSignatureAssocKey, signature, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

%group SCIStoryPollVoteCountsHooks

%hook IGStoryFullscreenOverlayView

- (void)layoutSubviews {
    %orig;
    SCIApplyStoryPollVoteCountsIfNeeded((UIView *)self);
}

%end

%end

extern "C" void SCIInstallStoryPollVoteCountsHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"story_poll_vote_counts"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIStoryPollVoteCountsHooks);
    });
}
