#import "FSLMenuViewController.h"
#import "FSLAddFunctionViewController.h"
#import "FSLSettingsViewController.h"
#import "FSLFunctionManager.h"
#import "FSLFunction.h"
#import "FSLCore.h"

@implementation FSLMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"脚本功能";
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(closeTapped)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self action:@selector(addTapped)];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
    self.tableView.tableFooterView = [UIView new];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.5;
    [self.tableView addGestureRecognizer:lp];

    UILabel *empty = [[UILabel alloc] init];
    empty.text = @"还没有功能\n点击右上角 + 添加脚本";
    empty.numberOfLines = 0;
    empty.textAlignment = NSTextAlignmentCenter;
    empty.textColor = UIColor.grayColor;
    empty.font = [UIFont systemFontOfSize:15];
    self.tableView.backgroundView = empty;

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload)
                                               name:FSLFunctionsDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload)
                                               name:FSLRunStateDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)reload {
    [self.tableView reloadData];
    self.tableView.backgroundView.hidden =
        [FSLFunctionManager shared].functions.count > 0;
}

- (void)closeTapped {
    [[FSLCore shared] dismissMenu];
}

- (void)addTapped {
    FSLAddFunctionViewController *vc = [FSLAddFunctionViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint p = [g locationInView:self.tableView];
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:p];
    if (!ip) return;
    FSLFunction *fn = [FSLFunctionManager shared].functions[ip.row];
    FSLSettingsViewController *vc = [[FSLSettingsViewController alloc] initWithFunction:fn];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [FSLFunctionManager shared].functions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    FSLFunction *fn = [FSLFunctionManager shared].functions[indexPath.row];
    BOOL running = [[FSLFunctionManager shared] isRunning:fn];

    cell.textLabel.text = fn.name;
    cell.textLabel.textColor = fn.enabled ? UIColor.labelColor : UIColor.grayColor;

    NSString *state = running ? @"运行中 ●" : (fn.enabled ? @"已开启" : @"已关闭");
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", [fn typeBadge], state];
    cell.detailTextLabel.textColor = running
        ? [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:1.0] : UIColor.grayColor;

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    FSLFunction *fn = [FSLFunctionManager shared].functions[indexPath.row];
    [[FSLFunctionManager shared] toggleRun:fn];
}

@end
