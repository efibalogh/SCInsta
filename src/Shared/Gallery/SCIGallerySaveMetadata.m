#import "SCIGallerySaveMetadata.h"
#import "SCIGalleryFile.h"

@implementation SCIGallerySaveMetadata

- (instancetype)init {
    if ((self = [super init])) {
        _source = (int16_t)SCIGallerySourceFeed;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    SCIGallerySaveMetadata *c = [[SCIGallerySaveMetadata allocWithZone:zone] init];
    c.sourceUsername = [self.sourceUsername copy];
    c.sourceUserPK = [self.sourceUserPK copy];
    c.sourceProfileURLString = [self.sourceProfileURLString copy];
    c.sourceMediaPK = [self.sourceMediaPK copy];
    c.sourceMediaCode = [self.sourceMediaCode copy];
    c.sourceMediaURLString = [self.sourceMediaURLString copy];
    c.source = self.source;
    c.pixelWidth = self.pixelWidth;
    c.pixelHeight = self.pixelHeight;
    c.durationSeconds = self.durationSeconds;
    c.importFileNameStem = [self.importFileNameStem copy];
    c.customName = [self.customName copy];
    c.importCapturedDate = self.importCapturedDate;
    return c;
}

@end
