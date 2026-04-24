// Shows whether the current profile user follows you.

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Networking/SCIInstagramAPI.h"
#import <objc/runtime.h>

static NSInteger const kSCIFollowBadgeTag = 99788;
static const void *kSCIFollowStatusAssocKey = &kSCIFollowStatusAssocKey;

static NSString *SCIPKFromUserObject(id userObject) {
    if (!userObject) return nil;
    Ivar pkIvar = NULL;
    for (Class cls = [userObject class]; cls && !pkIvar; cls = class_getSuperclass(cls)) {
        pkIvar = class_getInstanceVariable(cls, "_pk");
    }
    if (!pkIvar) return nil;
    id pk = object_getIvar(userObject, pkIvar);
    return pk ? [pk description] : nil;
}

static NSString *SCICurrentUserPK(void) {
    @try {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in scene.windows) {
                id session = [window valueForKey:@"userSession"];
                if (!session) continue;
                id user = [session valueForKey:@"user"];
                if (!user) continue;
                NSString *pk = SCIPKFromUserObject(user);
                if (pk.length > 0) return pk;
            }
        }
    } @catch (__unused NSException *exception) {
    }
    return nil;
}

static NSNumber *SCIGetFollowStatusForController(id controller) {
    return objc_getAssociatedObject(controller, kSCIFollowStatusAssocKey);
}

static void SCISetFollowStatusForController(id controller, NSNumber *status) {
    objc_setAssociatedObject(controller, kSCIFollowStatusAssocKey, status, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIView *SCIProfileStatContainer(UIViewController *controller) {
    if (!controller.view) return nil;

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:controller.view];
    while (stack.count > 0) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];

        if ([NSStringFromClass([view class]) containsString:@"StatButtonContainerView"]) {
            return view;
        }

        [stack addObjectsFromArray:view.subviews];
    }
    return nil;
}

static void SCIRenderFollowBadge(UIViewController *controller) {
    NSNumber *status = SCIGetFollowStatusForController(controller);
    if (!status) return;

    UIView *container = SCIProfileStatContainer(controller);
    if (!container) return;

    UIView *existing = [container viewWithTag:kSCIFollowBadgeTag];
    [existing removeFromSuperview];

    BOOL followsYou = status.boolValue;
    UILabel *badge = [[UILabel alloc] init];
    badge.tag = kSCIFollowBadgeTag;
    badge.text = followsYou ? @"FOLLOWING YOU" : @"NOT FOLLOWING YOU";
    badge.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    badge.textColor = followsYou
        ? [UIColor colorWithRed:0.30 green:0.75 blue:0.40 alpha:1.0]
        : [UIColor colorWithRed:0.85 green:0.30 blue:0.30 alpha:1.0];
    [badge sizeToFit];

    CGFloat xOrigin = 0.0;
    for (UIView *subview in container.subviews) {
        if (!subview.isHidden && CGRectGetWidth(subview.frame) > 0.0) {
            xOrigin = CGRectGetMinX(subview.frame);
            break;
        }
    }

    badge.frame = CGRectMake(xOrigin,
                             CGRectGetHeight(container.bounds) - CGRectGetHeight(badge.bounds) - 2.0,
                             CGRectGetWidth(badge.bounds),
                             CGRectGetHeight(badge.bounds));
    [container addSubview:badge];
}

%hook IGProfileViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (![SCIUtils getBoolPref:@"follow_indicator"]) return;

    NSNumber *cachedStatus = SCIGetFollowStatusForController(self);
    if (cachedStatus) {
        SCIRenderFollowBadge((UIViewController *)self);
        return;
    }

    id profileUser = nil;
    @try {
        profileUser = [(id)self valueForKey:@"user"];
    } @catch (__unused NSException *exception) {
    }
    if (!profileUser) return;

    NSString *profilePK = SCIPKFromUserObject(profileUser);
    NSString *currentUserPK = SCICurrentUserPK();
    if (profilePK.length == 0 || currentUserPK.length == 0 || [profilePK isEqualToString:currentUserPK]) {
        return;
    }

    NSString *path = [NSString stringWithFormat:@"friendships/show/%@/", profilePK];
    __weak UIViewController *weakController = (UIViewController *)self;
    [SCIInstagramAPI sendRequestWithMethod:@"GET" path:path body:nil completion:^(NSDictionary *response, NSError *error) {
        if (error || !response) return;
        BOOL followsYou = [response[@"followed_by"] boolValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *strongController = weakController;
            if (!strongController) return;
            SCISetFollowStatusForController(strongController, @(followsYou));
            SCIRenderFollowBadge(strongController);
        });
    }];
}

- (void)viewDidLayoutSubviews {
    %orig;
    if ([SCIUtils getBoolPref:@"follow_indicator"]) {
        SCIRenderFollowBadge((UIViewController *)self);
    }
}

%end
