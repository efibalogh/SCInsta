#import "AssetUtils.h"

#import <math.h>

typedef NSDictionary<NSString *, id> SCIAssetDescriptor;

static NSString * const kSCIAssetFallbackSystemName = @"questionmark.square.dashed";

static UIImage *SCIAssetScaleImage(UIImage *image, CGFloat maxPointSize) {
    if (!image || maxPointSize <= 0) {
        return image;
    }

    CGFloat maxDimension = MAX(image.size.width, image.size.height);
    if (maxDimension <= maxPointSize + 0.01) {
        return image;
    }

    CGFloat ratio = maxPointSize / maxDimension;
    CGSize newSize = CGSizeMake(round(image.size.width * ratio), round(image.size.height * ratio));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = image.scale;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:newSize format:format];
    UIImage *scaled = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        (void)context;
        [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    }];

    if (image.renderingMode != UIImageRenderingModeAutomatic) {
        scaled = [scaled imageWithRenderingMode:image.renderingMode];
    }

    return scaled;
}

static UIImage *SCIAssetRotateImage(UIImage *image, CGFloat radians) {
    if (!image) {
        return nil;
    }

    CGRect rect = CGRectApplyAffineTransform((CGRect){.origin = CGPointZero, .size = image.size}, CGAffineTransformMakeRotation(radians));
    CGSize rotatedSize = CGSizeMake(fabs(rect.size.width), fabs(rect.size.height));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = image.scale;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:rotatedSize format:format];
    UIImage *rotated = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        CGContextRef cgContext = context.CGContext;
        CGContextTranslateCTM(cgContext, rotatedSize.width / 2.0, rotatedSize.height / 2.0);
        CGContextRotateCTM(cgContext, radians);
        [image drawInRect:CGRectMake(-image.size.width / 2.0, -image.size.height / 2.0, image.size.width, image.size.height)];
    }];

    if (image.renderingMode != UIImageRenderingModeAutomatic) {
        rotated = [rotated imageWithRenderingMode:image.renderingMode];
    }
    return rotated;
}

static NSArray<NSNumber *> *SCIAssetCandidateSizes(CGFloat pointSize) {
    NSInteger rounded = (NSInteger)lround(MAX(pointSize, 0.0));
    NSMutableOrderedSet<NSNumber *> *sizes = [NSMutableOrderedSet orderedSet];
    if (rounded > 0) {
        [sizes addObject:@(rounded)];
    }
    for (NSNumber *value in @[@24, @22, @20, @18, @16, @14, @12, @10, @32]) {
        [sizes addObject:value];
    }
    return sizes.array;
}

