#import "SCIGalleryOriginController.h"

#import <objc/message.h>
#import <objc/runtime.h>

#import "SCIGalleryFile.h"
#import "SCIGallerySaveMetadata.h"
#import "../../Utils.h"
#import "../ActionButton/ActionButtonLookupUtils.h"

static NSString *SCIGalleryStringValue(id value) {
    if (!value) return nil;
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value length] > 0 ? value : nil;
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *string = [value stringValue];
        return string.length > 0 ? string : nil;
    }
    if ([value respondsToSelector:@selector(description)]) {
        NSString *string = [value description];
        return string.length > 0 ? string : nil;
    }
    return nil;
}

static id SCIGalleryFieldCacheValue(id target, NSString *key) {
    if (!target || key.length == 0) return nil;
    if ([target isKindOfClass:[NSDictionary class]]) {
        id value = ((NSDictionary *)target)[key];
        return [value isKindOfClass:[NSNull class]] ? nil : value;
    }

    Ivar fieldCacheIvar = NULL;
    @try {
        for (Class cls = object_getClass(target); cls && !fieldCacheIvar; cls = class_getSuperclass(cls)) {
            fieldCacheIvar = class_getInstanceVariable(cls, "_fieldCache");
        }
    } @catch (__unused NSException *exception) {
        return nil;
    }
    if (!fieldCacheIvar) return nil;

    id fieldCache = nil;
    @try {
        fieldCache = object_getIvar(target, fieldCacheIvar);
    } @catch (__unused NSException *exception) {
        return nil;
    }
    if (![fieldCache isKindOfClass:[NSDictionary class]]) return nil;

    id value = ((NSDictionary *)fieldCache)[key];
    return [value isKindOfClass:[NSNull class]] ? nil : value;
}

static NSTimeInterval SCIGalleryTimestampFromValue(id value) {
    if (!value || [value isKindOfClass:[NSNull class]]) return 0.0;
    if ([value isKindOfClass:[NSDate class]]) return [(NSDate *)value timeIntervalSince1970];

    double raw = 0.0;
    if ([value respondsToSelector:@selector(doubleValue)]) {
        raw = [value doubleValue];
    }
    if (raw <= 0.0) return 0.0;
    if (raw > 1e15) raw /= 1000000.0;
    else if (raw > 1e12) raw /= 1000.0;
    return raw;
}

static NSDate *SCIGalleryDateFromTimestampValue(id value) {
    NSTimeInterval timestamp = SCIGalleryTimestampFromValue(value);
    if (timestamp <= 0.0) return nil;
    return [NSDate dateWithTimeIntervalSince1970:timestamp];
}

static NSString *SCIGalleryStringForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;
    id value = SCIObjectForSelector(target, selectorName);
    if (!value) value = SCIKVCObject(target, selectorName);
    return SCIGalleryStringValue(value);
}

static NSURL *SCIGalleryURLForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;
    id value = SCIObjectForSelector(target, selectorName);
    if (!value) value = SCIKVCObject(target, selectorName);
    if ([value isKindOfClass:[NSURL class]]) return value;
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return [NSURL URLWithString:(NSString *)value];
    }
    return nil;
}

static id SCIGalleryNestedObjectForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;
    id value = SCIObjectForSelector(target, selectorName);
    if (!value) value = SCIKVCObject(target, selectorName);
    if ([value isKindOfClass:[NSArray class]]) {
        return ((NSArray *)value).firstObject;
    }
    return value;
}

static NSString *SCIGalleryRecursiveStringForSelectors(id target, NSArray<NSString *> *selectorNames, NSInteger depth) {
    if (!target || depth > 3) return nil;

    for (NSString *selectorName in selectorNames) {
        NSString *value = SCIGalleryStringForSelector(target, selectorName);
        if (value.length > 0) return value;
    }

    for (NSString *selectorName in @[@"media", @"item", @"storyItem", @"visualMessage", @"explorePostInFeed", @"rootItem", @"clipsItem", @"clipsMedia", @"post"]) {
        id nested = SCIGalleryNestedObjectForSelector(target, selectorName);
        if (!nested || nested == target) continue;
        NSString *value = SCIGalleryRecursiveStringForSelectors(nested, selectorNames, depth + 1);
        if (value.length > 0) return value;
    }

    return nil;
}

static NSDate *SCIGalleryRecursiveDateForKeys(id target, NSArray<NSString *> *keys, NSInteger depth) {
    if (!target || depth > 3) return nil;

    for (NSString *key in keys) {
        id value = SCIObjectForSelector(target, key);
        if (!value) value = SCIKVCObject(target, key);
        if (!value) value = SCIGalleryFieldCacheValue(target, key);
        NSDate *date = SCIGalleryDateFromTimestampValue(value);
        if (date) return date;
    }

    for (NSString *selectorName in @[@"media", @"item", @"storyItem", @"visualMessage", @"explorePostInFeed", @"rootItem", @"clipsItem", @"clipsMedia", @"post"]) {
        id nested = SCIGalleryNestedObjectForSelector(target, selectorName);
        if (!nested || nested == target) continue;
        NSDate *date = SCIGalleryRecursiveDateForKeys(nested, keys, depth + 1);
        if (date) return date;
    }

    return nil;
}

