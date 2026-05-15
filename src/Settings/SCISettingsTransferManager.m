#import "SCISettingsTransferManager.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "TweakSettings.h"
#import "../Utils.h"
#import "../Shared/UI/SCIIGAlertPresenter.h"
#import "../Shared/Gallery/SCIGalleryCoreDataStack.h"
#import "../Shared/Gallery/SCIGalleryManager.h"
#import "../Shared/Gallery/SCIGalleryPaths.h"

@interface SCISettingsTransferManager () <UIDocumentPickerDelegate>
@property (nonatomic, weak) UIViewController *presentingController;
@property (nonatomic, assign) BOOL pendingImportSettings;
@property (nonatomic, assign) BOOL pendingImportGallery;
@end

static NSString *SCITemporaryTransferRoot(NSString *suffix) {
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"scinsta-transfer-%@-%@", suffix, NSUUID.UUID.UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
    return root;
}

static NSArray<SCISetting *> *SCIFlattenSettingsRowsFromSections(NSArray *sections) {
    NSMutableArray<SCISetting *> *rows = [NSMutableArray array];
    for (NSDictionary *section in sections) {
        NSArray *sectionRows = [section[@"rows"] isKindOfClass:[NSArray class]] ? section[@"rows"] : @[];
        for (SCISetting *row in sectionRows) {
            if (![row isKindOfClass:[SCISetting class]]) continue;
            [rows addObject:row];
            if (row.navSections.count > 0) {
                [rows addObjectsFromArray:SCIFlattenSettingsRowsFromSections(row.navSections)];
            }
        }
    }
    return rows;
}

static NSSet<NSString *> *SCIExportedPreferenceKeys(void) {
    NSMutableSet<NSString *> *keys = [NSMutableSet set];
    for (SCISetting *row in SCIFlattenSettingsRowsFromSections([SCITweakSettings sections])) {
        if (row.defaultsKey.length > 0) [keys addObject:row.defaultsKey];
    }

    [keys addObjectsFromArray:@[
        @"SCInstaFirstRun",
        @"header_long_press_gallery",
        @"instagram.override.project.lucent.navigation",
        @"IGLiquidGlassOverrideEnabled",
        @"liquid_glass_override_enabled",
        @"scinsta_gallery_folders",
        @"scinsta_gallery_sort_mode",
        @"scinsta_gallery_view_mode",
        @"cache_auto_clear_mode",
        @"cache_last_cleared_at"
    ]];

    NSDictionary *allPrefs = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    for (NSString *key in allPrefs) {
        if ([key hasPrefix:@"action_button_"] ||
            [key hasPrefix:@"scinsta_"] ||
            [key hasPrefix:@"liquid_glass_"]) {
            [keys addObject:key];
        }
    }

    return keys;
}

static NSDictionary *SCIPreferencesSnapshot(void) {
    NSDictionary *allPrefs = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    for (NSString *key in SCIExportedPreferenceKeys()) {
        id value = allPrefs[key];
        if (value) snapshot[key] = value;
    }
    return snapshot;
}

static BOOL SCICopyItemReplacingDestination(NSString *sourcePath, NSString *destinationPath, NSError **error) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:destinationPath]) {
        if (![fm removeItemAtPath:destinationPath error:error]) {
            return NO;
        }
    }
    NSString *parent = [destinationPath stringByDeletingLastPathComponent];
    [fm createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:nil];
    return [fm copyItemAtPath:sourcePath toPath:destinationPath error:error];
}

static BOOL SCIIsValidSettingsTransferBundleRoot(NSString *bundleRoot);
static NSString *SCIResolvedSettingsTransferBundleRoot(NSURL *pickedURL);

static void SCIAppendUInt16LE(NSMutableData *data, uint16_t value) {
    uint8_t bytes[2] = { (uint8_t)(value & 0xff), (uint8_t)((value >> 8) & 0xff) };
    [data appendBytes:bytes length:sizeof(bytes)];
}

static void SCIAppendUInt32LE(NSMutableData *data, uint32_t value) {
    uint8_t bytes[4] = {
        (uint8_t)(value & 0xff),
        (uint8_t)((value >> 8) & 0xff),
        (uint8_t)((value >> 16) & 0xff),
        (uint8_t)((value >> 24) & 0xff)
    };
    [data appendBytes:bytes length:sizeof(bytes)];
}

