#import "SCIVaultViewController.h"
#import "SCIVaultFile.h"
#import "SCIVaultGridCell.h"
#import "SCIVaultCoreDataStack.h"
#import "../MediaPreview/SCIMediaPreviewController.h"
#import "../InstagramHeaders.h"
#import "../Utils.h"
#import <CoreData/CoreData.h>

static NSString * const kGridCellID = @"SCIVaultGridCell";
static CGFloat const kGridSpacing = 2.0;
static NSInteger const kGridColumns = 3;

@interface SCIVaultViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) UIView *emptyStateView;

@end

@implementation SCIVaultViewController

#pragma mark - Presentation

+ (void)presentVault {
    SCIVaultViewController *vc = [[SCIVaultViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;

    UIViewController *presenter = topMostController();
    [presenter presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Media Vault";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                             target:self
                             action:@selector(dismissSelf)];

    [self setupCollectionView];
    [self setupEmptyState];
    [self setupFetchedResultsController];
    [self updateEmptyState];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Collection View

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = kGridSpacing;
    layout.minimumLineSpacing = kGridSpacing;

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = [UIColor systemBackgroundColor];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.alwaysBounceVertical = YES;
    [_collectionView registerClass:[SCIVaultGridCell class] forCellWithReuseIdentifier:kGridCellID];
    [self.view addSubview:_collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [_collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

#pragma mark - Empty State

- (void)setupEmptyState {
    _emptyStateView = [[UIView alloc] initWithFrame:CGRectZero];
    _emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateView.hidden = YES;
    [self.view addSubview:_emptyStateView];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightLight];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"tray" withConfiguration:cfg]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [UIColor tertiaryLabelColor];
    [_emptyStateView addSubview:icon];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"No files in vault";
    label.textColor = [UIColor secondaryLabelColor];
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    [_emptyStateView addSubview:label];

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Save media from the preview screen\nto see it here.";
    subtitle.textColor = [UIColor tertiaryLabelColor];
    subtitle.font = [UIFont systemFontOfSize:14];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    [_emptyStateView addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [_emptyStateView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40],
        [_emptyStateView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-40],

        [icon.topAnchor constraintEqualToAnchor:_emptyStateView.topAnchor],
        [icon.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],

        [label.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],
        [label.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],

        [subtitle.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:8],
        [subtitle.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],
        [subtitle.bottomAnchor constraintEqualToAnchor:_emptyStateView.bottomAnchor],
    ]];
}

- (void)updateEmptyState {
    NSInteger count = self.fetchedResultsController.fetchedObjects.count;
    self.emptyStateView.hidden = count > 0;
    self.collectionView.hidden = count == 0;
}

#pragma mark - Fetched Results Controller

- (void)setupFetchedResultsController {
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"SCIVaultFile"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:NO]];

    NSManagedObjectContext *ctx = [SCIVaultCoreDataStack shared].viewContext;
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                    managedObjectContext:ctx
                                                                      sectionNameKeyPath:nil
                                                                               cacheName:nil];
    _fetchedResultsController.delegate = self;

    NSError *error;
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"[SCInsta Vault] Fetch failed: %@", error);
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.collectionView reloadData];
    [self updateEmptyState];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    id<NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return sectionInfo.numberOfObjects;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SCIVaultGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kGridCellID forIndexPath:indexPath];
    SCIVaultFile *file = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [cell configureWithVaultFile:file];
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat totalSpacing = kGridSpacing * (kGridColumns - 1);
    CGFloat side = (collectionView.bounds.size.width - totalSpacing) / kGridColumns;
    return CGSizeMake(side, side);
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    SCIVaultFile *file = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (![file fileExists]) {
        [SCIUtils showToastForDuration:2.0 title:@"File not found"];
        return;
    }

    SCIMediaPreviewController *preview = [SCIMediaPreviewController previewWithFileURL:[file fileURL]];
    preview.modalPresentationStyle = UIModalPresentationOverFullScreen;
    preview.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:preview animated:YES completion:nil];
}

- (UIContextMenuConfiguration *)collectionView:(UICollectionView *)collectionView contextMenuConfigurationForItemAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    SCIVaultFile *file = [self.fetchedResultsController objectAtIndexPath:indexPath];

    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        NSString *favTitle = file.isFavorite ? @"Unfavorite" : @"Favorite";
        NSString *favImage = file.isFavorite ? @"heart.slash" : @"heart";

        UIAction *favoriteAction = [UIAction actionWithTitle:favTitle
                                                       image:[UIImage systemImageNamed:favImage]
                                                  identifier:nil
                                                     handler:^(UIAction *action) {
            file.isFavorite = !file.isFavorite;
            [[SCIVaultCoreDataStack shared] saveContext];
        }];

        UIAction *shareAction = [UIAction actionWithTitle:@"Share"
                                                    image:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                               identifier:nil
                                                  handler:^(UIAction *action) {
            NSURL *url = [file fileURL];
            UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
            [self presentViewController:acVC animated:YES completion:nil];
        }];

        UIAction *deleteAction = [UIAction actionWithTitle:@"Delete"
                                                     image:[UIImage systemImageNamed:@"trash"]
                                                identifier:nil
                                                   handler:^(UIAction *action) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete from Vault?"
                                                                          message:@"This will permanently remove this file from the vault."
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
                NSError *err;
                [file removeWithError:&err];
                if (err) {
                    [SCIUtils showToastForDuration:2.0 title:@"Failed to delete" subtitle:err.localizedDescription];
                }
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }];
        deleteAction.attributes = UIMenuElementAttributesDestructive;

        return [UIMenu menuWithTitle:@"" children:@[favoriteAction, shareAction, deleteAction]];
    }];
}

@end