static NSURL *SCIGalleryRecursiveURLForSelectors(id target, NSArray<NSString *> *selectorNames, NSInteger depth) {
    if (!target || depth > 3) return nil;

    for (NSString *selectorName in selectorNames) {
        NSURL *value = SCIGalleryURLForSelector(target, selectorName);
        if (value) return value;
    }

    for (NSString *selectorName in @[@"media", @"item", @"storyItem", @"visualMessage", @"explorePostInFeed", @"rootItem", @"clipsItem", @"clipsMedia", @"post"]) {
        id nested = SCIGalleryNestedObjectForSelector(target, selectorName);
        if (!nested || nested == target) continue;
        NSURL *value = SCIGalleryRecursiveURLForSelectors(nested, selectorNames, depth + 1);
        if (value) return value;
    }

    return nil;
}

static id SCIGalleryUserFromMedia(id media) {
    if (!media) return nil;

    for (NSString *selectorName in @[@"user", @"owner", @"author", @"creator", @"actor", @"profileUser"]) {
        id user = SCIObjectForSelector(media, selectorName);
        if (!user) user = SCIKVCObject(media, selectorName);
        if (user) return user;
    }

    for (NSString *nestedSelector in @[@"media", @"item", @"storyItem", @"visualMessage"]) {
        id nested = SCIObjectForSelector(media, nestedSelector);
        if (!nested) nested = SCIKVCObject(media, nestedSelector);
        if (nested && nested != media) {
            id user = SCIGalleryUserFromMedia(nested);
            if (user) return user;
        }
    }

    return nil;
}

static NSString *SCIGalleryProfileURLStringForUsername(NSString *username) {
    NSString *encodedUsername = [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    return encodedUsername.length > 0 ? [NSString stringWithFormat:@"instagram://user?username=%@", encodedUsername] : nil;
}

static NSString *SCIGalleryMediaURLStringFromMetadata(SCIGallerySaveMetadata *metadata) {
    if (metadata.sourceMediaURLString.length > 0) return metadata.sourceMediaURLString;
    if (metadata.sourceMediaCode.length > 0) {
        NSString *pathComponent = (metadata.source == SCIGallerySourceReels) ? @"reel" : @"p";
        return [NSString stringWithFormat:@"https://www.instagram.com/%@/%@/", pathComponent, metadata.sourceMediaCode];
    }
    return nil;
}

@implementation SCIGalleryOriginController

+ (void)populateProfileMetadata:(SCIGallerySaveMetadata *)metadata username:(NSString *)username user:(id)user {
    if (!metadata) return;

    if (username.length > 0) {
        metadata.sourceUsername = username;
        if (metadata.sourceProfileURLString.length == 0) {
            metadata.sourceProfileURLString = SCIGalleryProfileURLStringForUsername(username);
        }
    }

    NSString *userPK = SCIGalleryStringForSelector(user, @"pk");
    if (userPK.length == 0) userPK = SCIGalleryStringForSelector(user, @"id");
    if (userPK.length > 0) metadata.sourceUserPK = userPK;

    NSURL *profileURL = nil;
    for (NSString *selectorName in @[@"profileURL", @"profileUrl", @"url"]) {
        profileURL = SCIGalleryURLForSelector(user, selectorName);
        if (profileURL) break;
    }
    if (!profileURL && username.length > 0) {
        profileURL = [NSURL URLWithString:SCIGalleryProfileURLStringForUsername(username)];
    }
    if (profileURL) metadata.sourceProfileURLString = profileURL.absoluteString;
}

+ (void)populateMetadata:(SCIGallerySaveMetadata *)metadata fromMedia:(id)media {
    if (!metadata || !media) return;

    NSString *username = SCIUsernameFromMediaObject(media);
    id user = SCIGalleryUserFromMedia(media);
    [self populateProfileMetadata:metadata username:username user:user];

    NSString *mediaPK = SCIGalleryRecursiveStringForSelectors(media, @[@"pk", @"id", @"mediaID", @"mediaId"], 0);
    if (mediaPK.length > 0) metadata.sourceMediaPK = mediaPK;

    NSString *mediaCode = SCIGalleryRecursiveStringForSelectors(media, @[@"code", @"shortCode", @"shortcode", @"mediaCode", @"mediaShortcode", @"shortCodeToken"], 0);
    if (mediaCode.length > 0) metadata.sourceMediaCode = mediaCode;

    if (!metadata.importPostedDate) {
        NSDate *postedDate = SCIGalleryRecursiveDateForKeys(media, @[@"taken_at", @"takenAt", @"takenAtDate", @"device_timestamp", @"deviceTimestamp", @"created_at", @"createdAt", @"upload_time", @"uploadTime", @"published_time", @"publishedTime"], 0);
        if (postedDate) metadata.importPostedDate = postedDate;
    }

    NSURL *mediaURL = SCIGalleryRecursiveURLForSelectors(media, @[@"permalink", @"permaLink", @"shareURL", @"shareUrl", @"canonicalURL", @"canonicalUrl", @"permalinkURL", @"instagramURL", @"instagramUrl", @"webURL", @"webUrl"], 0);
    if (!mediaURL) {
        NSString *generatedURLString = SCIGalleryMediaURLStringFromMetadata(metadata);
        if (generatedURLString.length > 0) {
            mediaURL = [NSURL URLWithString:generatedURLString];
        }
    }
    if (mediaURL) metadata.sourceMediaURLString = mediaURL.absoluteString;
}

+ (BOOL)openOriginalPostForGalleryFile:(SCIGalleryFile *)file {
    NSURL *url = [file preferredOriginalMediaURL];
    return url ? [SCIUtils openInstagramMediaURL:url] : NO;
}

+ (BOOL)openProfileForGalleryFile:(SCIGalleryFile *)file {
    if (file.sourceUsername.length > 0) {
        return [SCIUtils openInstagramProfileForUsername:file.sourceUsername];
    }
    NSURL *url = [file preferredProfileURL];
    return url ? [SCIUtils openInstagramMediaURL:url] : NO;
}

@end
