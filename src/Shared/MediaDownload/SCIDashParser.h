#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIDashRepresentation : NSObject
@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, copy, nullable) NSString *contentType;
@property (nonatomic, copy, nullable) NSString *qualityLabel;
@property (nonatomic, copy, nullable) NSString *codecs;
@property (nonatomic) NSInteger bandwidth;
@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;
@property (nonatomic) double frameRate;
@end

@interface SCIDashParser : NSObject

+ (nullable NSString *)dashManifestForMedia:(id)media;
+ (NSArray<SCIDashRepresentation *> *)parseManifest:(NSString *)xmlString;

@end

NS_ASSUME_NONNULL_END
