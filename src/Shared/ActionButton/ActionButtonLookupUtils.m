#import "ActionButtonLookupUtils.h"

#import <objc/runtime.h>
#import <objc/message.h>
#import <os/log.h>
#import <stdarg.h>

#import "../../Utils.h"

id SCIObjectForSelector(id target, NSString *selectorName) {
	if (!target || selectorName.length == 0) return nil;

	SEL selector = NSSelectorFromString(selectorName);
	if (![target respondsToSelector:selector]) return nil;

	return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

id SCIKVCObject(id target, NSString *key) {
	if (!target || key.length == 0) return nil;

	@try {
		return [target valueForKey:key];
	} @catch (__unused NSException *exception) {
		return nil;
	}
}

NSArray *SCIArrayFromCollection(id collection) {
	if (!collection ||
		[collection isKindOfClass:[NSDictionary class]] ||
		[collection isKindOfClass:[NSString class]] ||
		[collection isKindOfClass:[NSURL class]]) {
		return nil;
	}

	if ([collection isKindOfClass:[NSArray class]]) {
		return collection;
	}

	if ([collection isKindOfClass:[NSOrderedSet class]]) {
		return [(NSOrderedSet *)collection array];
	}

	if ([collection isKindOfClass:[NSSet class]]) {
		return [(NSSet *)collection allObjects];
	}

	if ([collection conformsToProtocol:@protocol(NSFastEnumeration)]) {
		NSMutableArray *array = [NSMutableArray array];
		for (id item in collection) {
			[array addObject:item];
		}
		return array;
	}

	return nil;
}

NSURL *SCIURLFromValue(id value) {
	if (!value) return nil;

	if ([value isKindOfClass:[NSURL class]]) {
		return value;
	}

	if ([value isKindOfClass:[NSString class]]) {
		NSString *string = (NSString *)value;
		if (string.length == 0) return nil;
		return [NSURL URLWithString:string];
	}

	return nil;
}

NSString *SCIStringFromValue(id value) {
	if ([value isKindOfClass:[NSString class]]) return value;
	if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
	return nil;
}

NSString *SCIClassName(id object) {
	return object ? NSStringFromClass([object class]) : @"(nil)";
}

static NSString *SCIShallowUsernameFromObject(id object);

static void SCIDMTrace(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[SCInsta][DMTrace] %{public}@", message ?: @"(nil)");
}

static BOOL SCIRelationNameLooksRelevant(NSString *name) {
	if (name.length == 0) return NO;
	NSString *lower = name.lowercaseString;
	for (NSString *token in @[@"user", @"sender", @"author", @"owner", @"participant", @"thread", @"message", @"item", @"media"]) {
		if ([lower containsString:token]) return YES;
	}
	return NO;
}

static BOOL SCIAppendUniqueObject(NSMutableArray<NSDictionary *> *queue,
								  NSMutableSet<NSValue *> *seen,
								  id object,
								  NSString *path,
								  NSUInteger depth) {
	if (!object) return NO;
	if ([object isKindOfClass:[NSString class]] || [object isKindOfClass:[NSNumber class]] || [object isKindOfClass:[NSURL class]] || [object isKindOfClass:[NSDate class]]) {
		return NO;
	}
	NSValue *key = [NSValue valueWithNonretainedObject:object];
	if ([seen containsObject:key]) return NO;
	[seen addObject:key];
	[queue addObject:@{
		@"obj": object,
		@"path": path ?: @"(unknown)",
		@"depth": @(depth)
	}];
	return YES;
}

static NSArray<NSString *> *SCIUsernameTraversalKeys(void) {
	static NSArray<NSString *> *keys;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		keys = @[
			@"user", @"owner", @"author", @"sender", @"senderUser", @"fromUser", @"messageUser",
			@"participantUser", @"participants", @"threadUser", @"threadUsers", @"thread",
			@"otherUser", @"recipientUser", @"peerUser", @"opponentUser", @"targetUser",
			@"message", @"messageItem", @"directMessage", @"visualMessage", @"media", @"item",
			@"items", @"mediaItems", @"storyItem", @"reelShare", @"xmaMediaShareItem",
			@"parentMessage", @"currentMessage"
		];
	});
	return keys;
}

static BOOL SCIPathLooksLikeSessionPath(NSString *path) {
	if (path.length == 0) return NO;
	NSString *lower = path.lowercaseString;
	return ([lower containsString:@"usersession"] ||
			[lower containsString:@"_usersession"] ||
			[lower containsString:@"->session"] ||
			[lower containsString:@".session"]);
}