static uint16_t SCIReadUInt16LE(const uint8_t *bytes, NSUInteger offset) {
    return (uint16_t)bytes[offset] | ((uint16_t)bytes[offset + 1] << 8);
}

static uint32_t SCIReadUInt32LE(const uint8_t *bytes, NSUInteger offset) {
    return (uint32_t)bytes[offset] |
           ((uint32_t)bytes[offset + 1] << 8) |
           ((uint32_t)bytes[offset + 2] << 16) |
           ((uint32_t)bytes[offset + 3] << 24);
}

static uint32_t SCIZipCRC32ForBytes(uint32_t crc, const uint8_t *bytes, NSUInteger length) {
    static uint32_t table[256];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        for (uint32_t i = 0; i < 256; i++) {
            uint32_t c = i;
            for (int j = 0; j < 8; j++) {
                c = (c & 1) ? (0xedb88320U ^ (c >> 1)) : (c >> 1);
            }
            table[i] = c;
        }
    });

    crc = crc ^ 0xffffffffU;
    for (NSUInteger i = 0; i < length; i++) {
        crc = table[(crc ^ bytes[i]) & 0xff] ^ (crc >> 8);
    }
    return crc ^ 0xffffffffU;
}

static void SCIZipCurrentDOSTimeDate(uint16_t *timeOut, uint16_t *dateOut) {
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:[NSDate date]];
    NSInteger year = MAX(1980, MIN(2107, components.year));
    if (timeOut) *timeOut = (uint16_t)((components.hour << 11) | (components.minute << 5) | (components.second / 2));
    if (dateOut) *dateOut = (uint16_t)(((year - 1980) << 9) | (components.month << 5) | components.day);
}

@interface SCIZipEntry : NSObject
@property (nonatomic, copy) NSString *relativePath;
@property (nonatomic, copy) NSString *sourcePath;
@property (nonatomic, assign) uint32_t crc32;
@property (nonatomic, assign) uint32_t size;
@property (nonatomic, assign) uint32_t localHeaderOffset;
@property (nonatomic, assign) uint16_t dosTime;
@property (nonatomic, assign) uint16_t dosDate;
@end

@implementation SCIZipEntry
@end

