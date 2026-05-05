#import "SCIGalleryImportViewController.h"

#import "SCIGalleryImportMetadataFormViewController.h"
#import "SCIGalleryFile.h"
#import "SCIGallerySaveMetadata.h"
#import "../UI/SCIMediaChrome.h"
#import "../../Utils.h"
#import <CoreServices/CoreServices.h>

typedef NS_ENUM(NSInteger, SCIGalleryImportMainSection) {
    SCIGalleryImportMainSectionShared = 0,
    SCIGalleryImportMainSectionQueue,
};

@interface SCIGalleryImportQueuedFile : NSObject
@property (nonatomic, copy) NSString *fileLabel;
@property (nonatomic, strong) NSURL *tempFileURL;
@property (nonatomic, strong) SCIGallerySaveMetadata *metadata;
@end

@implementation SCIGalleryImportQueuedFile
@end

@interface SCIGalleryImportViewController () <UIDocumentPickerDelegate>
@property (nonatomic, copy, nullable) NSString *destinationFolderPath;
@property (nonatomic, strong) NSMutableArray<SCIGalleryImportQueuedFile *> *queuedFiles;
@property (nonatomic, strong) SCIGallerySaveMetadata *sharedDefaults;
@property (nonatomic, strong) UIBarButtonItem *importBarButtonItem;
@end

@implementation SCIGalleryImportViewController

- (instancetype)initWithDestinationFolderPath:(NSString *)folderPath {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _destinationFolderPath = [folderPath copy];
        _queuedFiles = [NSMutableArray array];
        _sharedDefaults = [[SCIGallerySaveMetadata alloc] init];
        _sharedDefaults.source = (int16_t)SCIGallerySourceOther;
    }
    return self;
}

- (void)dealloc {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (SCIGalleryImportQueuedFile *item in self.queuedFiles) {
        [fm removeItemAtURL:item.tempFileURL error:nil];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Import from Files";
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
    self.importBarButtonItem = SCIMediaChromeTopBarButtonItem(@"arrow_down", self, @selector(importAll));
    self.importBarButtonItem.enabled = NO;
    self.importBarButtonItem.accessibilityLabel = @"Import queue";
    UIBarButtonItem *addItem = SCIMediaChromeTopBarButtonItem(@"plus", self, @selector(addFiles));
    addItem.accessibilityLabel = @"Add files";
    self.navigationItem.rightBarButtonItems = @[ self.importBarButtonItem, addItem ];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == SCIGalleryImportMainSectionShared) {
        return 2;
    }
    return MAX((NSInteger)self.queuedFiles.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == SCIGalleryImportMainSectionShared) {
        return @"Shared fields";
    }
    return @"Queue";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == SCIGalleryImportMainSectionShared) {
        return @"Shared values apply to each new file you add. Use “Merge…” to copy them into files already in the queue (file name key and display name on each file are left as-is).";
    }
    if (section == SCIGalleryImportMainSectionQueue && self.queuedFiles.count == 0) {
        return @"Tap Add to choose images or videos from Files. Then tap a row to enter post/profile metadata so Open original / Open profile work like saves from Instagram.";
    }
    return nil;
}

- (UITableViewCell *)sharedCell:(UITableView *)tableView row:(NSInteger)row {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"shared"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"shared"];
    }
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.textLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.detailTextLabel.text = nil;
    if (row == 0) {
        cell.textLabel.text = @"Edit shared metadata";
    } else {
        cell.textLabel.text = @"Merge shared fields into all queued files";
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = self.queuedFiles.count ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = self.queuedFiles.count
            ? [SCIUtils SCIColor_InstagramPrimaryText]
            : [SCIUtils SCIColor_InstagramSecondaryText];
    }
    return cell;
}