static NSString *SCIUsernameFromObjectGraph(id root,
											NSUInteger maxDepth,
											NSString *usernameToAvoid,
											NSString *__autoreleasing *outPath) {
	if (!root) return nil;

	NSMutableArray<NSDictionary *> *queue = [NSMutableArray array];
	NSMutableSet<NSValue *> *seen = [NSMutableSet set];
	SCIAppendUniqueObject(queue, seen, root, @"root", 0);

	NSUInteger processed = 0;
	const NSUInteger kMaxNodes = 220;

	while (queue.count > 0 && processed < kMaxNodes) {
		NSDictionary *node = queue.firstObject;
		[queue removeObjectAtIndex:0];
		processed++;

		id object = node[@"obj"];
		NSString *path = node[@"path"];
		NSUInteger depth = [node[@"depth"] unsignedIntegerValue];

		NSString *username = SCIShallowUsernameFromObject(object);
		if (username.length > 0) {
			BOOL isAvoided = (usernameToAvoid.length > 0 &&
							  [username caseInsensitiveCompare:usernameToAvoid] == NSOrderedSame);
			BOOL isSessionPath = SCIPathLooksLikeSessionPath(path);
			if (!isAvoided && !isSessionPath) {
				if (outPath) *outPath = path;
				return username;
			}
		}
		if (depth >= maxDepth) continue;

		for (NSString *key in SCIUsernameTraversalKeys()) {
			id child = SCIObjectForSelector(object, key);
			if (!child) child = SCIKVCObject(object, key);
			if (!child) continue;

			NSArray *array = SCIArrayFromCollection(child);
			if (array) {
				NSUInteger index = 0;
				for (id item in array) {
					SCIAppendUniqueObject(queue, seen, item, [NSString stringWithFormat:@"%@.%@[%lu]", path, key, (unsigned long)index], depth + 1);
					index++;
				}
				continue;
			}

			SCIAppendUniqueObject(queue, seen, child, [NSString stringWithFormat:@"%@.%@", path, key], depth + 1);
		}

		unsigned int ivarCount = 0;
		Ivar *ivars = class_copyIvarList([object class], &ivarCount);
		for (unsigned int i = 0; i < ivarCount; i++) {
			Ivar ivar = ivars[i];
			const char *type = ivar_getTypeEncoding(ivar);
			if (!type || type[0] != '@') continue;

			const char *rawName = ivar_getName(ivar);
			if (!rawName) continue;
			NSString *name = [NSString stringWithUTF8String:rawName];
			if (!SCIRelationNameLooksRelevant(name)) continue;

			id child = object_getIvar(object, ivar);
			if (!child) continue;
			SCIAppendUniqueObject(queue, seen, child, [NSString stringWithFormat:@"%@->%@", path, name], depth + 1);
		}
		free(ivars);
	}

	return nil;
}

static NSString *SCIUsernameFromUserObject(id user) {
	if (!user) return nil;

	id username = SCIObjectForSelector(user, @"username");
	if (!username) {
		username = SCIKVCObject(user, @"username");
	}
	if (!username) {
		username = SCIObjectForSelector(user, @"authorUsername");
	}
	if (!username) {
		username = SCIKVCObject(user, @"authorUsername");
	}
	if (!username) {
		username = SCIObjectForSelector(user, @"senderUsername");
	}
	if (!username) {
		username = SCIKVCObject(user, @"senderUsername");
	}

	if ([username isKindOfClass:[NSString class]] && [(NSString *)username length] > 0) {
		return (NSString *)username;
	}

	return nil;
}