static NSArray<SCIZipEntry *> *SCIZipEntriesForDirectory(NSString *root, NSError **error) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator<NSString *> *enumerator = [fm enumeratorAtPath:root];
    NSMutableArray<SCIZipEntry *> *entries = [NSMutableArray array];

    for (NSString *relativePath in enumerator) {
        NSString *sourcePath = [root stringByAppendingPathComponent:relativePath];
        NSNumber *isDirectory = nil;
        NSURL *sourceURL = [NSURL fileURLWithPath:sourcePath];
        [sourceURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (isDirectory.boolValue) continue;

        NSDictionary *attrs = [fm attributesOfItemAtPath:sourcePath error:error];
        if (!attrs) return nil;
        unsigned long long fileSize = [attrs[NSFileSize] unsignedLongLongValue];
        if (fileSize > UINT32_MAX) {
            if (error) {
                *error = [NSError errorWithDomain:@"SCInstaSettingsTransfer"
                                             code:2001
                                         userInfo:@{NSLocalizedDescriptionKey: @"Export contains a file larger than 4 GB, which is not supported yet."}];
            }
            return nil;
        }

        SCIZipEntry *entry = [SCIZipEntry new];
        entry.relativePath = [relativePath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
        entry.sourcePath = sourcePath;
        entry.size = (uint32_t)fileSize;
        if ([entry.relativePath dataUsingEncoding:NSUTF8StringEncoding].length > UINT16_MAX) {
            if (error) {
                *error = [NSError errorWithDomain:@"SCInstaSettingsTransfer"
                                             code:2003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Export contains a path that is too long for zip."}];
            }
            return nil;
        }
        [entries addObject:entry];
    }

    [entries sortUsingComparator:^NSComparisonResult(SCIZipEntry *a, SCIZipEntry *b) {
        return [a.relativePath compare:b.relativePath];
    }];
    if (entries.count > UINT16_MAX) {
        if (error) {
            *error = [NSError errorWithDomain:@"SCInstaSettingsTransfer"
                                         code:2004
                                     userInfo:@{NSLocalizedDescriptionKey: @"Export contains too many files for this zip writer."}];
        }
        return nil;
    }
    return entries;
}

static BOOL SCIWriteStoredZipFromDirectory(NSString *root, NSString *zipPath, NSError **error) {
    NSArray<SCIZipEntry *> *entries = SCIZipEntriesForDirectory(root, error);
    if (!entries) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *parent = [zipPath stringByDeletingLastPathComponent];
    [fm createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createFileAtPath:zipPath contents:nil attributes:nil];
    NSFileHandle *zip = [NSFileHandle fileHandleForWritingAtPath:zipPath];
    if (!zip) return NO;

    uint16_t dosTime = 0;
    uint16_t dosDate = 0;
    SCIZipCurrentDOSTimeDate(&dosTime, &dosDate);

    for (SCIZipEntry *entry in entries) {
        entry.dosTime = dosTime;
        entry.dosDate = dosDate;
        if ([zip offsetInFile] > UINT32_MAX) {
            if (error) {
                *error = [NSError errorWithDomain:@"SCInstaSettingsTransfer"
                                             code:2005
                                         userInfo:@{NSLocalizedDescriptionKey: @"Export is too large for this zip writer."}];
            }
            [zip closeFile];
            return NO;
        }
        entry.localHeaderOffset = (uint32_t)[zip offsetInFile];
        NSData *nameData = [entry.relativePath dataUsingEncoding:NSUTF8StringEncoding];

        NSMutableData *local = [NSMutableData data];
        SCIAppendUInt32LE(local, 0x04034b50);
        SCIAppendUInt16LE(local, 20);
        SCIAppendUInt16LE(local, 0);
        SCIAppendUInt16LE(local, 0);
        SCIAppendUInt16LE(local, entry.dosTime);
        SCIAppendUInt16LE(local, entry.dosDate);
        SCIAppendUInt32LE(local, 0);
        SCIAppendUInt32LE(local, entry.size);
        SCIAppendUInt32LE(local, entry.size);
        SCIAppendUInt16LE(local, (uint16_t)nameData.length);
        SCIAppendUInt16LE(local, 0);
        [local appendData:nameData];
        [zip writeData:local];

        NSFileHandle *input = [NSFileHandle fileHandleForReadingAtPath:entry.sourcePath];
        if (!input) {
            if (error) {
                *error = [NSError errorWithDomain:@"SCInstaSettingsTransfer"
                                             code:2006
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not read %@.", entry.relativePath]}];
            }
            [zip closeFile];
            return NO;
        }
        uint32_t crc = 0;
        @autoreleasepool {
            while (true) {
                NSData *chunk = [input readDataOfLength:1024 * 1024];
                if (chunk.length == 0) break;
                crc = SCIZipCRC32ForBytes(crc, chunk.bytes, chunk.length);
                [zip writeData:chunk];
            }
        }
        [input closeFile];
        entry.crc32 = crc;

        unsigned long long returnOffset = [zip offsetInFile];
        [zip seekToFileOffset:entry.localHeaderOffset + 14];
        NSMutableData *sizes = [NSMutableData data];
        SCIAppendUInt32LE(sizes, entry.crc32);
        SCIAppendUInt32LE(sizes, entry.size);
        SCIAppendUInt32LE(sizes, entry.size);
        [zip writeData:sizes];
        [zip seekToFileOffset:returnOffset];
    }

    if ([zip offsetInFile] > UINT32_MAX) {
        if (error) {
            *error = [NSError errorWithDomain:@"SCInstaSettingsTransfer"
                                         code:2005
                                     userInfo:@{NSLocalizedDescriptionKey: @"Export is too large for this zip writer."}];
        }
        [zip closeFile];
        return NO;
    }
    uint32_t centralOffset = (uint32_t)[zip offsetInFile];
    NSMutableData *central = [NSMutableData data];
    for (SCIZipEntry *entry in entries) {
        NSData *nameData = [entry.relativePath dataUsingEncoding:NSUTF8StringEncoding];
        SCIAppendUInt32LE(central, 0x02014b50);
        SCIAppendUInt16LE(central, 20);
        SCIAppendUInt16LE(central, 20);
        SCIAppendUInt16LE(central, 0);
        SCIAppendUInt16LE(central, 0);
        SCIAppendUInt16LE(central, entry.dosTime);
        SCIAppendUInt16LE(central, entry.dosDate);
        SCIAppendUInt32LE(central, entry.crc32);
        SCIAppendUInt32LE(central, entry.size);
        SCIAppendUInt32LE(central, entry.size);
        SCIAppendUInt16LE(central, (uint16_t)nameData.length);
        SCIAppendUInt16LE(central, 0);
        SCIAppendUInt16LE(central, 0);
        SCIAppendUInt16LE(central, 0);
        SCIAppendUInt16LE(central, 0);
        SCIAppendUInt32LE(central, 0);
        SCIAppendUInt32LE(central, entry.localHeaderOffset);
        [central appendData:nameData];
    }
    [zip writeData:central];

    uint32_t centralSize = (uint32_t)central.length;
    NSMutableData *eocd = [NSMutableData data];
    SCIAppendUInt32LE(eocd, 0x06054b50);
    SCIAppendUInt16LE(eocd, 0);
    SCIAppendUInt16LE(eocd, 0);
    SCIAppendUInt16LE(eocd, (uint16_t)entries.count);
    SCIAppendUInt16LE(eocd, (uint16_t)entries.count);
    SCIAppendUInt32LE(eocd, centralSize);
    SCIAppendUInt32LE(eocd, centralOffset);
    SCIAppendUInt16LE(eocd, 0);
    [zip writeData:eocd];
    [zip closeFile];
    return YES;
}

static BOOL SCIIsSafeZipEntryName(NSString *name) {
    if (name.length == 0 || [name hasPrefix:@"/"] || [name containsString:@"\\"]) return NO;
    for (NSString *part in [name componentsSeparatedByString:@"/"]) {
        if ([part isEqualToString:@".."]) return NO;
    }
    return YES;
}

static NSString *SCIExpandStoredZipSettingsTransferArchive(NSURL *archiveURL, NSError **error) {
    NSData *zipData = [NSData dataWithContentsOfURL:archiveURL options:NSDataReadingMappedIfSafe error:error];
    if (zipData.length < 22) return nil;

    const uint8_t *bytes = zipData.bytes;
    NSInteger eocdOffset = -1;
    for (NSInteger i = (NSInteger)zipData.length - 22; i >= 0 && i >= (NSInteger)zipData.length - 65557; i--) {
        if (SCIReadUInt32LE(bytes, (NSUInteger)i) == 0x06054b50) {
            eocdOffset = i;
            break;
        }
    }
    if (eocdOffset < 0) return nil;

    uint16_t entryCount = SCIReadUInt16LE(bytes, (NSUInteger)eocdOffset + 10);
    uint32_t centralSize = SCIReadUInt32LE(bytes, (NSUInteger)eocdOffset + 12);
    uint32_t centralOffset = SCIReadUInt32LE(bytes, (NSUInteger)eocdOffset + 16);
    if ((NSUInteger)centralOffset + centralSize > zipData.length) return nil;

    NSString *tempRoot = SCITemporaryTransferRoot(@"import");
    NSString *expandedRoot = [tempRoot stringByAppendingPathComponent:@"Expanded"];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:expandedRoot withIntermediateDirectories:YES attributes:nil error:nil];

    NSFileHandle *archiveHandle = [NSFileHandle fileHandleForReadingFromURL:archiveURL error:error];
    if (!archiveHandle) return nil;

    NSUInteger cursor = centralOffset;
    for (uint16_t i = 0; i < entryCount; i++) {
        if (cursor + 46 > zipData.length || SCIReadUInt32LE(bytes, cursor) != 0x02014b50) {
            [archiveHandle closeFile];
            return nil;
        }

        uint16_t method = SCIReadUInt16LE(bytes, cursor + 10);
        uint32_t compressedSize = SCIReadUInt32LE(bytes, cursor + 20);
        uint32_t uncompressedSize = SCIReadUInt32LE(bytes, cursor + 24);
        uint16_t nameLen = SCIReadUInt16LE(bytes, cursor + 28);
        uint16_t extraLen = SCIReadUInt16LE(bytes, cursor + 30);
        uint16_t commentLen = SCIReadUInt16LE(bytes, cursor + 32);
        uint32_t localOffset = SCIReadUInt32LE(bytes, cursor + 42);
        if (cursor + 46 + nameLen + extraLen + commentLen > zipData.length) {
            [archiveHandle closeFile];
            return nil;
        }

        NSData *nameData = [zipData subdataWithRange:NSMakeRange(cursor + 46, nameLen)];
        NSString *entryName = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
        cursor += 46 + nameLen + extraLen + commentLen;
        if (!SCIIsSafeZipEntryName(entryName)) {
            [archiveHandle closeFile];
            return nil;
        }
        if ([entryName hasSuffix:@"/"]) {
            [fm createDirectoryAtPath:[expandedRoot stringByAppendingPathComponent:entryName] withIntermediateDirectories:YES attributes:nil error:nil];
            continue;
        }
        if (method != 0 || compressedSize != uncompressedSize) {
            if (error) {
                *error = [NSError errorWithDomain:@"SCInstaSettingsTransfer"
                                             code:2002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Compressed zip entries are not supported by this build."}];
            }
            [archiveHandle closeFile];
            return nil;
        }
        if ((NSUInteger)localOffset + 30 > zipData.length || SCIReadUInt32LE(bytes, localOffset) != 0x04034b50) {
            [archiveHandle closeFile];
            return nil;
        }
        uint16_t localNameLen = SCIReadUInt16LE(bytes, localOffset + 26);
        uint16_t localExtraLen = SCIReadUInt16LE(bytes, localOffset + 28);
        unsigned long long dataOffset = (unsigned long long)localOffset + 30ULL + localNameLen + localExtraLen;
        if (dataOffset + compressedSize > zipData.length) {
            [archiveHandle closeFile];
            return nil;
        }

        NSString *destPath = [expandedRoot stringByAppendingPathComponent:entryName];
        [fm createDirectoryAtPath:[destPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [fm createFileAtPath:destPath contents:nil attributes:nil];
        NSFileHandle *output = [NSFileHandle fileHandleForWritingAtPath:destPath];
        [archiveHandle seekToFileOffset:dataOffset];
        uint32_t remaining = compressedSize;
        while (remaining > 0) {
            NSUInteger chunkSize = MIN((NSUInteger)remaining, (NSUInteger)(1024 * 1024));
            NSData *chunk = [archiveHandle readDataOfLength:chunkSize];
            if (chunk.length == 0) break;
            [output writeData:chunk];
            remaining -= (uint32_t)chunk.length;
        }
        [output closeFile];
        if (remaining > 0) {
            [archiveHandle closeFile];
            return nil;
        }
    }

    [archiveHandle closeFile];
    return SCIIsValidSettingsTransferBundleRoot(expandedRoot) ? expandedRoot : SCIResolvedSettingsTransferBundleRoot([NSURL fileURLWithPath:expandedRoot isDirectory:YES]);
}

static UTType *SCISettingsTransferArchiveType(void) {
    UTType *type = [UTType typeWithFilenameExtension:@"scinstaexport" conformingToType:UTTypeData];
    if (type) return type;
    return nil;
}

static BOOL SCIIsValidSettingsTransferBundleRoot(NSString *bundleRoot) {
    if (bundleRoot.length == 0) return NO;
    NSString *prefsPath = [bundleRoot stringByAppendingPathComponent:@"Preferences/settings.plist"];
    NSString *galleryPath = [bundleRoot stringByAppendingPathComponent:@"Gallery"];
    return [[NSFileManager defaultManager] fileExistsAtPath:prefsPath] ||
           [[NSFileManager defaultManager] fileExistsAtPath:galleryPath];
}

static NSString *SCIResolvedSettingsTransferBundleRoot(NSURL *pickedURL) {
    if (!pickedURL.path.length) return nil;

    NSString *candidate = pickedURL.path;
    for (NSInteger i = 0; i < 5 && candidate.length > 1; i++) {
        if (SCIIsValidSettingsTransferBundleRoot(candidate)) {
            return candidate;
        }
        candidate = [candidate stringByDeletingLastPathComponent];
    }
    return nil;
}

static NSString *SCIExpandSerializedSettingsTransferArchive(NSURL *archiveURL, NSError **error) {
    NSData *archiveData = [NSData dataWithContentsOfURL:archiveURL options:NSDataReadingMappedIfSafe error:error];
    if (archiveData.length == 0) return nil;

    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithSerializedRepresentation:archiveData];
    if (!wrapper.isDirectory) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:@"SCInstaSettingsTransfer"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Archive contents were invalid."}];
        }
        return nil;
    }

    NSString *tempRoot = SCITemporaryTransferRoot(@"import");
    NSString *expandedRoot = [tempRoot stringByAppendingPathComponent:@"Expanded"];
    NSURL *expandedURL = [NSURL fileURLWithPath:expandedRoot isDirectory:YES];
    if (![wrapper writeToURL:expandedURL options:NSFileWrapperWritingAtomic originalContentsURL:nil error:error]) {
        return nil;
    }

    return SCIIsValidSettingsTransferBundleRoot(expandedRoot) ? expandedRoot : SCIResolvedSettingsTransferBundleRoot(expandedURL);
}

static NSString *SCIResolvedImportBundleRootForPickedURL(NSURL *pickedURL, NSError **error) {
    NSString *bundleRoot = SCIResolvedSettingsTransferBundleRoot(pickedURL);
    if (bundleRoot.length > 0) return bundleRoot;

    NSNumber *isDirectory = nil;
    [pickedURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
    if (isDirectory.boolValue) return nil;

    NSString *zipBundleRoot = SCIExpandStoredZipSettingsTransferArchive(pickedURL, error);
    if (zipBundleRoot.length > 0) return zipBundleRoot;

    return SCIExpandSerializedSettingsTransferArchive(pickedURL, error);
}

static NSDictionary *SCITransferManifest(BOOL includeSettings, BOOL includeGallery) {
    return @{
        @"format_version": @2,
        @"created_at": [NSDate date],
        @"includes_settings": @(includeSettings),
        @"includes_gallery": @(includeGallery),
        @"included_keys": includeSettings ? [[SCIExportedPreferenceKeys() allObjects] sortedArrayUsingSelector:@selector(compare:)] : @[]
    };
}

@implementation SCISettingsTransferManager

+ (instancetype)sharedManager {
    static SCISettingsTransferManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SCISettingsTransferManager alloc] init];
    });
    return manager;
}

