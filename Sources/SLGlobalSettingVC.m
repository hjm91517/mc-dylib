#import "SLGlobalSettingVC.h"
#import "SLAPIClient.h"

static const NSInteger kKeyTag   = 3000;
static const NSInteger kURLTag   = 3001;
static const NSInteger kModelTag = 3002;

@interface SLGlobalSettingVC () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation SLGlobalSettingVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"设置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                             target:self action:@selector(save)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 3 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"AI API 配置" : @"说明";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"支持 OpenAI 兼容接口。Base URL 例：https://api.openai.com/v1 或自建代理。";
    return @"所有数据保存在 App 沙盒 Documents/SLNetEaseMC/。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    CGFloat W = tableView.bounds.size.width;

    if (indexPath.section == 0) {
        NSArray *titles = @[@"API Key", @"Base URL", @"Model"];
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 100, 44)];
        l.text = titles[indexPath.row];
        l.font = [UIFont boldSystemFontOfSize:14];
        [cell.contentView addSubview:l];

        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(116, 6, W - 132, 32)];
        tf.borderStyle = UITextBorderStyleRoundedRect;
        tf.font = [UIFont systemFontOfSize:13];
        tf.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        if (indexPath.row == 0) {
            tf.text = [[SLAPIClient sharedInstance] apiKey];
            tf.secureTextEntry = YES;
            tf.placeholder = @"sk-...";
            tf.tag = kKeyTag;
        } else if (indexPath.row == 1) {
            tf.text = [[SLAPIClient sharedInstance] baseURL];
            tf.placeholder = @"https://api.openai.com/v1";
            tf.tag = kURLTag;
        } else {
            tf.text = [[SLAPIClient sharedInstance] model];
            tf.placeholder = @"gpt-3.5-turbo";
            tf.tag = kModelTag;
        }
        [cell.contentView addSubview:tf];
    } else {
        cell.textLabel.text = @"SLNetEaseMC · 脚本加载器 + AI 助手";
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
    }
    return cell;
}

- (void)save {
    [self.view endEditing:YES];
    UITextField *f0 = [self.tableView viewWithTag:kKeyTag];
    UITextField *f1 = [self.tableView viewWithTag:kURLTag];
    UITextField *f2 = [self.tableView viewWithTag:kModelTag];

    if (f0.text) [[SLAPIClient sharedInstance] setApiKey:f0.text];
    if (f1.text.length) [[SLAPIClient sharedInstance] setBaseURL:f1.text];
    if (f2.text.length) [[SLAPIClient sharedInstance] setModel:f2.text];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"已保存"
                                                               message:nil
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
