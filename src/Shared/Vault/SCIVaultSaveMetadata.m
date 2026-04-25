#import "SCIVaultSaveMetadata.h"
#import "SCIVaultFile.h"

@implementation SCIVaultSaveMetadata

- (instancetype)init {
    if ((self = [super init])) {
        _source = (int16_t)SCIVaultSourceFeed;
    }
    return self;
}

@end