- (void)exportSettingsAndGalleryFromController:(UIViewController *)controller {
    [self exportFromController:controller includeSettings:YES includeGallery:YES];
}

- (void)importSettingsAndGalleryFromController:(UIViewController *)controller {
    [self importFromController:controller includeSettings:YES includeGallery:YES];
}

- (void)presentExportOptionsFromController:(UIViewController *)controller {
    __weak typeof(self) weakSelf = self;
    [SCIIGAlertPresenter presentActionSheetFromViewController:controller
                                                        title:@"Export Backup"
                                                      message:@"Choose what to include in the export."
                                                      actions:@[
        [SCIIGAlertAction actionWithTitle:@"Export Settings Only" style:SCIIGAlertActionStyleDefault handler:^{
        [weakSelf exportFromController:controller includeSettings:YES includeGallery:NO];
    }],
        [SCIIGAlertAction actionWithTitle:@"Export Gallery Only" style:SCIIGAlertActionStyleDefault handler:^{
        [weakSelf exportFromController:controller includeSettings:NO includeGallery:YES];
    }],
        [SCIIGAlertAction actionWithTitle:@"Export Settings + Gallery" style:SCIIGAlertActionStyleDefault handler:^{
        [weakSelf exportFromController:controller includeSettings:YES includeGallery:YES];
    }],
        [SCIIGAlertAction actionWithTitle:@"Cancel" style:SCIIGAlertActionStyleCancel handler:nil],
    ]];
}

