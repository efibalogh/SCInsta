#import "SCIActionSectionEditViewController.h"
#import "SCIActionSectionIconPickerViewController.h"

#import "SCISymbol.h"
#import "../Shared/ActionButton/SCIActionDescriptor.h"
#import "../Utils.h"

static char kSCISectionEditFieldAssocKey;
static char kSCISectionEditSwitchAssocKey;

@interface SCIActionSectionEditViewController () <UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SCIActionButtonConfiguration *configuration;
@property (nonatomic, copy) NSString *sectionIdentifier;
@property (nonatomic, copy) dispatch_block_t onChange;

@end

@implementation SCIActionSectionEditViewController

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SCIUtils SCIColor_InstagramPressedBackground];
    return view;
}

- (NSString *)displayTitleForSectionIconName:(NSString *)iconName {
    SCIActionDescriptor *descriptor = [SCIActionDescriptor descriptorForIdentifier:iconName];
    return descriptor.title ?: iconName;
}

- (void)showIconPicker {
    SCIActionMenuSection *section = [self currentSection];
    if (!section) return;

    __weak typeof(self) weakSelf = self;
    SCIActionSectionIconPickerViewController *controller = [[SCIActionSectionIconPickerViewController alloc] initWithSelectedIconName:section.iconName onSelect:^(NSString *iconName) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        SCIActionMenuSection *strongSection = [strongSelf currentSection];
        strongSection.iconName = iconName;
        [strongSelf.configuration save];
        if (strongSelf.onChange) strongSelf.onChange();
        [strongSelf.tableView reloadData];
    }];
    [self.navigationController pushViewController:controller animated:YES];
}

- (instancetype)initWithConfiguration:(SCIActionButtonConfiguration *)configuration
                    sectionIdentifier:(NSString *)sectionIdentifier
                             onChange:(dispatch_block_t)onChange
{
    self = [super init];
    if (self) {
        _configuration = configuration;
        _sectionIdentifier = [sectionIdentifier copy];
        _onChange = [onChange copy];
        self.title = @"Edit Section";
    }
    return self;
}

