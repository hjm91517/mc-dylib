#import "SLFeatureListVC.h"
#import "SLScriptManager.h"
#import "SLAddFeatureVC.h"
#import "SLSettingVC.h"
#import "SLScriptEngine.h"
#import "SLHotkeyManager.h"

@interface SLFeatureListVC () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<SLFeature *> *features;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation SLFeatureListVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"功能列表";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                             target:self action:@selector(addFeature)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];

    self.emptyLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
    self.emptyLabel.text = @"暂无功能\n点击右上角 + 添加脚本";
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.hidden = YES;
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.emptyLabel];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleLongPress:)];
    [self.tableView addGestureRecognizer:lp];

    [self loadFeatures];
    [[SLHotkeyManager sharedInstance] rebuildAll];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadFeatures];
}

- (void)loadFeatures {
    self.features = [[SLScriptManager sharedInstance] loadAllFeatures];
    self.emptyLabel.hidden = self.features.count > 0;
    [self.tableView reloadData];
}

- (void)addFeature {
    SLAddFeatureVC *vc = [[SLAddFeatureVC alloc] init];
    __weak typeof(self) weakSelf = self;
    vc.onSave = ^{
        [weakSelf loadFeatures];
        [[SLHotkeyManager sharedInstance] rebuildAll];
    };
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.features.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    SLFeature *f = self.features[indexPath.row];

    NSString *icon = [f.lastRunStatus isEqualToString:@"success"] ? @"✅" :
                     [f.lastRunStatus isEqualToString:@"fail"]    ? @"❌" : @"⚪";
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", icon, f.name];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
                                 [f.scriptType uppercaseString],
                                 f.enabled ? @"启用" : @"停用"];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.accessoryType = f.enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SLFeature *f = self.features[indexPath.row];
    BOOL ok = [SLScriptEngine runScript:f.scriptContent
                                    type:f.scriptType
                               variables:f.settings
                             featureName:f.name];
    f.lastRunStatus = ok ? @"success" : @"fail";
    f.lastRunTime = [NSDate date];
    [[SLScriptManager sharedInstance] saveFeature:f];
    [self loadFeatures];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                      title:@"删除"
                                                                    handler:^(UIContextualAction *action, UIView *src, void (^done)(BOOL)) {
        SLFeature *f = self.features[indexPath.row];
        [[SLScriptManager sharedInstance] deleteFeature:f];
        [[SLHotkeyManager sharedInstance] removeHotkeyForFeatureId:f.featureId];
        [self loadFeatures];
        done(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint p = [g locationInView:self.tableView];
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:p];
    if (!ip) return;
    SLFeature *f = self.features[ip.row];
    SLSettingVC *vc = [[SLSettingVC alloc] initWithFeature:f];
    __weak typeof(self) weakSelf = self;
    vc.onSave = ^{
        [weakSelf loadFeatures];
        [[SLHotkeyManager sharedInstance] rebuildAll];
    };
    [self.navigationController pushViewController:vc animated:YES];
}
@end