- (void)presentImportOptionsFromController:(UIViewController *)controller {
    __weak typeof(self) weakSelf = self;
    [SCIIGAlertPresenter presentActionSheetFromViewController:controller
                                                        title:@"Import Backup"
                                                      message:@"Choose what to restore from the backup."
                                                      actions:@[
        [SCIIGAlertAction actionWithTitle:@"Import Settings Only" style:SCIIGAlertActionStyleDefault handler:^{
        [weakSelf importFromController:controller includeSettings:YES includeGallery:NO];
    }],
        [SCIIGAlertAction actionWithTitle:@"Import Gallery Only" style:SCIIGAlertActionStyleDefault handler:^{
        [weakSelf importFromController:controller includeSettings:NO includeGallery:YES];
    }],
        [SCIIGAlertAction actionWithTitle:@"Import Settings + Gallery" style:SCIIGAlertActionStyleDefault handler:^{
        [weakSelf importFromController:controller includeSettings:YES includeGallery:YES];
    }],
        [SCIIGAlertAction actionWithTitle:@"Cancel" style:SCIIGAlertActionStyleCancel handler:nil],
    ]];
}

- (void)exportFromController:(UIViewController *)controller includeSettings:(BOOL)includeSettings includeGallery:(BOOL)includeGallery {
    if (!includeSettings && !includeGallery) return;
    self.presentingController = controller;

    NSString *root = SCITemporaryTransferRoot(@"export");
    NSString *bundleRoot = [root stringByAppendingPathComponent:@"SCInstaExportBundle"];
    NSString *prefsPath = [bundleRoot stringByAppendingPathComponent:@"Preferences/settings.plist"];
    NSString *galleryDestination = [bundleRoot stringByAppendingPathComponent:@"Gallery"];
    NSString *manifestPath = [bundleRoot stringByAppendingPathComponent:@"manifest.plist"];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:bundleRoot withIntermediateDirectories:YES attributes:nil error:nil];

    if (includeSettings) {
        [fm createDirectoryAtPath:[prefsPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        NSDictionary *prefs = SCIPreferencesSnapshot();
        [prefs writeToFile:prefsPath atomically:YES];
    }

    if (includeGallery) {
        NSError *copyError = nil;
        if (![fm copyItemAtPath:[SCIGalleryPaths galleryDirectory] toPath:galleryDestination error:&copyError]) {
            SCINotify(kSCINotificationSettingsExport, @"Export failed", copyError.localizedDescription, @"error_filled", SCINotificationToneForIconResource(@"error_filled"));
            return;
        }
    }

    [SCITransferManifest(includeSettings, includeGallery) writeToFile:manifestPath atomically:YES];

    NSError *archiveError = nil;
    NSString *archivePath = [root stringByAppendingPathComponent:@"SCInsta.zip"];
    if (!SCIWriteStoredZipFromDirectory(bundleRoot, archivePath, &archiveError)) {
        NSString *message = archiveError.localizedDescription ?: @"The export zip could not be created.";
        SCINotify(kSCINotificationSettingsExport, @"Export failed", message, @"error_filled", SCINotificationToneForIconResource(@"error_filled"));
        return;
    }

    NSURL *archiveURL = [NSURL fileURLWithPath:archivePath isDirectory:NO];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[archiveURL] asCopy:YES];
    SCINotify(kSCINotificationSettingsExport, @"Opened export sheet", nil, @"arrow_up", SCINotificationToneForIconResource(@"arrow_up"));
    [controller presentViewController:picker animated:YES completion:nil];
}

