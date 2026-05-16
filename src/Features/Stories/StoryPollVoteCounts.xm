#import <objc/message.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

#import "../../Utils.h"

// ─── Constants & Types ──────────────────────────────────────────────

static const char kSCICellSectionControllerAssocKey = 0;

// ─── Customization ──────────────────────────────────────────────────
// Adjust these values to customize the badge position and size.
#define kSCIPollBadgePaddingHorizontal 12.0
#define kSCIPollBadgePaddingVertical 6.0
#define kSCIPollBadgeMarginRight -6.0
// Set to 0.0 to center vertically, or a positive/negative value to offset from the center
#define kSCIPollBadgeCenterYOffset -18.0

// ─── Utilities ──────────────────────────────────────────────────────

static id SCICallMaybe(id object, NSString *selectorName) {
    if (!object || selectorName.length == 0) return nil;
    SEL selector = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:selector]) return nil;
    @try {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id SCIKVCMaybe(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSArray *SCIArrayIvar(id object, const char *name) {
    if (!object || !name) return nil;
    for (Class cls = [object class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        Ivar ivar = class_getInstanceVariable(cls, name);
        if (!ivar) continue;
        @try {
            id value = object_getIvar(object, ivar);
            return [value isKindOfClass:[NSArray class]] ? value : nil;
        } @catch (__unused NSException *exception) {
            return nil;
        }
    }
    return nil;
}

// ─── Label & String Handling ────────────────────────────────────────

static BOOL SCIStoryPollStickerIsEditing(UIView *view) {
    for (UIResponder *responder = view; responder; responder = responder.nextResponder) {
        NSString *className = NSStringFromClass([responder class]);
        if ([className containsString:@"StoryPostCaptureEditing"] ||
            [className containsString:@"StoryMediaCompositionEditing"] ||
            [className containsString:@"StoryStickerTray"]) {
            return YES;
        }
    }
    return NO;
}

// ─── Data Extraction ────────────────────────────────────────────────

static NSInteger SCIStoryPollTallyCount(id tally) {
    if ([tally respondsToSelector:@selector(integerValue)]) return [tally integerValue];
    for (NSString *selectorName in @[@"totalCount", @"count", @"countValue", @"voteCount", @"pollVotersCount"]) {
        id value = SCICallMaybe(tally, selectorName) ?: SCIKVCMaybe(tally, selectorName);
        if ([value respondsToSelector:@selector(integerValue)]) {
            return [value integerValue];
        }
    }
    return 0;
}

// Returns the IGAPIStoryPollTappableObject -> IGAPIPollSticker -> tallies
static id SCIStoryPollAuthoritativeSticker(id media, id viewModel) {
    NSArray *storyPolls = SCICallMaybe(media, @"_private_storyPolls") ?: SCIKVCMaybe(media, @"_private_storyPolls");
    if (![storyPolls isKindOfClass:[NSArray class]] || storyPolls.count == 0) {
        storyPolls = SCICallMaybe(media, @"storyPolls") ?: SCIKVCMaybe(media, @"storyPolls");
    }
    if (![storyPolls isKindOfClass:[NSArray class]] || storyPolls.count == 0) return nil;

    id viewPollValue = SCICallMaybe(viewModel, @"pollId") ?: SCIKVCMaybe(viewModel, @"pollId");
    NSString *viewPollID = [viewPollValue description];

    for (id storyPoll in storyPolls) {
        id sticker = SCICallMaybe(storyPoll, @"pollSticker") ?: SCIKVCMaybe(storyPoll, @"pollSticker");
        if (!sticker) continue;
        if (viewPollID.length == 0) return sticker;
        id stickerPollValue = SCICallMaybe(sticker, @"pollId") ?: SCIKVCMaybe(sticker, @"pollId");
        NSString *stickerPollID = [stickerPollValue description];
        if ([stickerPollID isEqualToString:viewPollID]) return sticker;
    }

    id first = storyPolls.firstObject;
    return SCICallMaybe(first, @"pollSticker") ?: SCIKVCMaybe(first, @"pollSticker");
}

static id SCIFindMediaForPollView(UIView *pollView) {
    // Check if any parent cell has an associated section controller.
    UICollectionViewCell *parentCell = nil;
    UIView *current = pollView;
    while (current != nil) {
        if ([current isKindOfClass:[UICollectionViewCell class]]) {
            parentCell = (UICollectionViewCell *)current;
            break;
        }
        current = current.superview;
    }

    if (parentCell) {
        id sectionController = objc_getAssociatedObject(parentCell, &kSCICellSectionControllerAssocKey);
        if (sectionController) {
            id media = SCICallMaybe(sectionController, @"currentStoryItem") ?: SCICallMaybe(sectionController, @"model");
            if (media) return media;
        }
    }

    // 2. Fallback: traverse responder chain
    for (UIResponder *responder = pollView; responder; responder = responder.nextResponder) {
        for (NSString *selectorName in @[@"media", @"igMedia", @"storyMedia", @"storyItem", @"item", @"feedItem"]) {
            id media = SCICallMaybe(responder, selectorName) ?: SCIKVCMaybe(responder, selectorName);
            if (media && media != responder) return media;
        }
    }

    return nil;
}

static void SCIApplyStoryPollVoteCounts(UIView *pollView, NSArray<UIView *> *optionViews) {
    if (![SCIUtils getBoolPref:@"story_poll_vote_counts"]) return;
    if (!pollView.window || SCIStoryPollStickerIsEditing(pollView)) {
        for (UIView *subview in pollView.subviews) {
            if (subview.tag >= 998800 && subview.tag < 998900) subview.hidden = YES;
        }
        return;
    }

    id media = SCIFindMediaForPollView(pollView);
    if (!media) return;

    id viewModel = SCICallMaybe(pollView, @"pollSticker") ?: SCICallMaybe(pollView, @"igapiStickerModel") ?: SCICallMaybe(pollView, @"exportModel");
    id model = SCIStoryPollAuthoritativeSticker(media, viewModel) ?: viewModel;

    NSArray *tallies = SCICallMaybe(model, @"tallies") ?: SCIKVCMaybe(model, @"tallies");
    if (![tallies isKindOfClass:[NSArray class]] || tallies.count == 0) {
        for (UIView *subview in pollView.subviews) {
            if (subview.tag >= 998800 && subview.tag < 998900) subview.hidden = YES;
        }
        return;
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;

    NSUInteger count = MIN(optionViews.count, tallies.count);
    for (NSUInteger index = 0; index < count; index++) {
        UIView *optionView = optionViews[index];

        NSInteger votes = SCIStoryPollTallyCount(tallies[index]);
        NSString *formattedVotes = [formatter stringFromNumber:@(votes)] ?: [NSString stringWithFormat:@"%td", votes];
        
        // Use a unique tag for each option view's badge
        NSInteger badgeTag = 998800 + index;
        UILabel *badge = [pollView viewWithTag:badgeTag];
        if (!badge) {
            badge = [[UILabel alloc] init];
            badge.tag = badgeTag;
            badge.font = [UIFont boldSystemFontOfSize:12];
            badge.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
            badge.backgroundColor = [SCIUtils SCIColor_InstagramTertiaryBackground];
            badge.textAlignment = NSTextAlignmentCenter;
            badge.layer.masksToBounds = YES;
            [pollView addSubview:badge];
        }
        
        badge.hidden = NO;
        badge.text = formattedVotes;
        [badge sizeToFit];
        
        CGSize badgeSize = badge.frame.size;
        badgeSize.width += kSCIPollBadgePaddingHorizontal;
        badgeSize.height += kSCIPollBadgePaddingVertical;
        
        // Enforce perfect circle if the width is smaller than the height (e.g. for single digits)
        badgeSize.width = MAX(badgeSize.width, badgeSize.height);
        
        // Convert optionView bounds to pollView coordinate space so we aren't clipped by the optionView
        CGRect optionFrame = [optionView convertRect:optionView.bounds toView:pollView];
        
        CGFloat badgeX = CGRectGetMaxX(optionFrame) - badgeSize.width - kSCIPollBadgeMarginRight;
        CGFloat badgeY = CGRectGetMidY(optionFrame) - (badgeSize.height / 2.0) + kSCIPollBadgeCenterYOffset;
        
        badge.frame = CGRectMake(badgeX, badgeY, badgeSize.width, badgeSize.height);
        badge.layer.cornerRadius = badgeSize.height / 2.0;
        
        [pollView bringSubviewToFront:badge];
    }
    
    // Hide any phantom badges that were created from previous logic or if options count shrank
    for (UIView *subview in pollView.subviews) {
        if (subview.tag >= 998800 + count && subview.tag < 998900) {
            subview.hidden = YES;
        }
    }
}

// ─── Hooks ──────────────────────────────────────────────────────────

%group SCIStoryPollVoteCountsHooks

// Bind section controller to cell so child views can easily access the current story item.
%hook IGStoryFullscreenSectionController
- (id)cellForItemAtIndex:(NSInteger)index {
    UICollectionViewCell *cell = %orig;
    if (cell) objc_setAssociatedObject(cell, &kSCICellSectionControllerAssocKey, self, OBJC_ASSOCIATION_ASSIGN);
    return cell;
}
%end

%hook IGStorySectionController
- (id)cellForItemAtIndex:(NSInteger)index {
    UICollectionViewCell *cell = %orig;
    if (cell) objc_setAssociatedObject(cell, &kSCICellSectionControllerAssocKey, self, OBJC_ASSOCIATION_ASSIGN);
    return cell;
}
%end

// Modern poll sticker
%hook IGPollStickerV2View
- (void)layoutSubviews {
    %orig;
    NSArray *options = SCIArrayIvar(self, "_optionViews");
    if (options.count > 0) SCIApplyStoryPollVoteCounts((UIView *)self, options);
}
%end

// Legacy poll sticker
%hook IGPollStickerView
- (void)layoutSubviews {
    %orig;
    NSArray *options = SCIArrayIvar(self, "_optionViews") ?: SCIArrayIvar(self, "_voteOptionViews") ?: SCIArrayIvar(self, "_options");
    if (options.count > 0) SCIApplyStoryPollVoteCounts((UIView *)self, options);
}
%end

// Overlay view constantly lays out (e.g. progress bar), so hooking it guarantees
// our text isn't overwritten by Instagram's asynchronous poll result fetches.
%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
    %orig;
    Class pollV2Class = NSClassFromString(@"IGPollStickerV2View");
    Class pollClass = NSClassFromString(@"IGPollStickerView");
    if (!pollV2Class && !pollClass) return;
    
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:(UIView *)self];
    while (stack.count > 0) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        
        if ((pollV2Class && [view isKindOfClass:pollV2Class]) ||
            (pollClass && [view isKindOfClass:pollClass])) {
            NSArray *options = SCIArrayIvar(view, "_optionViews") ?: SCIArrayIvar(view, "_voteOptionViews") ?: SCIArrayIvar(view, "_options");
            if (options.count > 0) SCIApplyStoryPollVoteCounts(view, options);
        }
        
        for (UIView *subview in view.subviews) {
            [stack addObject:subview];
        }
    }
}
%end

%end // group SCIStoryPollVoteCountsHooks

#pragma mark - Entry Point

extern "C" void SCIInstallStoryPollVoteCountsHooksIfEnabled(void) {
    if (![SCIUtils getBoolPref:@"story_poll_vote_counts"]) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIStoryPollVoteCountsHooks);
    });
}