static NSString *SCIAssetNormalizeInternalName(NSString *name) {
    NSString *normalized = [[name ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    while ([normalized containsString:@"__"]) {
        normalized = [normalized stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return normalized;
}

static NSBundle *SCIAssetFrameworkBundle(void) {
    static NSBundle *bundle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks/FBSharedFramework.framework"];
        bundle = [NSBundle bundleWithPath:path];
    });
    return bundle;
}

static NSBundle *SCIAssetBundleForSource(SCIAssetCatalogSource source) {
    switch (source) {
        case SCIAssetCatalogSourceFBSharedFramework:
            return SCIAssetFrameworkBundle();
        case SCIAssetCatalogSourceMainApp:
            return [NSBundle mainBundle];
        case SCIAssetCatalogSourceAutomatic:
        default:
            return nil;
    }
}

static NSArray<NSNumber *> *SCIAssetSearchOrderForSource(SCIAssetCatalogSource requestedSource, SCIAssetCatalogSource defaultSource) {
    NSMutableOrderedSet<NSNumber *> *sources = [NSMutableOrderedSet orderedSet];
    if (requestedSource != SCIAssetCatalogSourceAutomatic) {
        [sources addObject:@(requestedSource)];
    } else {
        [sources addObject:@(defaultSource)];
    }
    [sources addObject:@(SCIAssetCatalogSourceFBSharedFramework)];
    [sources addObject:@(SCIAssetCatalogSourceMainApp)];
    return sources.array;
}

static NSDictionary<NSString *, SCIAssetDescriptor *> *SCIAssetOverrides(void) {
    static NSDictionary<NSString *, SCIAssetDescriptor *> *overrides;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        overrides = @{
            @"app": @{@"candidates": @[@"ig_icon_app_instagram_pano_outline_24", @"ig_icon_app_instagram_outline_24"]},
            @"action": @{@"candidates": @[@"ig_icon_flash_outline_24", @"ig_icon_flash_outline_20"]},
            @"action_reels": @{@"candidates": @[@"ig_icon_flash_outline_44"]},
            @"audio": @{@"candidates": @[@"ig_icon_audio_wave_outline_24"]},
            @"arrow_up": @{@"candidates": @[@"ig_icon_arrow_up_outline_24"]},
            @"arrow_down": @{@"candidates": @[@"ig_icon_arrow_down_outline_24"]},
            @"arrow_left": @{@"candidates": @[@"ig_icon_arrow_left_outline_24"]},
            @"arrow_right": @{@"candidates": @[@"ig_icon_arrow_right_outline_24"]},
            @"arrow_cw": @{@"candidates": @[@"ig_icon_arrow_cw_outline_24"]},
            @"arrow_ccw": @{@"candidates": @[@"ig_icon_arrow_ccw_outline_24"]},
            @"backspace": @{@"candidates": @[@"ig_icon_backspace_outline_24"]},
            @"calendar": @{@"candidates": @[@"ig_icon_calendar_outline_24"]},
            @"caption": @{@"candidates": @[@"ig_icon_community_notes_outline_24"]},
            @"check": @{@"candidates": @[@"ig_icon_check_outline_24"]},
            @"chest": @{@"candidates": @[@"ig_icon_chest_outline_24"]},
            @"circle": @{@"candidates": @[@"ig_icon_circle_outline_24"]},
            @"circle_check": @{@"candidates": @[@"ig_icon_circle_check_outline_24"]},
            @"circle_check_filled": @{@"candidates": @[@"ig_icon_circle_check_pano_filled_24", @"ig_icon_circle_check_filled_24"]},
            @"copy": @{@"candidates": @[@"ig_icon_copy_outline_24"]},
            @"copy_filled": @{@"candidates": @[@"ig_icon_copy_filled_24"]},
            @"download": @{@"candidates": @[@"ig_icon_download_outline_24"]},
            @"download_reels": @{@"candidates": @[@"ig_icon_download_outline_44"]},
            @"edit": @{@"candidates": @[@"ig_icon_edit_outline_24"]},
            @"error": @{@"candidates": @[@"ig_icon_error_outline_24"]},
            @"error_filled": @{@"candidates": @[@"ig_icon_error_filled_24"]},
            @"expand": @{@"candidates": @[@"ig_icon_fit_outline_24"]},
            @"expand_reels": @{@"candidates": @[@"ig_icon_fit_outline_44"]},
            @"external_link": @{@"candidates": @[@"ig_icon_external_link_outline_24"]},
            @"eye": @{@"candidates": @[@"ig_icon_eye_outline_24"]},
            @"feed": @{@"candidates": @[@"ig_icon_carousel_prism_outline_24", @"ig_icon_photo_list_outline_24"]},
            @"filter": @{@"candidates": @[@"ig_icon_align_center_outline_24", @"ig_icon_sliders_pano_outline_24", @"ig_icon_sliders_outline_24"]},
            @"folder": @{@"candidates": @[@"ig_icon_folder_prism_outline_24", @"ig_icon_folder_outline_24"]},
            @"folder_move": @{@"candidates": @[@"ig_icon_folder_arrow_right_prism_outline_24", @"ig_icon_folder_arrow_right_outline_24"]},
            @"grid": @{@"candidates": @[@"ig_icon_collections_outline_24"]},
            @"heart": @{@"candidates": @[@"ig_icon_heart_pano_outline_24", @"ig_icon_heart_outline_24"]},
            @"heart_filled": @{@"candidates": @[@"ig_icon_heart_filled_24"]},
            @"info": @{@"candidates": @[@"ig_icon_info_pano_outline_24", @"ig_icon_info_outline_24"]},
            @"info_filled": @{@"candidates": @[@"ig_icon_info_filled_16"]},
            @"interface": @{@"candidates": @[@"ig_icon_device_phone_prism_outline_24", @"ig_icon_device_phone_pano_outline_24", @"ig_icon_device_phone_outline_24"]},
            @"key": @{@"candidates": @[@"ig_icon_key_outline_24"]},
            @"link": @{@"candidates": @[@"ig_icon_link_outline_24"]},
            @"link_reels": @{@"candidates": @[@"ig_icon_link_outline_44"]},
            @"list": @{@"candidates": @[@"ig_icon_edit_list_outline_24"]},
            @"lock": @{@"candidates": @[@"ig_icon_lock_prism_filled_24", @"ig_icon_lock_filled_24"]},
            @"media": @{@"candidates": @[@"ig_icon_collage_prism_outline_24", @"ig_icon_collage_outline_24", @"ig_icon_media_outline_24"]},
            @"media_filled": @{@"candidates": @[@"ig_icon_media_filled_24", @"ig_icon_photo_filled_24"]},
            @"media_empty": @{@"candidates": @[@"ig_icon_media_outline_96"]},
            @"mention": @{@"candidates": @[@"ig_icon_story_mention_pano_outline_24"]},
            @"messages": @{@"candidates": @[@"ig_icon_direct_prism_outline_24"]},
            @"more": @{@"candidates": @[@"ig_icon_more_horizontal_outline_24"]},
            @"notification": @{@"candidates": @[@"ig_icon_alert_pano_outline_24", @"ig_icon_alert_outline_24"]},
            @"photo": @{@"candidates": @[@"ig_icon_photo_outline_24"]},
            @"photo_filled": @{@"candidates": @[@"ig_icon_photo_filled_24"]},
            @"photo_reels": @{@"candidates": @[@"ig_icon_photo_outline_44"]},
            @"photo_gallery": @{@"candidates": @[@"ig_icon_photo_gallery_outline_24"]},
            @"plus": @{@"candidates": @[@"ig_icon_add_pano_outline_24", @"ig_icon_add_outline_24"]},
            @"profile": @{@"candidates": @[@"ig_icon_user_prism_outline_24", @"ig_icon_user_outline_24"]},
            @"reels": @{@"candidates": @[@"ig_icon_reels_prism_outline_24", @"ig_icon_reels_pano_prism_outline_24", @"ig_icon_reels_outline_24", @"ig_icon_reels_pano_outline_24"]},
            @"reels_gallery": @{@"candidates": @[@"ig_icon_reels_gallery_outline_24"]},
            @"repost": @{@"candidates": @[@"ig_icon_reshare_outline_24"]},
            @"search": @{@"candidates": @[@"ig_icon_search_pano_outline_24", @"ig_icon_search_outline_24"]},
            @"settings": @{@"candidates": @[@"ig_icon_settings_pano_outline_24", @"ig_icon_settings_outline_24"]},
            @"share": @{@"candidates": @[@"ig_icon_share_pano_outline_24"]},
            @"share_reels": @{@"candidates": @[@"ig_icon_share_outline_44"]},
            @"size_large": @{@"candidates": @[@"ig_icon_fit_outline_24"]},
            @"size_small": @{@"candidates": @[@"ig_icon_fill_outline_24"]},
            @"sort": @{@"candidates": @[@"ig_icon_sort_pano_outline_24"]},
            @"story": @{@"candidates": @[@"ig_icon_story_outline_24"]},
            @"text": @{@"candidates": @[@"ig_icon_text_outline_24"]},
            @"toolbox": @{@"candidates": @[@"ig_icon_toolbox_outline_24"]},
            @"trash": @{@"candidates": @[@"ig_icon_delete_outline_24"]},
            @"trash_filled": @{@"candidates": @[@"ig_icon_delete_filled_24"]},
            @"unlock": @{@"candidates": @[@"ig_icon_unlock_prism_filled_24", @"ig_icon_unlock_filled_24"]},
            @"username": @{@"candidates": @[@"ig_icon_user_nickname_prism_outline_24"]},
            @"users": @{@"candidates": @[@"ig_icon_users_prism_outline_24"]},
            @"video": @{@"candidates": @[@"ig_icon_video_chat_pano_outline_24", @"ig_icon_video_chat_outline_24"]},
            @"video_filled": @{@"candidates": @[@"ig_icon_video_chat_pano_filled_24"]},
            @"warning": @{@"candidates": @[@"ig_icon_warning_pano_outline_24", @"ig_icon_warning_outline_24"]},
            @"warning_filled": @{@"candidates": @[@"ig_icon_warning_pano_filled_24", @"ig_icon_warning_filled_24"]},
            @"xmark": @{@"candidates": @[@"ig_icon_x_pano_outline_24"]}
        };
    });
    return overrides;
}