- (void)importFromController:(UIViewController *)controller includeSettings:(BOOL)includeSettings includeGallery:(BOOL)includeGallery {
    if (!includeSettings && !includeGallery) return;
    self.presentingController = controller;
    self.pendingImportSettings = includeSettings;
    self.pendingImportGallery = includeGallery;
    UIDocumentPickerViewController *picker = nil;
    UTType *archiveType = SCISettingsTransferArchiveType();
    NSMutableArray<UTType *> *contentTypes = [NSMutableArray array];
    if (archiveType) [contentTypes addObject:archiveType];
    [contentTypes addObject:UTTypeZIP];
    [contentTypes addObject:UTTypeFolder];
    [contentTypes addObject:UTTypeData];
    picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes asCopy:YES];
    picker.delegate = self;
    SCINotify(kSCINotificationSettingsImport, @"Choose an export bundle", nil, @"arrow_down", SCINotificationToneForIconResource(@"arrow_down"));
    [controller presentViewController:picker animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.pendingImportSettings = NO;
    self.pendingImportGallery = NO;
    self.presentingController = nil;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    self.presentingController = nil;
    if (!url) return;

    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSError *archiveError = nil;
    NSString *bundleRoot = SCIResolvedImportBundleRootForPickedURL(url, &archiveError);
    NSString *prefsPath = [bundleRoot stringByAppendingPathComponent:@"Preferences/settings.plist"];
    NSString *galleryPath = [bundleRoot stringByAppendingPathComponent:@"Gallery"];
    NSString *manifestPath = [bundleRoot stringByAppendingPathComponent:@"manifest.plist"];
    NSDictionary *manifest = bundleRoot.length > 0 ? [NSDictionary dictionaryWithContentsOfFile:manifestPath] : nil;
    NSDictionary *prefs = [[NSFileManager defaultManager] fileExistsAtPath:prefsPath] ? [NSDictionary dictionaryWithContentsOfFile:prefsPath] : nil;
    BOOL archiveHasSettings = [prefs isKindOfClass:[NSDictionary class]];
    BOOL archiveHasGallery = [[NSFileManager defaultManager] fileExistsAtPath:galleryPath];
    BOOL importSettings = self.pendingImportSettings;
    BOOL importGallery = self.pendingImportGallery;
    self.pendingImportSettings = NO;
    self.pendingImportGallery = NO;

    if (manifest && [manifest isKindOfClass:[NSDictionary class]]) {
        NSNumber *manifestSettings = manifest[@"includes_settings"];
        NSNumber *manifestGallery = manifest[@"includes_gallery"];
        if ([manifestSettings respondsToSelector:@selector(boolValue)]) archiveHasSettings = manifestSettings.boolValue && archiveHasSettings;
        if ([manifestGallery respondsToSelector:@selector(boolValue)]) archiveHasGallery = manifestGallery.boolValue && archiveHasGallery;
    }

    if ((importSettings && !archiveHasSettings) || (importGallery && !archiveHasGallery) || (!archiveHasSettings && !archiveHasGallery)) {
        if (scoped) [url stopAccessingSecurityScopedResource];
        NSString *message = archiveError.localizedDescription ?: @"Archive contents were invalid.";
        SCINotify(kSCINotificationSettingsImport, @"Import failed", message, @"error_filled", SCINotificationToneForIconResource(@"error_filled"));
        return;
    }

    if (importSettings) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        for (NSString *key in SCIExportedPreferenceKeys()) {
            [defaults removeObjectForKey:key];
        }
        [prefs enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            [defaults setObject:value forKey:key];
        }];
    }

    if (importGallery) {
        [[SCIGalleryCoreDataStack shared] unloadPersistentStores];
        NSError *galleryCopyError = nil;
        if (!SCICopyItemReplacingDestination(galleryPath, [SCIGalleryPaths galleryDirectory], &galleryCopyError)) {
            if (scoped) [url stopAccessingSecurityScopedResource];
            SCINotify(kSCINotificationSettingsImport, @"Import failed", galleryCopyError.localizedDescription, @"error_filled", SCINotificationToneForIconResource(@"error_filled"));
            [[SCIGalleryCoreDataStack shared] reloadPersistentContainer];
            return;
        }
        [[SCIGalleryManager sharedManager] removePasscode];
        [[SCIGalleryCoreDataStack shared] reloadPersistentContainer];
    }

    if (scoped) [url stopAccessingSecurityScopedResource];

    NSString *subtitle = importSettings && importGallery
        ? @"Settings and Gallery media were restored. Reconfigure Gallery lock if needed."
        : (importSettings ? @"Settings were restored." : @"Gallery media were restored. Reconfigure Gallery lock if needed.");
    SCINotify(kSCINotificationSettingsImport, @"Import complete", subtitle, @"circle_check_filled", SCINotificationToneForIconResource(@"circle_check_filled"));
    [SCIUtils showRestartConfirmation];
}

- (void)resetAllSettingsFromController:(UIViewController *)controller {
    [SCIIGAlertPresenter presentAlertFromViewController:controller
                                                  title:@"Reset all settings?"
                                                message:@"This restores every SCInsta preference to its default value. Gallery media is left untouched. This cannot be undone."
                                                actions:@[
        [SCIIGAlertAction actionWithTitle:@"Cancel" style:SCIIGAlertActionStyleCancel handler:nil],
        [SCIIGAlertAction actionWithTitle:@"Reset" style:SCIIGAlertActionStyleDestructive handler:^{
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            for (NSString *key in SCIExportedPreferenceKeys()) {
                [defaults removeObjectForKey:key];
            }
            SCINotify(kSCINotificationSettingsImport,
                      @"Settings reset",
                      @"All SCInsta preferences were restored to defaults.",
                      @"circle_check_filled",
                      SCINotificationToneForIconResource(@"circle_check_filled"));
            [SCIUtils showRestartConfirmation];
        }],
    ]];
}

@end
