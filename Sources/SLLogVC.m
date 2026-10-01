#import "SLLogVC.h"
#import "SLLogManager.h"

@interface SLLogVC () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UISegmentedControl *segment;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<SLLogEntry *> *current;
@end

@implementation SLLogVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"日志";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;

    self.segment = [[UISegmentedControl alloc] initWithItems:@[@"运行", @"失败", @"崩溃", @"AI", @"系统"]];
    self.segment.selectedSegmentIndex = 0;
    self.segment.frame = CGRectMake(12, 8, W - 24, 34);
    [self.segment addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segment];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"清空" style:UIBarButtonItemStylePlain
               target:self action:@selector(clear)];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 50, W, H - 50)
                                                  style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];

    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
}

- (void)refresh {
    SLLogType t = (SLLogType)self.segment.selectedSegmentIndex;
    NSArray *arr = [[SLLogManager sharedInstance] logsOfType:t];
    self.current = [[arr reverseObjectEnumerator] allObjects];
    [self.tableView reloadData];
}

- (void)clear {
    [[SLLogManager sharedInstance] clearAll];
    [self refresh];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.current.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"log"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"log"];
    SLLogEntry *e = self.current[indexPath.row];

    static NSDateFormatter *f = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        f = [[NSDateFormatter alloc] init];
        f.dateFormat = @"HH:mm:ss";
    });

    NSString *first = [[e.message componentsSeparatedByString:@"\n"] firstObject];
    cell.textLabel.text = [NSString stringWithFormat:@"[%@][%@] %@",
                           [f stringFromDate:e.timestamp], e.featureName, first];
    cell.textLabel.font = [UIFont systemFontOfSize:13];
    cell.detailTextLabel.text = e.message;
    cell.detailTextLabel.numberOfLines = 3;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SLLogEntry *e = self.current[indexPath.row];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:e.featureName
                                                               message:e.message
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end