NSString *SCICaptionFromMediaObject(id media) {
	if (!media) return nil;

	for (NSString *selectorName in @[@"fullCaptionString", @"captionString", @"caption", @"captionText", @"text"]) {
		SEL selector = NSSelectorFromString(selectorName);
		if (![media respondsToSelector:selector]) continue;

		@try {
			id result = ((id(*)(id, SEL))objc_msgSend)(media, selector);
			if ([result isKindOfClass:[NSString class]] && [(NSString *)result length] > 0) {
				return result;
			}
			if (result && ![result isKindOfClass:[NSString class]]) {
				for (NSString *textSelectorName in @[@"text", @"string", @"commentText", @"attributedString", @"rawText"]) {
					SEL textSelector = NSSelectorFromString(textSelectorName);
					if (![result respondsToSelector:textSelector]) continue;

					id text = ((id(*)(id, SEL))objc_msgSend)(result, textSelector);
					if ([text respondsToSelector:@selector(string)] && ![text isKindOfClass:[NSString class]]) {
						text = ((id(*)(id, SEL))objc_msgSend)(text, @selector(string));
					}
					if ([text isKindOfClass:[NSString class]] && [(NSString *)text length] > 0) {
						return text;
					}
				}
			}
		} @catch (__unused NSException *exception) {
		}
	}

	id capObj = SCIKVCObject(media, @"caption");
	if ([capObj isKindOfClass:[NSDictionary class]]) {
		id text = ((NSDictionary *)capObj)[@"text"];
		if ([text isKindOfClass:[NSString class]] && [(NSString *)text length] > 0) {
			return text;
		}
	} else if ([capObj isKindOfClass:[NSString class]] && [(NSString *)capObj length] > 0) {
		return capObj;
	}

	if (capObj && [capObj respondsToSelector:@selector(text)]) {
		@try {
			id text = ((id(*)(id, SEL))objc_msgSend)(capObj, @selector(text));
			if ([text isKindOfClass:[NSString class]] && [(NSString *)text length] > 0) {
				return text;
			}
		} @catch (__unused NSException *exception) {
		}
	}

	return nil;
}

static NSString *SCIShallowUsernameFromObject(id object) {
	if (!object) return nil;

	for (NSString *stringSelector in @[
		@"username",
		@"authorUsername",
		@"senderUsername",
		@"ownerUsername"
	]) {
		id value = SCIObjectForSelector(object, stringSelector);
		if (!value) value = SCIKVCObject(object, stringSelector);
		NSString *s = SCIStringFromValue(value);
		if (s.length > 0) return s;
	}

	for (NSString *userSelector in @[
		@"user",
		@"owner",
		@"author",
		@"sender",
		@"senderUser",
		@"messageUser",
		@"userObject",
		@"threadUser",
		@"participantUser"
	]) {
		id userObject = SCIObjectForSelector(object, userSelector);
		if (!userObject) userObject = SCIKVCObject(object, userSelector);
		NSString *username = SCIUsernameFromUserObject(userObject);
		if (username.length > 0) return username;
	}

	return nil;
}

NSString *SCISessionUsernameFromController(UIViewController *controller) {
	if (!controller) return nil;

	id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
	if (!dataSource) dataSource = SCIKVCObject(controller, @"dataSource");

	id userSession = [SCIUtils getIvarForObj:controller name:"_userSession"];
	if (!userSession) userSession = SCIKVCObject(controller, @"userSession");
	if (!userSession && dataSource) {
		userSession = [SCIUtils getIvarForObj:dataSource name:"_userSession"];
	}
	if (!userSession && dataSource) {
		userSession = SCIKVCObject(dataSource, @"userSession");
	}

	id user = SCIObjectForSelector(userSession, @"user");
	if (!user) user = SCIKVCObject(userSession, @"user");
	return SCIUsernameFromUserObject(user);
}

static NSArray<Class> *SCIClassesRespondingToClassSelector(NSString *selectorName) {
	if (selectorName.length == 0) return @[];

	static NSMutableDictionary<NSString *, id> *cache;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		cache = [NSMutableDictionary dictionary];
	});

	id cached = cache[selectorName];
	if (cached) {
		return (cached == NSNull.null) ? @[] : (NSArray<Class> *)cached;
	}

	SEL selector = NSSelectorFromString(selectorName);
	int count = objc_getClassList(NULL, 0);
	if (count <= 0) {
		cache[selectorName] = NSNull.null;
		return @[];
	}

	Class *classes = (Class *)calloc((size_t)count, sizeof(Class));
	count = objc_getClassList(classes, count);

	NSMutableArray<Class> *matches = [NSMutableArray array];
	for (int i = 0; i < count; i++) {
		Class cls = classes[i];
		if (!cls) continue;
		if (class_respondsToSelector(object_getClass(cls), selector)) {
			[matches addObject:cls];
		}
	}
	free(classes);

	cache[selectorName] = matches.count > 0 ? [matches copy] : NSNull.null;
	return matches;
}

static NSString *SCINonSessionUsernameFromUser(id user, NSString *sessionUsername) {
	NSString *username = SCIUsernameFromUserObject(user);
	if (username.length == 0) return nil;
	if (sessionUsername.length > 0 && [username caseInsensitiveCompare:sessionUsername] == NSOrderedSame) {
		return nil;
	}
	return username;
}

