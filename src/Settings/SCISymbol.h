#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCISymbol : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) UIColor *color;
@property (nonatomic, readonly) CGFloat size;
@property (nonatomic, readonly) UIImageSymbolWeight weight;

- (UIImage *)image;

+ (instancetype)symbolWithName:(NSString *)name;
+ (instancetype)symbolWithName:(NSString *)name color:(UIColor *)color;
+ (instancetype)symbolWithName:(NSString *)name color:(UIColor *)color size:(CGFloat)size;
+ (instancetype)symbolWithName:(NSString *)name color:(UIColor *)color size:(CGFloat)size weight:(UIImageSymbolWeight)weight;

/// Bundle PNG (same lookup as `SCIUtils sci_resourceImageNamed`) scaled to `size` in points; tinted via settings cell `imageProperties`.
+ (instancetype)resourceSymbolWithName:(NSString *)resourceName color:(nullable UIColor *)color size:(CGFloat)size;

@end

NS_ASSUME_NONNULL_END