static CGFloat SCIAssetResolvedPointSize(NSString *name, CGFloat pointSize) {
    if (pointSize <= 0) {
        return pointSize;
    }

    SCIAssetDescriptor *descriptor = SCIAssetOverrides()[SCIAssetNormalizeInternalName(name)];
    NSDictionary *sizeMap = descriptor[@"size_map"];
    if (![sizeMap isKindOfClass:[NSDictionary class]]) {
        return pointSize;
    }

    NSNumber *mapped = sizeMap[[NSString stringWithFormat:@"%ld", (long)lround(pointSize)]];
    if ([mapped isKindOfClass:[NSNumber class]] && mapped.doubleValue > 0) {
        return mapped.doubleValue;
    }

    return pointSize;
}

static NSArray<NSString *> *SCIAssetHeuristicCandidates(NSString *name, CGFloat pointSize) {
    NSString *normalized = SCIAssetNormalizeInternalName(name);
    if (normalized.length == 0) {
        return @[];
    }

    if ([normalized hasPrefix:@"ig_icon_"]) {
        return @[normalized];
    }

    NSString *baseName = normalized;
    NSString *variant = nil;
    if ([baseName hasSuffix:@"_filled"]) {
        baseName = [baseName substringToIndex:baseName.length - @"_filled".length];
        variant = @"filled";
    } else if ([baseName hasSuffix:@"_outline"]) {
        baseName = [baseName substringToIndex:baseName.length - @"_outline".length];
        variant = @"outline";
    }

    NSMutableOrderedSet<NSString *> *candidates = [NSMutableOrderedSet orderedSet];
    [candidates addObject:normalized];
    [candidates addObject:[NSString stringWithFormat:@"ig_icon_%@", normalized]];

    for (NSNumber *sizeValue in SCIAssetCandidateSizes(pointSize)) {
        NSInteger size = sizeValue.integerValue;
        if (variant.length > 0) {
            [candidates addObject:[NSString stringWithFormat:@"ig_icon_%@_%@_%ld", baseName, variant, (long)size]];
            [candidates addObject:[NSString stringWithFormat:@"ig_icon_%@_%ld", baseName, (long)size]];
        } else {
            [candidates addObject:[NSString stringWithFormat:@"ig_icon_%@_%ld", baseName, (long)size]];
            [candidates addObject:[NSString stringWithFormat:@"ig_icon_%@_outline_%ld", baseName, (long)size]];
            [candidates addObject:[NSString stringWithFormat:@"ig_icon_%@_filled_%ld", baseName, (long)size]];
        }
    }

    return candidates.array;
}

