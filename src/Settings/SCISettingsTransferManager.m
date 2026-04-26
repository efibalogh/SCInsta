#import "SCISettingsTransferManager.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "TweakSettings.h"
#import "../Utils.h"
#import "../Shared/Vault/SCIVaultCoreDataStack.h"
#import "../Shared/Vault/SCIVaultManager.h"
#import "../Shared/Vault/SCIVaultPaths.h"

@interface SCISettingsTransferManager () <UIDocumentPickerDelegate>
@property (nonatomic, weak) UIViewController *presentingController;
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
        @"header_long_press_vault",
        @"instagram.override.project.lucent.navigation",
        @"IGLiquidGlassOverrideEnabled",
        @"liquid_glass_override_enabled",
        @"scinsta_vault_folders",
        @"scinsta_vault_sort_mode",
        @"scinsta_vault_view_mode",
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
    if (@available(iOS 14.0, *)) {
        UTType *type = [UTType typeWithFilenameExtension:@"scinstaexport" conformingToType:UTTypeData];
        if (type) return type;
    }
    return nil;
}

static BOOL SCIIsValidSettingsTransferBundleRoot(NSString *bundleRoot) {
    if (bundleRoot.length == 0) return NO;
    NSString *prefsPath = [bundleRoot stringByAppendingPathComponent:@"Preferences/settings.plist"];
    NSString *vaultPath = [bundleRoot stringByAppendingPathComponent:@"Vault"];
    return [[NSFileManager defaultManager] fileExistsAtPath:prefsPath] &&
           [[NSFileManager defaultManager] fileExistsAtPath:vaultPath];
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

- (void)exportSettingsAndVaultFromController:(UIViewController *)controller {
    self.presentingController = controller;

    NSString *root = SCITemporaryTransferRoot(@"export");
    NSString *bundleRoot = [root stringByAppendingPathComponent:@"SCInstaExportBundle"];
    NSString *prefsPath = [bundleRoot stringByAppendingPathComponent:@"Preferences/settings.plist"];
    NSString *vaultDestination = [bundleRoot stringByAppendingPathComponent:@"Vault"];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[prefsPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];

    NSDictionary *prefs = SCIPreferencesSnapshot();
    NSDictionary *manifest = @{
        @"format_version": @1,
        @"created_at": [NSDate date],
        @"included_keys": [[SCIExportedPreferenceKeys() allObjects] sortedArrayUsingSelector:@selector(compare:)]
    };
    [prefs writeToFile:prefsPath atomically:YES];
    [manifest writeToFile:[bundleRoot stringByAppendingPathComponent:@"manifest.plist"] atomically:YES];

    NSError *copyError = nil;
    if (![fm copyItemAtPath:[SCIVaultPaths vaultDirectory] toPath:vaultDestination error:&copyError]) {
        [SCIUtils showToastForDuration:3.0 title:@"Export failed" subtitle:copyError.localizedDescription iconResource:@"error_filled" fallbackSystemImageName:@"exclamationmark.circle.fill" tone:SCIFeedbackPillToneError];
        return;
    }

    NSError *wrapperError = nil;
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:bundleRoot isDirectory:YES]
                                                        options:NSFileWrapperReadingImmediate
                                                          error:&wrapperError];
    NSData *archiveData = wrapper.serializedRepresentation;
    if (archiveData.length == 0) {
        NSString *message = wrapperError.localizedDescription ?: @"The export archive could not be created.";
        [SCIUtils showToastForDuration:3.0 title:@"Export failed" subtitle:message iconResource:@"error_filled" fallbackSystemImageName:@"exclamationmark.circle.fill" tone:SCIFeedbackPillToneError];
        return;
    }

    NSString *archivePath = [root stringByAppendingPathComponent:@"SCInsta.scinstaexport"];
    if (![archiveData writeToFile:archivePath options:NSDataWritingAtomic error:&wrapperError]) {
        NSString *message = wrapperError.localizedDescription ?: @"The export archive could not be written.";
        [SCIUtils showToastForDuration:3.0 title:@"Export failed" subtitle:message iconResource:@"error_filled" fallbackSystemImageName:@"exclamationmark.circle.fill" tone:SCIFeedbackPillToneError];
        return;
    }

    NSURL *archiveURL = [NSURL fileURLWithPath:archivePath isDirectory:NO];
    if (@available(iOS 14.0, *)) {
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[archiveURL] asCopy:YES];
        [controller presentViewController:picker animated:YES completion:nil];
    } else {
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[archiveURL] applicationActivities:nil];
        if (activityController.popoverPresentationController) {
            activityController.popoverPresentationController.sourceView = controller.view;
            activityController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(controller.view.bounds), CGRectGetMidY(controller.view.bounds), 1.0, 1.0);
        }
        [controller presentViewController:activityController animated:YES completion:nil];
    }
}

- (void)importSettingsAndVaultFromController:(UIViewController *)controller {
    self.presentingController = controller;
    UIDocumentPickerViewController *picker = nil;
    if (@available(iOS 14.0, *)) {
        UTType *archiveType = SCISettingsTransferArchiveType();
        NSMutableArray<UTType *> *contentTypes = [NSMutableArray array];
        if (archiveType) [contentTypes addObject:archiveType];
        [contentTypes addObject:UTTypeFolder];
        [contentTypes addObject:UTTypeData];
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes asCopy:YES];
    } else {
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data", @"public.folder"] inMode:UIDocumentPickerModeImport];
    }
    picker.delegate = self;
    [controller presentViewController:picker animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
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
    NSString *vaultPath = [bundleRoot stringByAppendingPathComponent:@"Vault"];

    NSDictionary *prefs = bundleRoot.length > 0 ? [NSDictionary dictionaryWithContentsOfFile:prefsPath] : nil;
    if (![prefs isKindOfClass:[NSDictionary class]] || ![[NSFileManager defaultManager] fileExistsAtPath:vaultPath]) {
        if (scoped) [url stopAccessingSecurityScopedResource];
        NSString *message = archiveError.localizedDescription ?: @"Archive contents were invalid.";
        [SCIUtils showToastForDuration:3.0 title:@"Import failed" subtitle:message iconResource:@"error_filled" fallbackSystemImageName:@"exclamationmark.circle.fill" tone:SCIFeedbackPillToneError];
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in SCIExportedPreferenceKeys()) {
        [defaults removeObjectForKey:key];
    }
    [prefs enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        [defaults setObject:value forKey:key];
    }];

    [[SCIVaultCoreDataStack shared] unloadPersistentStores];
    NSError *vaultCopyError = nil;
    if (!SCICopyItemReplacingDestination(vaultPath, [SCIVaultPaths vaultDirectory], &vaultCopyError)) {
        if (scoped) [url stopAccessingSecurityScopedResource];
        [SCIUtils showToastForDuration:3.0 title:@"Import failed" subtitle:vaultCopyError.localizedDescription iconResource:@"error_filled" fallbackSystemImageName:@"exclamationmark.circle.fill" tone:SCIFeedbackPillToneError];
        [[SCIVaultCoreDataStack shared] reloadPersistentContainer];
        return;
    }

    [[SCIVaultManager sharedManager] removePasscode];
    [[SCIVaultCoreDataStack shared] reloadPersistentContainer];
    if (scoped) [url stopAccessingSecurityScopedResource];

    [SCIUtils showToastForDuration:3.0 title:@"Import complete" subtitle:@"Settings and vault media were restored. Reconfigure vault lock if needed." iconResource:@"info" fallbackSystemImageName:@"checkmark.circle.fill" tone:SCIFeedbackPillToneSuccess];
}

@end
