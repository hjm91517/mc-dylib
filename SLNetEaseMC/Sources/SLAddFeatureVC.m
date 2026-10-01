#import "SLAddFeatureVC.h"
#import "SLModel.h"
#import "SLScriptManager.h"
#import "SLAPIClient.h"
#import "SLLogManager.h"

@interface SLAddFeatureVC ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextView *scriptTextView;
@property (nonatomic, strong) UIButton *aiButton;
@end

@implementation SLAddFeatureVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"添加功能";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                             target:self action:@selector(save)];

    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;
    CGFloat pad = 16;

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.scrollView];

    // 类型选择
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[@"JS 脚本", @"Python 脚本"]];
    self.typeSegment.selectedSegmentIndex = 1;
    self.typeSegment.frame = CGRectMake(pad, 16, W - pad * 2, 36);
    [self.scrollView addSubview:self.typeSegment];

    // 名称
    self.nameField = [[UITextField alloc] initWithFrame:CGRectMake(pad, 64, W - pad * 2, 42)];
    self.nameField.placeholder = @"功能名称";
    self.nameField.borderStyle = UITextBorderStyleRoundedRect;
    self.nameField.font = [UIFont systemFontOfSize:15];
    self.nameField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.scrollView addSubview:self.nameField];

    // AI 辅助
    self.aiButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.aiButton.frame = CGRectMake(pad, 118, W - pad * 2, 42);
    [self.aiButton setTitle:@"🤖  让 AI 帮我写 / 优化脚本" forState:UIControlStateNormal];
    self.aiButton.backgroundColor = [UIColor systemBlueColor];
    [self.aiButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.aiButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.aiButton.layer.cornerRadius = 8;
    [self.aiButton addTarget:self action:@selector(askAI) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.aiButton];

    // 脚本输入
    CGFloat tvY = 174;
    CGFloat tvH = H - tvY - 40;
    if (tvH < 220) tvH = 220;
    self.scriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(pad, tvY, W - pad * 2, tvH)];
    self.scriptTextView.font = [UIFont fontWithName:@"Menlo" size:13];
    self.scriptTextView.layer.borderWidth = 1;
    self.scriptTextView.layer.borderColor = [UIColor systemGray4Color].CGColor;
    self.scriptTextView.layer.cornerRadius = 8;
    self.scriptTextView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    self.scriptTextView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.scriptTextView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.scriptTextView.smartQuotesType = UITextSmartQuotesTypeNo;
    self.scriptTextView.smartDashesType = UITextSmartDashesTypeNo;
    self.scriptTextView.text =
        @"# Python 脚本示例\n"
        @"# 用 $变量名 = 默认值 定义可在设置中修改的参数\n"
        @"# （引擎会自动把 $变量名 转成合法 Python 变量）\n\n"
        @"import scriptloader\n\n"
        @"$message = \"Hello Minecraft\"\n"
        @"scriptloader.sl_log($message)";
    [self.scrollView addSubview:self.scriptTextView];

    self.scrollView.contentSize = CGSizeMake(W, tvY + tvH + 40);
}

- (void)save {
    NSString *name = self.nameField.text.length ? self.nameField.text : @"未命名";
    SLFeature *f = [[SLFeature alloc] init];
    f.featureId     = [[NSUUID UUID] UUIDString];
    f.name          = name;
    f.scriptType    = self.typeSegment.selectedSegmentIndex == 0 ? @"js" : @"py";
    f.scriptContent = self.scriptTextView.text ?: @"";
    f.enabled       = YES;
    f.settings      = [NSMutableDictionary dictionary];
    [[SLScriptManager sharedInstance] saveFeature:f];
    [[SLLogManager sharedInstance] log:SLLogTypeSystem feature:name message:@"功能已保存"];
    if (self.onSave) self.onSave();
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)askAI {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AI 辅助"
                                                                   message:@"描述你的需求，AI 会生成或优化脚本"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"例如：每隔 3 秒显示一次提示";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"发送" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *q = alert.textFields.firstObject.text;
        if (!q.length) return;
        NSString *lang = weakSelf.typeSegment.selectedSegmentIndex == 0 ? @"JavaScript" : @"Python";
        NSString *sys = [NSString stringWithFormat:
            @"你是一个 iOS 脚本助手。请用 %@ 生成脚本。"
            @"环境说明：Python 可 import scriptloader 后调用 sl_alert(msg)、sl_log(msg)、sl_http_get(url)。"
            @"JS 可调用 sl_log(msg)、sl_alert(msg)。脚本中可用 $变量名 = 默认值 定义设置项。只输出代码，不要解释。", lang];
        NSArray *msgs = @[
            @{@"role": @"system", @"content": sys},
            @{@"role": @"user",   @"content": q}
        ];
        [[SLLogManager sharedInstance] log:SLLogTypeAI feature:@"Ask" message:q];
        [[SLAPIClient sharedInstance] chatWithMessages:msgs completion:^(NSString *reply, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    UIAlertController *e = [UIAlertController alertControllerWithTitle:@"AI 失败"
                                                                                message:error.localizedDescription
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                    [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [weakSelf presentViewController:e animated:YES completion:nil];
                    return;
                }
                weakSelf.scriptTextView.text = reply ?: @"";
                [[SLLogManager sharedInstance] log:SLLogTypeAI feature:@"Reply" message:@"脚本已生成"];
            });
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
