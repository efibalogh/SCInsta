#import "../../Utils.h"

#pragma mark - Hook group

%group SCIDMInteractionConfirmHooks

// ─── Double-tap like ────────────────────────────────────────────────

%hook IGDirectMessageSectionController

- (void)messageCellDidDoubleTap:(id)cell {
    if (![SCIUtils getBoolPref:@"dm_message_double_tap_confirm"]) {
        %orig;
        return;
    }

    [SCIUtils showConfirmation:^{ %orig; }
                         title:@"Confirm Message Double Tap"
                       message:@"Are you sure you want to double tap this message?"];
}

%end

// ─── Emoji reaction picker ──────────────────────────────────────────
// When the user long-presses a message and picks an emoji, the call
// chain is:
//
//   IGDirectMessageReactionSelectionViewController
//       -reactionContainerView:didSelectEmojiAtIndex:       ← we hook HERE
//           → internally delegates to IGDirectMessageReactionController
//               -messageReactionSelectionViewController:didToggleEmoji:…
//
// We ONLY hook the picker VC entry point. Hooking the delegate too
// causes a double-prompt because %orig on the picker method cascades
// into the delegate.

%hook IGDirectMessageReactionSelectionViewController

- (void)reactionContainerView:(id)containerView didSelectEmojiAtIndex:(NSInteger)index {
    if (![SCIUtils getBoolPref:@"dm_message_reaction_confirm"]) {
        %orig;
        return;
    }

    [SCIUtils showConfirmation:^{ %orig; }
                         title:@"Confirm Message Reaction"
                       message:@"Are you sure you want to react to this message?"];
}

%end

%end // group SCIDMInteractionConfirmHooks

#pragma mark - Entry point

extern "C" void SCIInstallDMInteractionConfirmHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SCIDMInteractionConfirmHooks);
    });
}