static NSArray<NSString *> *SCIAssetCandidatesForInternalName(NSString *name, CGFloat pointSize) {
    NSString *normalized = SCIAssetNormalizeInternalName(name);
    SCIAssetDescriptor *descriptor = SCIAssetOverrides()[normalized];
    NSMutableOrderedSet<NSString *> *candidates = [NSMutableOrderedSet orderedSet];

    NSArray<NSString *> *explicitCandidates = descriptor[@"candidates"];
    if ([explicitCandidates isKindOfClass:[NSArray class]]) {
        [candidates addObjectsFromArray:explicitCandidates];
    }
    [candidates addObjectsFromArray:SCIAssetHeuristicCandidates(normalized, pointSize)];
    return candidates.array;
}

static SCIAssetCatalogSource SCIAssetDefaultSourceForInternalName(NSString *name) {
    SCIAssetDescriptor *descriptor = SCIAssetOverrides()[SCIAssetNormalizeInternalName(name)];
    NSNumber *sourceValue = descriptor[@"source"];
    if ([sourceValue isKindOfClass:[NSNumber class]]) {
        return (SCIAssetCatalogSource)sourceValue.integerValue;
    }
    return SCIAssetCatalogSourceFBSharedFramework;
}

static UIImage *SCIAssetApplyRenderingMode(UIImage *image, UIImageRenderingMode renderingMode) {
    if (!image || renderingMode == UIImageRenderingModeAutomatic) {
        return image;
    }
    return [image imageWithRenderingMode:renderingMode];
}