- (NSString *)subtitleForQueuedItem:(SCIGalleryImportQueuedFile *)item {
    SCIGallerySaveMetadata *m = item.metadata;
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (m.sourceUsername.length > 0) {
        [parts addObject:[NSString stringWithFormat:@"@%@", m.sourceUsername]];
    }
    [parts addObject:[SCIGalleryFile labelForSource:(SCIGallerySource)m.source]];
    if (m.sourceMediaCode.length > 0) {
        [parts addObject:m.sourceMediaCode];
    }
    return parts.count ? [parts componentsJoinedByString:@" · "] : @"Edit metadata…";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SCIGalleryImportMainSectionShared) {
        return [self sharedCell:tableView row:indexPath.row];
    }

    if (self.queuedFiles.count == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"empty"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"empty"];
        }
        cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
        cell.textLabel.text = @"No files yet";
        cell.textLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
        cell.detailTextLabel.text = @"Use Add to pick from Files";
        cell.detailTextLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"q"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"q"];
    }
    SCIGalleryImportQueuedFile *item = self.queuedFiles[(NSUInteger)indexPath.row];
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.textLabel.text = item.fileLabel;
    cell.textLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    cell.detailTextLabel.text = [self subtitleForQueuedItem:item];
    cell.detailTextLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != SCIGalleryImportMainSectionQueue || self.queuedFiles.count == 0) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) {
        return;
    }
    SCIGalleryImportQueuedFile *item = self.queuedFiles[(NSUInteger)indexPath.row];
    [[NSFileManager defaultManager] removeItemAtURL:item.tempFileURL error:nil];
    [self.queuedFiles removeObjectAtIndex:(NSUInteger)indexPath.row];
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [self updateImportEnabled];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SCIGalleryImportMainSectionShared) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if (indexPath.row == 0) {
            [self pushEditorForMetadata:self.sharedDefaults title:@"Shared metadata"];
            return;
        }
        if (self.queuedFiles.count == 0) {
            return;
        }
        [self mergeSharedIntoAllQueued];
        UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [h impactOccurred];
        return;
    }

    if (self.queuedFiles.count == 0) {
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SCIGalleryImportQueuedFile *item = self.queuedFiles[(NSUInteger)indexPath.row];
    [self pushEditorForMetadata:item.metadata title:item.fileLabel];
}

- (void)pushEditorForMetadata:(SCIGallerySaveMetadata *)metadata title:(NSString *)title {
    SCIGalleryImportMetadataFormViewController *form = [[SCIGalleryImportMetadataFormViewController alloc] init];
    form.metadata = metadata;
    form.title = title;
    [self.navigationController pushViewController:form animated:YES];
}

- (void)mergeSharedIntoAllQueued {
    SCIGallerySaveMetadata *src = self.sharedDefaults;
    for (SCIGalleryImportQueuedFile *item in self.queuedFiles) {
        SCIGallerySaveMetadata *d = item.metadata;
        d.source = src.source;
        if (src.sourceUsername.length > 0) {
            d.sourceUsername = [src.sourceUsername copy];
        }
        if (src.sourceUserPK.length > 0) {
            d.sourceUserPK = [src.sourceUserPK copy];
        }
        if (src.sourceProfileURLString.length > 0) {
            d.sourceProfileURLString = [src.sourceProfileURLString copy];
        }
        if (src.sourceMediaPK.length > 0) {
            d.sourceMediaPK = [src.sourceMediaPK copy];
        }
        if (src.sourceMediaCode.length > 0) {
            d.sourceMediaCode = [src.sourceMediaCode copy];
        }
        if (src.sourceMediaURLString.length > 0) {
            d.sourceMediaURLString = [src.sourceMediaURLString copy];
        }
        if (src.pixelWidth > 0) {
            d.pixelWidth = src.pixelWidth;
        }
        if (src.pixelHeight > 0) {
            d.pixelHeight = src.pixelHeight;
        }
        if (src.durationSeconds > 0.05) {
            d.durationSeconds = src.durationSeconds;
        }
        if (src.importCapturedDate) {
            d.importCapturedDate = src.importCapturedDate;
        }
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:SCIGalleryImportMainSectionQueue] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Document picker

- (void)addFiles {
    NSArray<NSString *> *utiStrings = @[
        (__bridge NSString *)kUTTypeImage,
        (__bridge NSString *)kUTTypeMovie,
        (__bridge NSString *)kUTTypeVideo,
        (__bridge NSString *)kUTTypeMPEG4,
        (__bridge NSString *)kUTTypeQuickTimeMovie,
        (__bridge NSString *)kUTTypeGIF,
        @"org.webmproject.webp",
    ];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:utiStrings inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    for (NSURL *url in urls) {
        [self enqueueCopiedFileFromURL:url];
    }
    [self.tableView reloadData];
    [self updateImportEnabled];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    (void)controller;
}

- (void)enqueueCopiedFileFromURL:(NSURL *)srcURL {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL scoped = [srcURL startAccessingSecurityScopedResource];
    NSString *tmpName = [NSString stringWithFormat:@"scinsta-gallery-import-%@.%@", [NSUUID UUID].UUIDString, srcURL.pathExtension];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpName];
    [fm removeItemAtPath:tempPath error:nil];
    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
    NSError *err = nil;
    if (![fm copyItemAtURL:srcURL toURL:tempURL error:&err]) {
        if (scoped) {
            [srcURL stopAccessingSecurityScopedResource];
        }
        NSString *reason = err.localizedDescription ?: @"Copy failed";
        [SCIUtils showToastForDuration:2.8
                                 title:@"Couldn’t add file"
                              subtitle:reason
                          iconResource:@"error_filled"];
        return;
    }
    if (scoped) {
        [srcURL stopAccessingSecurityScopedResource];
    }

    SCIGalleryImportQueuedFile *item = [SCIGalleryImportQueuedFile new];
    item.tempFileURL = tempURL;
    item.fileLabel = srcURL.lastPathComponent ?: @"file";
    item.metadata = [self.sharedDefaults copy];
    SCIGalleryApplyImportHeuristicsFromFilename(item.fileLabel, item.metadata);
    [self.queuedFiles addObject:item];
}

