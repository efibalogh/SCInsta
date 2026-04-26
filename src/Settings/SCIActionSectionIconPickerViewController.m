#import "SCIActionSectionIconPickerViewController.h"

#import "SCISymbol.h"
#import "../Shared/ActionButton/SCIActionDescriptor.h"

@interface SCIActionSectionIconPickerViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSString *selectedIconName;
@property (nonatomic, copy) void (^onSelect)(NSString *iconName);

@end

@implementation SCIActionSectionIconPickerViewController

- (instancetype)initWithSelectedIconName:(NSString *)selectedIconName
                                onSelect:(void (^)(NSString *iconName))onSelect
{
    self = [super init];
    if (self) {
        _selectedIconName = [selectedIconName copy] ?: @"more";
        _onSelect = [onSelect copy];
        self.title = @"Section Icon";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = NO;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [SCIActionDescriptor availableSectionIconDescriptors].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    UIListContentConfiguration *config = cell.defaultContentConfiguration;

    SCIActionDescriptor *descriptor = [SCIActionDescriptor availableSectionIconDescriptors][indexPath.row];
    config.text = descriptor.title;
    config.image = [[SCISymbol resourceSymbolWithName:descriptor.iconName color:[UIColor labelColor] size:22.0] image];
    config.imageProperties.tintColor = [UIColor labelColor];
    cell.contentConfiguration = config;
    cell.accessoryType = [descriptor.iconName isEqualToString:self.selectedIconName] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SCIActionDescriptor *descriptor = [SCIActionDescriptor availableSectionIconDescriptors][indexPath.row];
    self.selectedIconName = descriptor.iconName;
    if (self.onSelect) self.onSelect(descriptor.iconName);
    [self.tableView reloadData];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