static UIImage *SCIAssetFallbackImage(CGFloat pointSize, UIImageRenderingMode renderingMode) {
    UIImageConfiguration *configuration = nil;
    if (pointSize > 0) {
        configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize];
    }

    UIImage *image = configuration
        ? [UIImage systemImageNamed:kSCIAssetFallbackSystemName withConfiguration:configuration]
        : [UIImage systemImageNamed:kSCIAssetFallbackSystemName];
    return SCIAssetApplyRenderingMode(image, renderingMode);
}

static UIImage *SCIAssetSystemSymbolImage(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight, UIImageRenderingMode renderingMode) {
    if (name.length == 0) {
        return nil;
    }

    UIImageConfiguration *configuration = nil;
    if (pointSize > 0) {
        configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
    } else if (weight != UIImageSymbolWeightUnspecified) {
        configuration = [UIImageSymbolConfiguration configurationWithWeight:weight];
    }

    UIImage *image = configuration
        ? [UIImage systemImageNamed:name withConfiguration:configuration]
        : [UIImage systemImageNamed:name];
    return SCIAssetApplyRenderingMode(image, renderingMode);
}

static BOOL SCIAssetHasExplicitOverride(NSString *name) {
    return SCIAssetOverrides()[SCIAssetNormalizeInternalName(name)] != nil;
}

static UIImage *SCIAssetLookupInstagramIcon(NSString *name, CGFloat pointSize, SCIAssetCatalogSource source, UIImageRenderingMode renderingMode) {
    NSString *normalizedName = SCIAssetNormalizeInternalName(name);
    if (normalizedName.length == 0) {
        return nil;
    }

    CGFloat resolvedPointSize = SCIAssetResolvedPointSize(normalizedName, pointSize);
    SCIAssetCatalogSource defaultSource = SCIAssetDefaultSourceForInternalName(normalizedName);
    NSArray<NSNumber *> *sourceOrder = SCIAssetSearchOrderForSource(source, defaultSource);
    NSArray<NSString *> *candidates = SCIAssetCandidatesForInternalName(normalizedName, resolvedPointSize);

    for (NSNumber *sourceValue in sourceOrder) {
        NSBundle *bundle = SCIAssetBundleForSource((SCIAssetCatalogSource)sourceValue.integerValue);
        if (!bundle) {
            continue;
        }

        for (NSString *candidate in candidates) {
            UIImage *image = [UIImage imageNamed:candidate inBundle:bundle compatibleWithTraitCollection:nil];
            if (!image) {
                continue;
            }

            image = SCIAssetScaleImage(image, resolvedPointSize);
            return SCIAssetApplyRenderingMode(image, renderingMode);
        }
    }

    return nil;
}

@implementation SCIAssetUtils

