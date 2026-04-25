#import "SCIVaultPaths.h"

static NSString *_vaultDirectory;
static NSString *_vaultMediaDirectory;
static NSString *_vaultThumbnailsDirectory;

@implementation SCIVaultPaths

+ (NSString *)vaultDirectory {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        _vaultDirectory = [docs stringByAppendingPathComponent:@"Vault"];
        [self ensureDirectoryExists:_vaultDirectory];
    });
    return _vaultDirectory;
}

+ (NSString *)vaultMediaDirectory {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _vaultMediaDirectory = [[self vaultDirectory] stringByAppendingPathComponent:@"Files"];
        [self ensureDirectoryExists:_vaultMediaDirectory];
    });
    return _vaultMediaDirectory;
}

+ (NSString *)vaultThumbnailsDirectory {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _vaultThumbnailsDirectory = [[self vaultDirectory] stringByAppendingPathComponent:@"Thumbnails"];
        [self ensureDirectoryExists:_vaultThumbnailsDirectory];
    });
    return _vaultThumbnailsDirectory;
}

+ (void)ensureDirectoryExists:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        NSError *error;
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"[SCInsta Vault] Failed to create directory %@: %@", path, error);
        }
    }
}

@end
