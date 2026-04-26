#import "SCIEditActionsListViewController.h"
#include <UIKit/UIKit.h>

#import "SCIActionSectionEditViewController.h"
#import "SCISymbol.h"
#import "../Shared/ActionButton/SCIActionDescriptor.h"
#import "../Utils.h"

static char kSCIActionsListSwitchAssocKey;

@interface SCIEditActionsListViewController () <UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SCIActionButtonConfiguration *configuration;

@end

@implementation SCIEditActionsListViewController

- (instancetype)initWithSource:(SCIActionButtonSource)source topicTitle:(NSString *)topicTitle {
    self = [super init];
    if (self) {
        _configuration = [SCIActionButtonConfiguration configurationForSource:source
                                                                   topicTitle:topicTitle
                                                             supportedActions:SCIActionButtonSupportedActionsForSource(source)
                                                              defaultSections:SCIActionButtonDefaultSectionsForSource(source)];
        self.title = @"Configure Actions";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    UIBarButtonItemStyle buttonStyle;
    if (@available(iOS 26.0, *)) {
        buttonStyle = (UIBarButtonItemStyle)2; // prominent
    } else {
        buttonStyle = UIBarButtonItemStylePlain;
    }
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[SCIUtils sci_resourceImageNamed:@"plus" template:YES]
                                                                              style:buttonStyle
                                                                             target:self
                                                                             action:@selector(addSectionTapped)];
    // self.navigationItem.rightBarButtonItem.tintColor = [UIColor labelColor];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.dragInteractionEnabled = YES;
    self.tableView.dragDelegate = self;
    self.tableView.dropDelegate = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.configuration.sections.count;
    if (section == 1) return self.configuration.unassignedActions.count;
    return self.configuration.supportedActions.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Menu Sections";
    if (section == 1) return @"Unassigned Actions";
    return @"Possible Actions";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"Drag to reorder sections. Tap a section to edit its title, icon, collapsible state, and actions.";
    if (section == 1) return @"Actions here are supported but do not appear in the runtime menu.";
    if (section == 2) return @"Disabled actions are hidden even if they remain assigned to a section.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    UIListContentConfiguration *config = cell.defaultContentConfiguration;

    if (indexPath.section == 0) {
        SCIActionMenuSection *section = self.configuration.sections[indexPath.row];
        config.text = section.title;
        config.secondaryText = section.collapsible ? @"Collapsible" : @"Inline";
        config.image = [[SCISymbol resourceSymbolWithName:section.iconName color:[UIColor labelColor] size:22.0] image];
        config.imageProperties.tintColor = [UIColor labelColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.showsReorderControl = YES;
    } else if (indexPath.section == 1) {
        NSString *identifier = self.configuration.unassignedActions[indexPath.row];
        config.text = SCIActionDescriptorDisplayTitle(identifier, self.configuration.topicTitle);
        config.image = [[SCISymbol resourceSymbolWithName:SCIActionDescriptorIconName(identifier) color:[UIColor labelColor] size:22.0] image];
        config.imageProperties.tintColor = [UIColor labelColor];
    } else {
        NSString *identifier = self.configuration.supportedActions[indexPath.row];
        config.text = SCIActionDescriptorDisplayTitle(identifier, self.configuration.topicTitle);
        config.image = [[SCISymbol resourceSymbolWithName:SCIActionDescriptorIconName(identifier) color:[UIColor labelColor] size:22.0] image];
        config.imageProperties.tintColor = [UIColor labelColor];

        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = ![self.configuration.disabledActions containsObject:identifier];
        toggle.onTintColor = [SCIUtils SCIColor_Primary];
        objc_setAssociatedObject(toggle, &kSCIActionsListSwitchAssocKey, identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [toggle addTarget:self action:@selector(disabledSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    cell.contentConfiguration = config;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0;
}

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0) return @[];
    SCIActionMenuSection *section = self.configuration.sections[indexPath.row];
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] initWithObject:section.identifier]];
    item.localObject = section.identifier;
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

    NSInteger rowCount = self.configuration.sections.count;
    NSInteger destinationRow = MIN(MAX(0, destinationIndexPath.row), MAX(0, rowCount - 1));
    NSIndexPath *target = [NSIndexPath indexPathForRow:destinationRow inSection:0];

    [tableView performBatchUpdates:^{
        [self.configuration moveSectionFromIndex:sourceIndexPath.row toIndex:target.row];
        [self.configuration save];
        [tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:target];
    } completion:nil];
    [coordinator dropItem:dropItem.dragItem toRowAtIndexPath:target];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        SCIActionMenuSection *section = self.configuration.sections[indexPath.row];
        __weak typeof(self) weakSelf = self;
        SCIActionSectionEditViewController *controller = [[SCIActionSectionEditViewController alloc] initWithConfiguration:self.configuration sectionIdentifier:section.identifier onChange:^{
            [weakSelf.configuration save];
            [weakSelf.tableView reloadData];
        }];
        [self.navigationController pushViewController:controller animated:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete || indexPath.section != 0) return;

    SCIActionMenuSection *section = self.configuration.sections[indexPath.row];
    for (NSString *identifier in section.actions) {
        if (![self.configuration.unassignedActions containsObject:identifier]) {
            [self.configuration.unassignedActions addObject:identifier];
        }
    }
    [self.configuration.sections removeObjectAtIndex:indexPath.row];
    [self.configuration save];
    [tableView reloadData];
}

- (void)addSectionTapped {
    SCIActionMenuSection *section = [SCIActionMenuSection sectionWithIdentifier:NSUUID.UUID.UUIDString
                                                                          title:[NSString stringWithFormat:@"Section %lu", (unsigned long)(self.configuration.sections.count + 1)]
                                                                       iconName:@"more"
                                                                    collapsible:YES
                                                                        actions:@[]];
    [self.configuration.sections addObject:section];
    [self.configuration save];
    [self.tableView reloadData];

    __weak typeof(self) weakSelf = self;
    SCIActionSectionEditViewController *controller = [[SCIActionSectionEditViewController alloc] initWithConfiguration:self.configuration sectionIdentifier:section.identifier onChange:^{
        [weakSelf.configuration save];
        [weakSelf.tableView reloadData];
    }];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)disabledSwitchChanged:(UISwitch *)sender {
    NSString *identifier = objc_getAssociatedObject(sender, &kSCIActionsListSwitchAssocKey);
    if (identifier.length == 0) return;

    if (sender.isOn) {
        [self.configuration.disabledActions removeObject:identifier];
    } else if (![self.configuration.disabledActions containsObject:identifier]) {
        [self.configuration.disabledActions addObject:identifier];
    }
    [self.configuration save];
}

@end