+ (UIImage *)instagramIconNamed:(NSString *)name {
    return [self instagramIconNamed:name
                          pointSize:0
                             source:SCIAssetCatalogSourceAutomatic
                      renderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize {
    return [self instagramIconNamed:name
                          pointSize:pointSize
                             source:SCIAssetCatalogSourceAutomatic
                      renderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize renderingMode:(UIImageRenderingMode)renderingMode {
    return [self instagramIconNamed:name
                          pointSize:pointSize
                             source:SCIAssetCatalogSourceAutomatic
                      renderingMode:renderingMode];
}

+ (UIImage *)instagramIconNamed:(NSString *)name pointSize:(CGFloat)pointSize source:(SCIAssetCatalogSource)source {
    return [self instagramIconNamed:name
                          pointSize:pointSize
                             source:source
                      renderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIImage *)instagramIconNamed:(NSString *)name
                      pointSize:(CGFloat)pointSize
                         source:(SCIAssetCatalogSource)source
                  renderingMode:(UIImageRenderingMode)renderingMode {
    UIImage *image = SCIAssetLookupInstagramIcon(name, pointSize, source, renderingMode);
    if (image) {
        return image;
    }
    return SCIAssetFallbackImage(pointSize, renderingMode);
}

+ (UIImage *)resolvedImageNamed:(NSString *)name
                      pointSize:(CGFloat)pointSize
                         weight:(UIImageSymbolWeight)weight
                         source:(SCIResolvedImageSource)source
                  renderingMode:(UIImageRenderingMode)renderingMode {
    return [self resolvedImageNamed:name
                 fallbackSystemName:nil
                          pointSize:pointSize
                             weight:weight
                             source:source
                      renderingMode:renderingMode];
}

+ (UIImage *)resolvedImageNamed:(NSString *)name
             fallbackSystemName:(NSString *)fallbackSystemName
                      pointSize:(CGFloat)pointSize
                         weight:(UIImageSymbolWeight)weight
                         source:(SCIResolvedImageSource)source
                  renderingMode:(UIImageRenderingMode)renderingMode {
    if (name.length == 0 && fallbackSystemName.length == 0) {
        return nil;
    }

    UIImage *image = nil;

    switch (source) {
        case SCIResolvedImageSourceInstagramIcon:
            image = SCIAssetLookupInstagramIcon(name, pointSize, SCIAssetCatalogSourceAutomatic, renderingMode);
            if (!image && fallbackSystemName.length > 0) {
                image = SCIAssetSystemSymbolImage(fallbackSystemName, pointSize, weight, renderingMode);
            }
            break;
        case SCIResolvedImageSourceSystemSymbol:
            image = SCIAssetSystemSymbolImage(name, pointSize, weight, renderingMode);
            if (!image && fallbackSystemName.length > 0) {
                image = SCIAssetSystemSymbolImage(fallbackSystemName, pointSize, weight, renderingMode);
            }
            break;
        case SCIResolvedImageSourceAutomatic:
        default: {
            BOOL shouldTryInstagramFirst = [name hasPrefix:@"ig_icon_"] || SCIAssetHasExplicitOverride(name);
            if (shouldTryInstagramFirst) {
                image = SCIAssetLookupInstagramIcon(name, pointSize, SCIAssetCatalogSourceAutomatic, renderingMode);
            }
            if (!image) {
                image = SCIAssetSystemSymbolImage(name, pointSize, weight, renderingMode);
            }
            if (!image && !shouldTryInstagramFirst) {
                image = SCIAssetLookupInstagramIcon(name, pointSize, SCIAssetCatalogSourceAutomatic, renderingMode);
            }
            if (!image && fallbackSystemName.length > 0) {
                image = SCIAssetSystemSymbolImage(fallbackSystemName, pointSize, weight, renderingMode);
            }
            break;
        }
    }

    if (image) {
        return image;
    }
    if (fallbackSystemName.length > 0) {
        return SCIAssetFallbackImage(pointSize, renderingMode);
    }
    return nil;
}

@end