static NSString *SCIPKStringFromValue(id value) {
	if (!value) return nil;
	NSString *string = SCIStringFromValue(value);
	if (string.length > 0) return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([value respondsToSelector:@selector(integerValue)]) {
		return [NSString stringWithFormat:@"%lld", (long long)[value integerValue]];
	}
	return nil;
}

static BOOL SCIIsAllDigits(NSString *value) {
	if (value.length == 0) return NO;
	NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
	return [value rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

static NSString *SCINormalizedNumericString(NSString *value) {
	if (value.length == 0) return nil;
	NSUInteger index = 0;
	while (index + 1 < value.length && [value characterAtIndex:index] == '0') {
		index++;
	}
	return [value substringFromIndex:index];
}

static BOOL SCIPKStringsEqual(NSString *lhs, NSString *rhs) {
	if (lhs.length == 0 || rhs.length == 0) return NO;
	lhs = [lhs stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	rhs = [rhs stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (SCIIsAllDigits(lhs) && SCIIsAllDigits(rhs)) {
		return [SCINormalizedNumericString(lhs) isEqualToString:SCINormalizedNumericString(rhs)];
	}
	return [lhs caseInsensitiveCompare:rhs] == NSOrderedSame;
}

static NSString *SCIUserPKStringFromObject(id object) {
	if (!object) return nil;
	for (NSString *key in @[
		@"pk", @"PK", @"userPk", @"userPK", @"userId", @"userID", @"id", @"identifier",
		@"senderPk", @"senderPK", @"authorPk", @"authorPK", @"participantPk", @"participantPK"
	]) {
		id value = SCIObjectForSelector(object, key);
		if (!value) value = SCIKVCObject(object, key);
		NSString *pk = SCIPKStringFromValue(value);
		if (pk.length > 0) return pk;
	}
	return nil;
}

static NSString *SCIUsernameForSenderPKInObjectGraph(id root, NSString *senderPk, NSString *sessionUsername, NSString *__autoreleasing *outPath) {
	if (!root || senderPk.length == 0) return nil;

	NSMutableArray<NSDictionary *> *queue = [NSMutableArray array];
	NSMutableSet<NSValue *> *seen = [NSMutableSet set];
	SCIAppendUniqueObject(queue, seen, root, @"root", 0);

	NSUInteger processed = 0;
	const NSUInteger kMaxNodes = 260;

	static NSArray<NSString *> *traversalKeys;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		traversalKeys = @[
			@"user", @"owner", @"author", @"sender", @"senderUser", @"fromUser", @"messageUser",
			@"participantUser", @"participants", @"threadUser", @"threadUsers", @"thread",
			@"otherUser", @"recipientUser", @"peerUser", @"opponentUser", @"targetUser",
			@"users", @"members", @"recipients", @"recipient", @"recipientUsers",
			@"message", @"messageItem", @"directMessage", @"visualMessage", @"media", @"item",
			@"items", @"mediaItems", @"metadata", @"currentMessage", @"parentMessage"
		];
	});

	while (queue.count > 0 && processed < kMaxNodes) {
		NSDictionary *node = queue.firstObject;
		[queue removeObjectAtIndex:0];
		processed++;

		id object = node[@"obj"];
		NSString *path = node[@"path"];
		NSUInteger depth = [node[@"depth"] unsignedIntegerValue];

		NSString *objectPk = SCIUserPKStringFromObject(object);
		if (SCIPKStringsEqual(senderPk, objectPk)) {
			NSString *username = SCIUsernameFromUserObject(object);
			if (username.length > 0 &&
				(sessionUsername.length == 0 || [username caseInsensitiveCompare:sessionUsername] != NSOrderedSame)) {
				if (outPath) *outPath = path;
				return username;
			}
		}

		if (depth >= 7) continue;

		for (NSString *key in traversalKeys) {
			id child = SCIObjectForSelector(object, key);
			if (!child) child = SCIKVCObject(object, key);
			if (!child) continue;

			NSArray *array = SCIArrayFromCollection(child);
			if (array) {
				NSUInteger index = 0;
				for (id item in array) {
					SCIAppendUniqueObject(queue, seen, item, [NSString stringWithFormat:@"%@.%@[%lu]", path, key, (unsigned long)index], depth + 1);
					index++;
				}
				continue;
			}

			SCIAppendUniqueObject(queue, seen, child, [NSString stringWithFormat:@"%@.%@", path, key], depth + 1);
		}

		unsigned int ivarCount = 0;
		Ivar *ivars = class_copyIvarList([object class], &ivarCount);
		for (unsigned int i = 0; i < ivarCount; i++) {
			Ivar ivar = ivars[i];
			const char *type = ivar_getTypeEncoding(ivar);
			if (!type || type[0] != '@') continue;

			const char *rawName = ivar_getName(ivar);
			if (!rawName) continue;
			NSString *name = [NSString stringWithUTF8String:rawName];
			if (!SCIRelationNameLooksRelevant(name)) continue;

			id child = object_getIvar(object, ivar);
			if (!child) continue;
			SCIAppendUniqueObject(queue, seen, child, [NSString stringWithFormat:@"%@->%@", path, name], depth + 1);
		}
		free(ivars);
	}

	return nil;
}

static NSString *SCIDirectSenderPKFromMessage(id message) {
	if (!message) return nil;

	NSMutableArray *candidates = [NSMutableArray arrayWithObject:message];
	id envelope = SCIObjectForSelector(message, @"message");
	if (!envelope) envelope = SCIKVCObject(message, @"message");
	if (envelope) [candidates addObject:envelope];

	id metadata = SCIObjectForSelector(envelope ?: message, @"metadata");
	if (!metadata) metadata = SCIKVCObject(envelope ?: message, @"metadata");
	if (metadata) [candidates addObject:metadata];

	for (id candidate in candidates) {
		for (NSString *key in @[@"senderPk", @"senderPK", @"senderId", @"senderID", @"authorPk", @"authorPK", @"userPk", @"userPK"]) {
			id value = SCIObjectForSelector(candidate, key);
			if (!value) value = SCIKVCObject(candidate, key);
			NSString *pk = SCIPKStringFromValue(value);
			if (pk.length > 0) {
				SCIDMTrace(@"senderPk resolved from %@.%@ = %@", SCIClassName(candidate), key, pk);
				return pk;
			}
		}
	}

	SCIDMTrace(@"senderPk not found on currentMessage/message.metadata");
	return nil;
}

static id SCIDirectCacheFromController(UIViewController *controller) {
	if (!controller) return nil;

	id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
	if (!dataSource) dataSource = SCIKVCObject(controller, @"dataSource");

	for (id root in @[dataSource ?: (id)NSNull.null, controller ?: (id)NSNull.null]) {
		if (!root || root == (id)NSNull.null) continue;

		for (NSString *key in @[@"directCache", @"_directCache"]) {
			id cache = SCIObjectForSelector(root, key);
			if (!cache) cache = SCIKVCObject(root, key);
			if (!cache && [key hasPrefix:@"_"]) {
				cache = [SCIUtils getIvarForObj:root name:key.UTF8String];
			}
			if (cache) {
				SCIDMTrace(@"resolved directCache from %@.%@", SCIClassName(root), key);
				return cache;
			}
		}
	}

	return nil;
}

static id SCIDirectCacheUpdatesApplicatorFromController(UIViewController *controller) {
	if (!controller) return nil;

	id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
	if (!dataSource) dataSource = SCIKVCObject(controller, @"dataSource");

	for (id root in @[dataSource ?: (id)NSNull.null, controller ?: (id)NSNull.null]) {
		if (!root || root == (id)NSNull.null) continue;

		for (NSString *key in @[@"directCacheUpdatesApplicator", @"cacheUpdatesApplicator", @"_directCacheUpdatesApplicator"]) {
			id value = SCIObjectForSelector(root, key);
			if (!value) value = SCIKVCObject(root, key);
			if (!value && [key hasPrefix:@"_"]) {
				value = [SCIUtils getIvarForObj:root name:key.UTF8String];
			}
			if (value) {
				SCIDMTrace(@"resolved directCacheUpdatesApplicator from %@.%@", SCIClassName(root), key);
				return value;
			}
		}
	}

	return nil;
}

static NSString *SCIDirectUsernameFromSenderPK(UIViewController *controller, id message, NSString *sessionUsername) {
	NSString *senderPk = SCIDirectSenderPKFromMessage(message);
	if (senderPk.length == 0) return nil;

	id envelope = SCIObjectForSelector(message, @"message");
	if (!envelope) envelope = SCIKVCObject(message, @"message");
	NSArray *messageCandidates = envelope && envelope != message ? @[message, envelope] : @[message];

	id directCache = SCIDirectCacheFromController(controller);
	id applicator = SCIDirectCacheUpdatesApplicatorFromController(controller);

	id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
	if (!dataSource) dataSource = SCIKVCObject(controller, @"dataSource");

	for (id root in @[message ?: (id)NSNull.null, dataSource ?: (id)NSNull.null, directCache ?: (id)NSNull.null, applicator ?: (id)NSNull.null, controller ?: (id)NSNull.null]) {
		if (!root || root == (id)NSNull.null) continue;
		NSString *path = nil;
		NSString *u = SCIUsernameForSenderPKInObjectGraph(root, senderPk, sessionUsername, &path);
		if (u.length > 0) {
			SCIDMTrace(@"username from senderPk graph on %@ path=%@: %@", SCIClassName(root), path ?: @"(unknown)", u);
			return u;
		}
	}

	NSNumber *senderPkNumber = nil;
	if (senderPk.length > 0 && [senderPk rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
		senderPkNumber = @([senderPk longLongValue]);
	}
	NSArray *pkCandidates = senderPkNumber ? @[senderPk, senderPkNumber] : @[senderPk];

	for (Class cls in SCIClassesRespondingToClassSelector(@"userFromCurrentSessionDirectCacheWithPK:")) {
		SEL sel = NSSelectorFromString(@"userFromCurrentSessionDirectCacheWithPK:");
		for (id pkValue in pkCandidates) {
			id user = ((id (*)(id, SEL, id))objc_msgSend)(cls, sel, pkValue);
			NSString *u = SCINonSessionUsernameFromUser(user, sessionUsername);
			if (u.length > 0) {
				SCIDMTrace(@"username from %@ userFromCurrentSessionDirectCacheWithPK:(%@): %@", NSStringFromClass(cls), SCIClassName(pkValue), u);
				return u;
			}
		}
	}

	if (directCache) {
		for (Class cls in SCIClassesRespondingToClassSelector(@"userFromPK:inDirectCache:")) {
			SEL sel = NSSelectorFromString(@"userFromPK:inDirectCache:");
			for (id pkValue in pkCandidates) {
				id user = ((id (*)(id, SEL, id, id))objc_msgSend)(cls, sel, pkValue, directCache);
				NSString *u = SCINonSessionUsernameFromUser(user, sessionUsername);
				if (u.length > 0) {
					SCIDMTrace(@"username from %@ userFromPK:inDirectCache:(%@): %@", NSStringFromClass(cls), SCIClassName(pkValue), u);
					return u;
				}
			}
		}
	}

	if (applicator) {
		for (Class cls in SCIClassesRespondingToClassSelector(@"userFromPK:fromDirectCacheUpdatesApplicator:")) {
			SEL sel = NSSelectorFromString(@"userFromPK:fromDirectCacheUpdatesApplicator:");
			for (id pkValue in pkCandidates) {
				id user = ((id (*)(id, SEL, id, id))objc_msgSend)(cls, sel, pkValue, applicator);
				NSString *u = SCINonSessionUsernameFromUser(user, sessionUsername);
				if (u.length > 0) {
					SCIDMTrace(@"username from %@ userFromPK:fromDirectCacheUpdatesApplicator:(%@): %@", NSStringFromClass(cls), SCIClassName(pkValue), u);
					return u;
				}
			}
		}
	}

	if (directCache) {
		for (Class cls in SCIClassesRespondingToClassSelector(@"senderFromMessage:directCache:")) {
			SEL sel = NSSelectorFromString(@"senderFromMessage:directCache:");
			for (id messageCandidate in messageCandidates) {
				id user = ((id (*)(id, SEL, id, id))objc_msgSend)(cls, sel, messageCandidate, directCache);
				NSString *u = SCINonSessionUsernameFromUser(user, sessionUsername);
				if (u.length > 0) {
					SCIDMTrace(@"username from %@ senderFromMessage:directCache: %@", NSStringFromClass(cls), u);
					return u;
				}
			}
		}
	}

	if (applicator) {
		for (Class cls in SCIClassesRespondingToClassSelector(@"senderFromMessage:directCacheUpdatesApplicator:")) {
			SEL sel = NSSelectorFromString(@"senderFromMessage:directCacheUpdatesApplicator:");
			for (id messageCandidate in messageCandidates) {
				id user = ((id (*)(id, SEL, id, id))objc_msgSend)(cls, sel, messageCandidate, applicator);
				NSString *u = SCINonSessionUsernameFromUser(user, sessionUsername);
				if (u.length > 0) {
					SCIDMTrace(@"username from %@ senderFromMessage:directCacheUpdatesApplicator: %@", NSStringFromClass(cls), u);
					return u;
				}
			}
		}
	}

	for (NSString *selectorName in @[@"userFromPK:", @"userFromPk:", @"userForPK:", @"userForPk:", @"userWithPK:", @"userWithPk:", @"userForUserID:", @"userForUserId:", @"userForID:", @"userForId:"]) {
		SEL sel = NSSelectorFromString(selectorName);
		if (directCache && [directCache respondsToSelector:sel]) {
			for (id pkValue in pkCandidates) {
				id user = ((id (*)(id, SEL, id))objc_msgSend)(directCache, sel, pkValue);
				NSString *u = SCINonSessionUsernameFromUser(user, sessionUsername);
				if (u.length > 0) {
					SCIDMTrace(@"username from directCache %@ (%@): %@", selectorName, SCIClassName(pkValue), u);
					return u;
				}
			}
		}
		if (applicator && [applicator respondsToSelector:sel]) {
			for (id pkValue in pkCandidates) {
				id user = ((id (*)(id, SEL, id))objc_msgSend)(applicator, sel, pkValue);
				NSString *u = SCINonSessionUsernameFromUser(user, sessionUsername);
				if (u.length > 0) {
					SCIDMTrace(@"username from directCacheUpdatesApplicator %@ (%@): %@", selectorName, SCIClassName(pkValue), u);
					return u;
				}
			}
		}
	}

	SCIDMTrace(@"senderPk fallback could not resolve a non-session username");
	return nil;
}

NSString *SCIUsernameFromMediaObject(id media) {
	if (!media) return nil;

	NSString *username = SCIShallowUsernameFromObject(media);
	if (username.length > 0) return username;

	for (NSString *nestedSelector in @[
		@"media",
		@"item",
		@"message",
		@"visualMessage",
		@"storyItem",
		@"reelShare",
		@"xmaMediaShareItem",
		@"currentMessage",
		@"parentMessage"
	]) {
		id nested = SCIObjectForSelector(media, nestedSelector);
		if (!nested) nested = SCIKVCObject(media, nestedSelector);
		if (!nested || nested == media) continue;

		username = SCIShallowUsernameFromObject(nested);
		if (username.length > 0) return username;

		NSArray *nestedItems = SCIArrayFromCollection(nested);
		for (id nestedItem in nestedItems) {
			if (!nestedItem || nestedItem == media) continue;
			username = SCIShallowUsernameFromObject(nestedItem);
			if (username.length > 0) return username;
		}
	}

	return nil;
}

id SCIDirectCurrentMessageFromController(UIViewController *controller) {
	if (!controller) return nil;

	id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
	if (!dataSource) dataSource = SCIKVCObject(controller, @"dataSource");

	id message = [SCIUtils getIvarForObj:dataSource name:"_currentMessage"];
	if (!message) message = SCIKVCObject(dataSource, @"currentMessage");

	return message;
}

static NSArray *SCIItemsFromMediaContainer(id media) {
	if (!media) return nil;

	NSArray *items = SCIArrayFromCollection(SCIObjectForSelector(media, @"items"));
	if (items.count == 0) {
		items = SCIArrayFromCollection(SCIKVCObject(media, @"items"));
	}
	return items.count > 0 ? items : nil;
}

id SCIDirectResolvedMediaFromController(UIViewController *controller) {
	id message = SCIDirectCurrentMessageFromController(controller);
	SCIDMTrace(@"resolved currentMessage class=%@", SCIClassName(message));
	if (!message) return nil;

	if (SCIItemsFromMediaContainer(message).count > 0) {
		SCIDMTrace(@"using currentMessage as media container (items=%lu)", (unsigned long)SCIItemsFromMediaContainer(message).count);
		return message;
	}

	for (NSString *nestedKey in @[@"media", @"visualMessage", @"item"]) {
		id nested = SCIObjectForSelector(message, nestedKey);
		if (!nested) nested = SCIKVCObject(message, nestedKey);
		if (!nested || nested == message) continue;

		if (SCIItemsFromMediaContainer(nested).count > 0) {
			SCIDMTrace(@"using nested %@ as media container class=%@ (items=%lu)", nestedKey, SCIClassName(nested), (unsigned long)SCIItemsFromMediaContainer(nested).count);
			return nested;
		}
	}

	SCIDMTrace(@"falling back to currentMessage without items");
	return message;
}

NSInteger SCIDirectCurrentIndexFromController(UIViewController *controller) {
	if (!controller) return 0;

	id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
	if (!dataSource) dataSource = SCIKVCObject(controller, @"dataSource");

	for (NSString *selectorName in @[@"currentItemIndex", @"currentIndex", @"itemIndex"]) {
		NSNumber *n = [SCIUtils numericValueForObj:dataSource selectorName:selectorName];
		if (n && n.integerValue >= 0) {
			SCIDMTrace(@"resolved current index via selector %@ = %ld", selectorName, (long)n.integerValue);
			return n.integerValue;
		}
	}

	for (NSString *key in @[@"currentItemIndex", @"currentIndex", @"itemIndex"]) {
		id v = SCIKVCObject(dataSource, key);
		if ([v respondsToSelector:@selector(integerValue)] && [v integerValue] >= 0) {
			SCIDMTrace(@"resolved current index via KVC %@ = %ld", key, (long)[v integerValue]);
			return [v integerValue];
		}
	}

	for (NSString *key in @[@"_currentItemIndex", @"_currentIndex", @"_itemIndex"]) {
		id v = [SCIUtils getIvarForObj:dataSource name:key.UTF8String];
		if ([v respondsToSelector:@selector(integerValue)] && [v integerValue] >= 0) {
			SCIDMTrace(@"resolved current index via ivar %@ = %ld", key, (long)[v integerValue]);
			return [v integerValue];
		}
	}

	SCIDMTrace(@"could not resolve current index; defaulting to 0");
	return 0;
}

NSString *SCIDirectUsernameFromController(UIViewController *controller) {
	id message = SCIDirectCurrentMessageFromController(controller);
	SCIDMTrace(@"resolving username from currentMessage class=%@", SCIClassName(message));
	NSString *sessionUsername = SCISessionUsernameFromController(controller);
	if (sessionUsername.length > 0) {
		SCIDMTrace(@"current session username=%@", sessionUsername);
	}
	NSString *username = SCIUsernameFromMediaObject(message);
	if (username.length > 0) {
		if (sessionUsername.length > 0 &&
			[username caseInsensitiveCompare:sessionUsername] == NSOrderedSame) {
			SCIDMTrace(@"username on currentMessage matched session user; continuing search");
		} else {
			SCIDMTrace(@"username found on currentMessage: %@", username);
			return username;
		}
	}

	NSArray *items = SCIItemsFromMediaContainer(message);
	SCIDMTrace(@"username fallback scanning items count=%lu", (unsigned long)items.count);
	for (id item in items) {
		SCIDMTrace(@"checking item class=%@", SCIClassName(item));
		username = SCIUsernameFromMediaObject(item);
		if (username.length > 0) {
			if (sessionUsername.length > 0 &&
				[username caseInsensitiveCompare:sessionUsername] == NSOrderedSame) {
				SCIDMTrace(@"username on item matched session user; continuing search");
			} else {
				SCIDMTrace(@"username found on item: %@", username);
				return username;
			}
		}

		for (NSString *nestedKey in @[@"media", @"visualMessage", @"item"]) {
			id nested = SCIObjectForSelector(item, nestedKey);
			if (!nested) nested = SCIKVCObject(item, nestedKey);
			username = SCIUsernameFromMediaObject(nested);
			if (username.length > 0) {
				if (sessionUsername.length > 0 &&
					[username caseInsensitiveCompare:sessionUsername] == NSOrderedSame) {
					SCIDMTrace(@"username on item.%@ matched session user; continuing search", nestedKey);
				} else {
					SCIDMTrace(@"username found on item.%@: %@", nestedKey, username);
					return username;
				}
			}
		}
	}

	id dataSource = [SCIUtils getIvarForObj:controller name:"_dataSource"];
	if (!dataSource) dataSource = SCIKVCObject(controller, @"dataSource");

	for (id root in @[message ?: (id)NSNull.null, dataSource ?: (id)NSNull.null, controller ?: (id)NSNull.null]) {
		if (!root || root == (id)NSNull.null) continue;
		NSString *foundPath = nil;
		NSUInteger depth = (root == controller) ? 4 : 6;
		username = SCIUsernameFromObjectGraph(root, depth, sessionUsername, &foundPath);
		if (username.length > 0) {
			SCIDMTrace(@"username found via graph on %@ path=%@: %@", SCIClassName(root), foundPath ?: @"(unknown)", username);
			return username;
		}
	}

	username = SCIDirectUsernameFromSenderPK(controller, message, sessionUsername);
	if (username.length > 0) {
		return username;
	}

	SCIDMTrace(@"username not found on currentMessage or any items");
	return nil;
}
