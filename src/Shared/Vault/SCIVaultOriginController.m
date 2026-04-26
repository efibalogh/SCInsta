#import "SCIVaultOriginController.h"

#import <objc/message.h>

#import "SCIVaultFile.h"
#import "SCIVaultSaveMetadata.h"
#import "../../Utils.h"
#import "../ActionButton/ActionButtonLookupUtils.h"

static NSString *SCIVaultStringValue(id value) {
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

static NSString *SCIVaultStringForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;
    id value = SCIObjectForSelector(target, selectorName);
    if (!value) value = SCIKVCObject(target, selectorName);
    return SCIVaultStringValue(value);
}

static NSURL *SCIVaultURLForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;
    id value = SCIObjectForSelector(target, selectorName);
    if (!value) value = SCIKVCObject(target, selectorName);
    if ([value isKindOfClass:[NSURL class]]) return value;
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return [NSURL URLWithString:(NSString *)value];
    }
    return nil;
}

static id SCIVaultNestedObjectForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;
    id value = SCIObjectForSelector(target, selectorName);
    if (!value) value = SCIKVCObject(target, selectorName);
    if ([value isKindOfClass:[NSArray class]]) {
        return ((NSArray *)value).firstObject;
    }
    return value;
}

static NSString *SCIVaultRecursiveStringForSelectors(id target, NSArray<NSString *> *selectorNames, NSInteger depth) {
    if (!target || depth > 3) return nil;

    for (NSString *selectorName in selectorNames) {
        NSString *value = SCIVaultStringForSelector(target, selectorName);
        if (value.length > 0) return value;
    }

    for (NSString *selectorName in @[@"media", @"item", @"storyItem", @"visualMessage", @"explorePostInFeed", @"rootItem", @"clipsItem", @"clipsMedia", @"post"]) {
        id nested = SCIVaultNestedObjectForSelector(target, selectorName);
        if (!nested || nested == target) continue;
        NSString *value = SCIVaultRecursiveStringForSelectors(nested, selectorNames, depth + 1);
        if (value.length > 0) return value;
    }

    return nil;
}

static NSURL *SCIVaultRecursiveURLForSelectors(id target, NSArray<NSString *> *selectorNames, NSInteger depth) {
    if (!target || depth > 3) return nil;

    for (NSString *selectorName in selectorNames) {
        NSURL *value = SCIVaultURLForSelector(target, selectorName);
        if (value) return value;
    }

    for (NSString *selectorName in @[@"media", @"item", @"storyItem", @"visualMessage", @"explorePostInFeed", @"rootItem", @"clipsItem", @"clipsMedia", @"post"]) {
        id nested = SCIVaultNestedObjectForSelector(target, selectorName);
        if (!nested || nested == target) continue;
        NSURL *value = SCIVaultRecursiveURLForSelectors(nested, selectorNames, depth + 1);
        if (value) return value;
    }

    return nil;
}

static id SCIVaultUserFromMedia(id media) {
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
            id user = SCIVaultUserFromMedia(nested);
            if (user) return user;
        }
    }

    return nil;
}

static NSString *SCIVaultProfileURLStringForUsername(NSString *username) {
    NSString *encodedUsername = [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    return encodedUsername.length > 0 ? [NSString stringWithFormat:@"instagram://user?username=%@", encodedUsername] : nil;
}

static NSString *SCIVaultMediaURLStringFromMetadata(SCIVaultSaveMetadata *metadata) {
    if (metadata.sourceMediaURLString.length > 0) return metadata.sourceMediaURLString;
    if (metadata.sourceMediaCode.length > 0) {
        NSString *pathComponent = (metadata.source == SCIVaultSourceReels) ? @"reel" : @"p";
        return [NSString stringWithFormat:@"https://www.instagram.com/%@/%@/", pathComponent, metadata.sourceMediaCode];
    }
    return nil;
}

@implementation SCIVaultOriginController

+ (void)populateProfileMetadata:(SCIVaultSaveMetadata *)metadata username:(NSString *)username user:(id)user {
    if (!metadata) return;

    if (username.length > 0) {
        metadata.sourceUsername = username;
        if (metadata.sourceProfileURLString.length == 0) {
            metadata.sourceProfileURLString = SCIVaultProfileURLStringForUsername(username);
        }
    }

    NSString *userPK = SCIVaultStringForSelector(user, @"pk");
    if (userPK.length == 0) userPK = SCIVaultStringForSelector(user, @"id");
    if (userPK.length > 0) metadata.sourceUserPK = userPK;

    NSURL *profileURL = nil;
    for (NSString *selectorName in @[@"profileURL", @"profileUrl", @"url"]) {
        profileURL = SCIVaultURLForSelector(user, selectorName);
        if (profileURL) break;
    }
    if (!profileURL && username.length > 0) {
        profileURL = [NSURL URLWithString:SCIVaultProfileURLStringForUsername(username)];
    }
    if (profileURL) metadata.sourceProfileURLString = profileURL.absoluteString;
}

+ (void)populateMetadata:(SCIVaultSaveMetadata *)metadata fromMedia:(id)media {
    if (!metadata || !media) return;

    NSString *username = SCIUsernameFromMediaObject(media);
    id user = SCIVaultUserFromMedia(media);
    [self populateProfileMetadata:metadata username:username user:user];

    NSString *mediaPK = SCIVaultRecursiveStringForSelectors(media, @[@"pk", @"id", @"mediaID", @"mediaId"], 0);
    if (mediaPK.length > 0) metadata.sourceMediaPK = mediaPK;

    NSString *mediaCode = SCIVaultRecursiveStringForSelectors(media, @[@"code", @"shortCode", @"shortcode", @"mediaCode", @"mediaShortcode", @"shortCodeToken"], 0);
    if (mediaCode.length > 0) metadata.sourceMediaCode = mediaCode;

    NSURL *mediaURL = SCIVaultRecursiveURLForSelectors(media, @[@"permalink", @"permaLink", @"shareURL", @"shareUrl", @"canonicalURL", @"canonicalUrl", @"permalinkURL", @"instagramURL", @"instagramUrl", @"webURL", @"webUrl"], 0);
    if (!mediaURL) {
        NSString *generatedURLString = SCIVaultMediaURLStringFromMetadata(metadata);
        if (generatedURLString.length > 0) {
            mediaURL = [NSURL URLWithString:generatedURLString];
        }
    }
    if (mediaURL) metadata.sourceMediaURLString = mediaURL.absoluteString;
}

+ (BOOL)openOriginalPostForVaultFile:(SCIVaultFile *)file {
    NSURL *url = [file preferredOriginalMediaURL];
    return url ? [SCIUtils openInstagramMediaURL:url] : NO;
}

+ (BOOL)openProfileForVaultFile:(SCIVaultFile *)file {
    if (file.sourceUsername.length > 0) {
        return [SCIUtils openInstagramProfileForUsername:file.sourceUsername];
    }
    NSURL *url = [file preferredProfileURL];
    return url ? [SCIUtils openInstagramMediaURL:url] : NO;
}

@end