- (SCIActionMenuSection *)currentSection {
    return [self.configuration sectionWithIdentifier:self.sectionIdentifier];
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 3;
    if (section == 1) return [self currentSection].actions.count;
    return self.configuration.supportedActions.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Section";
    if (section == 1) return @"Actions in This Section";
    return @"Available Actions";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return @"Drag to reorder actions in this section. Remove an action to send it to the unassigned bucket.";
    if (section == 2) return @"Tap an action to assign it here. If it is already in another section, it will move.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCIActionMenuSection *section = [self currentSection];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    UIListContentConfiguration *config = cell.defaultContentConfiguration;
    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.tintColor = [SCIUtils SCIColor_Primary];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    config.textProperties.color = [SCIUtils SCIColor_InstagramPrimaryText];
    config.secondaryTextProperties.color = [SCIUtils SCIColor_InstagramSecondaryText];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            config.text = @"Title";
            UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
            field.textAlignment = NSTextAlignmentRight;
            field.placeholder = @"Section";
            field.text = section.title;
            field.delegate = self;
            objc_setAssociatedObject(field, &kSCISectionEditFieldAssocKey, self, OBJC_ASSOCIATION_ASSIGN);
            [field addTarget:self action:@selector(titleFieldChanged:) forControlEvents:UIControlEventEditingChanged];
            cell.accessoryView = field;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            config.text = @"Icon";
            config.secondaryText = [self displayTitleForSectionIconName:section.iconName];
            config.image = [[SCISymbol resourceSymbolWithName:section.iconName color:[SCIUtils SCIColor_InstagramPrimaryText] size:22.0] image];
            config.imageProperties.tintColor = [SCIUtils SCIColor_InstagramPrimaryText];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else {
            config.text = @"Collapsible";
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = section.collapsible;
            toggle.onTintColor = [SCIUtils SCIColor_Primary];
            objc_setAssociatedObject(toggle, &kSCISectionEditSwitchAssocKey, self, OBJC_ASSOCIATION_ASSIGN);
            [toggle addTarget:self action:@selector(collapsibleSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (indexPath.section == 1) {
        NSString *identifier = section.actions[indexPath.row];
        config.text = SCIActionDescriptorDisplayTitle(identifier, self.configuration.topicTitle);
        config.image = [[SCISymbol resourceSymbolWithName:SCIActionDescriptorIconName(identifier) color:[SCIUtils SCIColor_InstagramPrimaryText] size:22.0] image];
        config.imageProperties.tintColor = [SCIUtils SCIColor_InstagramPrimaryText];
        cell.showsReorderControl = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        NSString *identifier = self.configuration.supportedActions[indexPath.row];
        config.text = SCIActionDescriptorDisplayTitle(identifier, self.configuration.topicTitle);
        config.image = [[SCISymbol resourceSymbolWithName:SCIActionDescriptorIconName(identifier) color:[SCIUtils SCIColor_InstagramPrimaryText] size:22.0] image];
        config.imageProperties.tintColor = [SCIUtils SCIColor_InstagramPrimaryText];

        NSString *owner = [self.configuration sectionIdentifierForAction:identifier];
        if ([owner isEqualToString:section.identifier]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            config.secondaryText = @"In this section";
        } else if (owner.length > 0) {
            SCIActionMenuSection *ownerSection = [self.configuration sectionWithIdentifier:owner];
            config.secondaryText = ownerSection.title;
        } else {
            config.secondaryText = @"Unassigned";
        }
    }

    cell.contentConfiguration = config;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1) return @[];
    NSString *identifier = [self currentSection].actions[indexPath.row];
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
    if (session.localDragSession == nil || destinationIndexPath.section != 1) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    }
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    NSIndexPath *destinationIndexPath = coordinator.destinationIndexPath;
    id<UITableViewDropItem> dropItem = coordinator.items.firstObject;
    NSIndexPath *sourceIndexPath = dropItem.sourceIndexPath;
    if (!destinationIndexPath || !sourceIndexPath || sourceIndexPath.section != 1 || destinationIndexPath.section != 1) return;

    NSInteger rowCount = [self currentSection].actions.count;
    NSInteger destinationRow = MIN(MAX(0, destinationIndexPath.row), MAX(0, rowCount - 1));
    NSIndexPath *target = [NSIndexPath indexPathForRow:destinationRow inSection:1];

    [tableView performBatchUpdates:^{
        [self.configuration moveActionInSectionIdentifier:self.sectionIdentifier fromIndex:sourceIndexPath.row toIndex:target.row];
        [self.configuration save];
        if (self.onChange) self.onChange();
        [tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:target];
    } completion:nil];
    [coordinator dropItem:dropItem.dragItem toRowAtIndexPath:target];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 1) {
        [self showIconPicker];
    } else if (indexPath.section == 1) {
        NSString *identifier = [self currentSection].actions[indexPath.row];
        [self.configuration setAction:identifier assignedToSectionIdentifier:nil];
        [self.configuration save];
        if (self.onChange) self.onChange();
        [self.tableView reloadData];
    } else if (indexPath.section == 2) {
        NSString *identifier = self.configuration.supportedActions[indexPath.row];
        NSString *owner = [self.configuration sectionIdentifierForAction:identifier];
        if ([owner isEqualToString:self.sectionIdentifier]) {
            [self.configuration setAction:identifier assignedToSectionIdentifier:nil];
        } else {
            [self.configuration setAction:identifier assignedToSectionIdentifier:self.sectionIdentifier];
        }
        [self.configuration save];
        if (self.onChange) self.onChange();
        [self.tableView reloadData];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)titleFieldChanged:(UITextField *)sender {
    SCIActionMenuSection *section = [self currentSection];
    section.title = sender.text.length > 0 ? sender.text : @"Section";
    [self.configuration save];
    if (self.onChange) self.onChange();
}

- (void)collapsibleSwitchChanged:(UISwitch *)sender {
    SCIActionMenuSection *section = [self currentSection];
    section.collapsible = sender.isOn;
    [self.configuration save];
    if (self.onChange) self.onChange();
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

@end
