#import "SCIBulkActionMenuEditViewController.h"

#import "SCITopicSettingsSupport.h"
#import "../AssetUtils.h"
#import "../Utils.h"
#import "../Shared/ActionButton/SCIActionButtonConfiguration.h"
#import "../Shared/ActionButton/SCIActionDescriptor.h"

@interface SCIBulkActionMenuEditViewController () <UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) SCIActionButtonSource source;
@property (nonatomic, copy) NSArray<NSString *> *supportedActions;
@property (nonatomic, strong) NSMutableArray<NSString *> *configuredActions;
@property (nonatomic, copy) void (^onSave)(NSArray<NSString *> *actions);

@end

@implementation SCIBulkActionMenuEditViewController

- (instancetype)initWithTitle:(NSString *)title
                       source:(SCIActionButtonSource)source
             supportedActions:(NSArray<NSString *> *)supportedActions
            configuredActions:(NSArray<NSString *> *)configuredActions
                       onSave:(void (^)(NSArray<NSString *> *actions))onSave
{
    self = [super init];
    if (self) {
        self.title = title;
        _source = source;
        _supportedActions = [supportedActions copy] ?: @[];
        _configuredActions = [configuredActions mutableCopy] ?: [NSMutableArray array];
        _onSave = [onSave copy];
    }
    return self;
}

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SCIUtils SCIColor_InstagramPressedBackground];
    return view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.dragInteractionEnabled = YES;
    self.tableView.dragDelegate = self;
    self.tableView.dropDelegate = self;
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
    self.tableView.tintColor = [SCIUtils SCIColor_Primary];
    [self.view addSubview:self.tableView];
}

- (NSArray<NSString *> *)availableActions {
    NSMutableArray<NSString *> *available = [NSMutableArray array];
    for (NSString *identifier in self.supportedActions) {
        if (![self.configuredActions containsObject:identifier]) {
            [available addObject:identifier];
        }
    }
    return available;
}

- (void)persist {
    if (self.onSave) self.onSave([self.configuredActions copy]);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? self.configuredActions.count : self.availableActions.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Enabled Actions" : @"Available Actions";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"Drag to reorder. Tap to disable an action.";
    return @"Tap an action to enable it in this submenu.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    UIListContentConfiguration *config = cell.defaultContentConfiguration;
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.tintColor = [SCIUtils SCIColor_Primary];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    config.textProperties.color = [SCIUtils SCIColor_InstagramPrimaryText];
    config.secondaryTextProperties.color = [SCIUtils SCIColor_InstagramSecondaryText];

    NSString *identifier = (indexPath.section == 0) ? self.configuredActions[indexPath.row] : self.availableActions[indexPath.row];
    config.text = SCIActionDescriptorDisplayTitle(identifier, SCIActionButtonTopicTitleForSource(self.source));
    config.image = SCISettingsIcon(SCIActionDescriptorIconName(identifier));
    config.imageProperties.tintColor = [SCIUtils SCIColor_InstagramPrimaryText];
    cell.contentConfiguration = config;
    cell.showsReorderControl = (indexPath.section == 0);
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0;
}

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0) return @[];
    NSString *identifier = self.configuredActions[indexPath.row];
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] initWithObject:identifier]];
    item.localObject = identifier;
    return @[item];
}

- (BOOL)tableView:(UITableView *)tableView dragSessionAllowsMoveOperation:(id<UIDragSession>)session {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView dragSessionIsRestrictedToDraggingApplication:(id<UIDragSession>)session {
    return YES;
}

- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    if (session.localDragSession == nil || destinationIndexPath.section != 0) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    }
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    NSIndexPath *destinationIndexPath = coordinator.destinationIndexPath;
    id<UITableViewDropItem> dropItem = coordinator.items.firstObject;
    NSIndexPath *sourceIndexPath = dropItem.sourceIndexPath;
    if (!destinationIndexPath || !sourceIndexPath || sourceIndexPath.section != 0 || destinationIndexPath.section != 0) return;

    NSInteger destinationRow = MIN(MAX(0, destinationIndexPath.row), MAX(0, self.configuredActions.count - 1));
    NSString *identifier = self.configuredActions[sourceIndexPath.row];
    [tableView performBatchUpdates:^{
        [self.configuredActions removeObjectAtIndex:sourceIndexPath.row];
        [self.configuredActions insertObject:identifier atIndex:destinationRow];
        [self persist];
        [tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:[NSIndexPath indexPathForRow:destinationRow inSection:0]];
    } completion:nil];
    [coordinator dropItem:dropItem.dragItem toRowAtIndexPath:[NSIndexPath indexPathForRow:destinationRow inSection:0]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        [self.configuredActions removeObjectAtIndex:indexPath.row];
    } else {
        NSString *identifier = self.availableActions[indexPath.row];
        [self.configuredActions addObject:identifier];
    }
    [self persist];
    [self.tableView reloadData];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