#pragma mark - Import

- (void)updateImportEnabled {
    self.importBarButtonItem.enabled = self.queuedFiles.count > 0;
}

- (void)importAll {
    if (self.queuedFiles.count == 0) {
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSUInteger failures = 0;
    NSString *lastErr = nil;
    NSMutableArray<SCIGalleryImportQueuedFile *> *succeeded = [NSMutableArray array];

    for (SCIGalleryImportQueuedFile *item in self.queuedFiles) {
        SCIGalleryMediaType mediaType = [SCIGalleryFile inferMediaTypeFromFileURL:item.tempFileURL];
        NSError *err = nil;
        SCIGalleryFile *saved = [SCIGalleryFile saveFileToGallery:item.tempFileURL
                                                            source:SCIGallerySourceOther
                                                         mediaType:mediaType
                                                        folderPath:self.destinationFolderPath
                                                          metadata:item.metadata
                                                             error:&err];
        if (saved) {
            [fm removeItemAtURL:item.tempFileURL error:nil];
            item.tempFileURL = nil;
            [succeeded addObject:item];
        } else {
            failures++;
            lastErr = err.localizedDescription ?: @"Save failed";
        }
    }

    [self.queuedFiles removeObjectsInArray:succeeded];
    [self.tableView reloadData];
    [self updateImportEnabled];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SCIGalleryFavoritesSortPreferenceChanged" object:nil];

    if (failures > 0) {
        NSString *subtitle = lastErr.length
            ? [NSString stringWithFormat:@"%lu couldn’t be saved · %@", (unsigned long)failures, lastErr]
            : [NSString stringWithFormat:@"%lu couldn’t be saved", (unsigned long)failures];
        [SCIUtils showToastForDuration:3.2
                                 title:@"Import incomplete"
                              subtitle:subtitle
                          iconResource:@"error_filled"];
        return;
    }

    if (self.queuedFiles.count == 0) {
        NSUInteger imported = succeeded.count;
        NSString *subtitle = imported == 1 ? @"1 file saved to gallery"
                                           : [NSString stringWithFormat:@"%lu files saved to gallery",
                                              (unsigned long)imported];
        [SCIUtils showToastForDuration:1.8
                                 title:@"Imported"
                              subtitle:subtitle
                          iconResource:@"circle_check_filled"];
        [self.navigationController popViewControllerAnimated:YES];
    }
}
@end
