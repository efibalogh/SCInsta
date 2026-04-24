// Reusable IG private API helper. Uses active session auth header.

#import "SCIInstagramAPI.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <sys/sysctl.h>

#define SCI_API_BASE @"https://i.instagram.com/api/v1/"
#define SCI_APP_ID   @"124024574287414"

static NSString *sciUserAgent(void) {
    static NSString *ua = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *version = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"424.0.0";
        char machine[64] = {0};
        size_t size = sizeof(machine);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        NSString *device = machine[0] ? [NSString stringWithUTF8String:machine] : @"iPhone15,2";
        NSString *iosVersion = [[UIDevice currentDevice].systemVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"];
        NSString *locale = [NSLocale currentLocale].localeIdentifier ?: @"en_US";
        NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
        UIScreen *screen = [UIScreen mainScreen];
        ua = [NSString stringWithFormat:@"Instagram %@ (%@; iOS %@; %@; %@; scale=%.2f; %.0fx%.0f; 0)",
              version,
              device,
              iosVersion,
              locale,
              language,
              screen.scale,
              screen.nativeBounds.size.width,
              screen.nativeBounds.size.height];
    });
    return ua;
}

static id sciCurrentUserSession(void) {
    @try {
        UIApplication *application = [UIApplication sharedApplication];
        NSMutableArray *windows = [NSMutableArray array];
        if (application.keyWindow) {
            [windows addObject:application.keyWindow];
        }
        for (UIWindow *window in application.windows) {
            if (window) [windows addObject:window];
        }
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window) [windows addObject:window];
            }
        }
        for (id window in windows) {
            if ([window respondsToSelector:@selector(userSession)]) {
                id session = [window valueForKey:@"userSession"];
                if (session) return session;
            }
        }
    } @catch (__unused NSException *exception) {
    }
    return nil;
}

static NSString *sciAuthHeader(void) {
    @try {
        id session = sciCurrentUserSession();
        SEL authHeaderManagerSel = NSSelectorFromString(@"authHeaderManager");
        if (!session || ![session respondsToSelector:authHeaderManagerSel]) return nil;
        id manager = ((id (*)(id, SEL))objc_msgSend)(session, authHeaderManagerSel);
        SEL authHeaderSel = NSSelectorFromString(@"authHeader");
        if (!manager || ![manager respondsToSelector:authHeaderSel]) return nil;
        id header = ((id (*)(id, SEL))objc_msgSend)(manager, authHeaderSel);
        if ([header isKindOfClass:[NSString class]] && [(NSString *)header length] > 0) {
            return (NSString *)header;
        }
    } @catch (__unused NSException *exception) {
    }
    return nil;
}

static NSString *sciFormEncode(NSDictionary *params) {
    if (!params.count) return @"";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    for (NSString *key in params) {
        NSString *value = [NSString stringWithFormat:@"%@", params[key]];
        NSString *encodedKey = [key stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
        NSString *encodedValue = [value stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
        [parts addObject:[NSString stringWithFormat:@"%@=%@", encodedKey, encodedValue]];
    }
    return [parts componentsJoinedByString:@"&"];
}

static NSMutableURLRequest *sciBuildRequest(NSString *method, NSURL *url, NSDictionary *body) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method ?: @"GET";

    [request setValue:sciUserAgent() forHTTPHeaderField:@"User-Agent"];
    [request setValue:SCI_APP_ID forHTTPHeaderField:@"X-IG-App-ID"];
    [request setValue:@"WIFI" forHTTPHeaderField:@"X-IG-Connection-Type"];
    [request setValue:@"en-US" forHTTPHeaderField:@"Accept-Language"];

    NSString *auth = sciAuthHeader();
    if (auth.length > 0) {
        [request setValue:auth forHTTPHeaderField:@"Authorization"];
    }

    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url]) {
        if ([cookie.name isEqualToString:@"csrftoken"]) {
            [request setValue:cookie.value forHTTPHeaderField:@"X-CSRFToken"];
            break;
        }
    }

    if (body) {
        request.HTTPBody = [sciFormEncode(body) dataUsingEncoding:NSUTF8StringEncoding];
        [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8"
       forHTTPHeaderField:@"Content-Type"];
    }

    return request;
}

static void sciPerformRequest(NSMutableURLRequest *request, SCIAPICompletion completion) {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        NSDictionary *parsedResponse = nil;
        if (data.length > 0) {
            @try {
                id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([parsed isKindOfClass:[NSDictionary class]]) {
                    parsedResponse = (NSDictionary *)parsed;
                }
            } @catch (__unused NSException *exception) {
            }
        }

        if (!completion) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(parsedResponse, error);
        });
    }];
    [task resume];
}

@implementation SCIInstagramAPI

+ (void)sendRequestWithMethod:(NSString *)method
                         path:(NSString *)path
                         body:(NSDictionary *)body
                   completion:(SCIAPICompletion)completion {
    NSString *cleanPath = [path hasPrefix:@"/"] ? [path substringFromIndex:1] : path;
    NSURL *url = [NSURL URLWithString:[SCI_API_BASE stringByAppendingString:cleanPath ?: @""]];
    if (!url) {
        if (completion) completion(nil, nil);
        return;
    }
    sciPerformRequest(sciBuildRequest(method, url, body), completion);
}

+ (void)followUserPK:(NSString *)pk completion:(SCIAPICompletion)completion {
    if (pk.length == 0) {
        if (completion) completion(nil, nil);
        return;
    }
    [self sendRequestWithMethod:@"POST"
                           path:[NSString stringWithFormat:@"friendships/create/%@/", pk]
                           body:@{@"user_id": pk, @"radio_type": @"wifi-none"}
                     completion:completion];
}

+ (void)unfollowUserPK:(NSString *)pk completion:(SCIAPICompletion)completion {
    if (pk.length == 0) {
        if (completion) completion(nil, nil);
        return;
    }
    [self sendRequestWithMethod:@"POST"
                           path:[NSString stringWithFormat:@"friendships/destroy/%@/", pk]
                           body:@{@"user_id": pk, @"radio_type": @"wifi-none"}
                     completion:completion];
}

+ (void)fetchFriendshipStatusesForPKs:(NSArray<NSString *> *)pks
                           completion:(SCIAPIStatusesCompletion)completion {
    if (pks.count == 0) {
        if (completion) completion(nil, nil);
        return;
    }
    [self sendRequestWithMethod:@"POST"
                           path:@"friendships/show_many/"
                           body:@{@"user_ids": [pks componentsJoinedByString:@","]}
                     completion:^(NSDictionary *response, NSError *error) {
        NSDictionary *statuses = nil;
        id raw = response[@"friendship_statuses"];
        if ([raw isKindOfClass:[NSDictionary class]]) {
            statuses = (NSDictionary *)raw;
        }
        if (completion) completion(statuses, error);
    }];
}

@end
