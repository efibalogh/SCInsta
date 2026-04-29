#import "SCISettingsTransferManager.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "TweakSettings.h"
#import "../Utils.h"
#import "../Shared/Gallery/SCIGalleryCoreDataStack.h"
#import "../Shared/Gallery/SCIGalleryManager.h"
#import "../Shared/Gallery/SCIGalleryPaths.h"

@interface SCISettingsTransferManager () <UIDocumentPickerDelegate>
@property (nonatomic, weak) UIViewController *presentingController;
@property (nonatomic, assign) BOOL pendingImportSettings;
@property (nonatomic, assign) BOOL pendingImportGallery;
@end

@implementation SCISettingsTransferManager

+ (instancetype)sharedManager {
    static SCISettingsTransferManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SCISettingsTransferManager alloc] init];
    });
    return manager;
}

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

- (void)exportSettingsAndGalleryFromController:(UIViewController *)controller {
    [self exportFromController:controller includeSettings:YES includeGallery:YES];
}

- (void)importSettingsAndGalleryFromController:(UIViewController *)controller {
    [self importFromController:controller includeSettings:YES includeGallery:YES];
}

- (void)presentExportOptionsFromController:(UIViewController *)controller {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Export Backup"
                                                                   message:@"Choose what to include in the export."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"Export Settings Only" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf exportFromController:controller includeSettings:YES includeGallery:NO];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Export Gallery Only" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf exportFromController:controller includeSettings:NO includeGallery:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Export Settings + Gallery" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf exportFromController:controller includeSettings:YES includeGallery:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = controller.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(controller.view.bounds), CGRectGetMidY(controller.view.bounds), 1.0, 1.0);
    }
    [controller presentViewController:sheet animated:YES completion:nil];
}

- (void)presentImportOptionsFromController:(UIViewController *)controller {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Import Backup"
                                                                   message:@"Choose what to restore from the backup."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"Import Settings Only" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf importFromController:controller includeSettings:YES includeGallery:NO];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Import Gallery Only" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf importFromController:controller includeSettings:NO includeGallery:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Import Settings + Gallery" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf importFromController:controller includeSettings:YES includeGallery:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = controller.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(controller.view.bounds), CGRectGetMidY(controller.view.bounds), 1.0, 1.0);
    }
    [controller presentViewController:sheet animated:YES completion:nil];
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
            [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionSettingsExport duration:3.0 title:@"Export failed" subtitle:copyError.localizedDescription iconResource:@"error_filled"];
            return;
        }
    }

    [SCITransferManifest(includeSettings, includeGallery) writeToFile:manifestPath atomically:YES];

    NSError *wrapperError = nil;
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:bundleRoot isDirectory:YES]
                                                        options:NSFileWrapperReadingImmediate
                                                          error:&wrapperError];
    NSData *archiveData = wrapper.serializedRepresentation;
    if (archiveData.length == 0) {
        NSString *message = wrapperError.localizedDescription ?: @"The export archive could not be created.";
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionSettingsExport duration:3.0 title:@"Export failed" subtitle:message iconResource:@"error_filled"];
        return;
    }

    NSString *archivePath = [root stringByAppendingPathComponent:@"SCInsta.scinstaexport"];
    if (![archiveData writeToFile:archivePath options:NSDataWritingAtomic error:&wrapperError]) {
        NSString *message = wrapperError.localizedDescription ?: @"The export archive could not be written.";
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionSettingsExport duration:3.0 title:@"Export failed" subtitle:message iconResource:@"error_filled"];
        return;
    }

    NSURL *archiveURL = [NSURL fileURLWithPath:archivePath isDirectory:NO];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[archiveURL] asCopy:YES];
    [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionSettingsExport duration:1.4 title:@"Opened export sheet" subtitle:nil iconResource:@"arrow_up"];
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
    [contentTypes addObject:UTTypeFolder];
    [contentTypes addObject:UTTypeData];
    picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes asCopy:YES];
    picker.delegate = self;
    [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionSettingsImport duration:1.4 title:@"Choose an export bundle" subtitle:nil iconResource:@"arrow_down"];
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
        [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionSettingsImport duration:3.0 title:@"Import failed" subtitle:message iconResource:@"error_filled"];
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
            [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionSettingsImport duration:3.0 title:@"Import failed" subtitle:galleryCopyError.localizedDescription iconResource:@"error_filled"];
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
    [SCIUtils showToastForActionIdentifier:kSCIFeedbackActionSettingsImport duration:3.0 title:@"Import complete" subtitle:subtitle iconResource:@"circle_check_filled"];
    [SCIUtils showRestartConfirmation];
}

@end
