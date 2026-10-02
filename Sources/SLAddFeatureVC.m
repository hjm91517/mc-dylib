#import "SLAddFeatureVC.h"
#import "SLModel.h"
#import "SLScriptManager.h"
#import "SLAPIClient.h"
#import "SLLogManager.h"
#import "SLTheme.h"

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
    self.view.backgroundColor = SLColorBG();
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
    // 安全起见默认选 JS，避免在未嵌入 Python.framework 的环境误以为 Python 可用
    self.typeSegment.selectedSegmentIndex = 0;
    self.typeSegment.frame = CGRectMake(pad, 16, W - pad * 2, 36);
    self.typeSegment.selectedSegmentTintColor = SLColorAccent();
    [self.typeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor],
                                               NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightMedium]}
                                    forState:UIControlStateSelected];
    [self.typeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: SLColorText2()}
                                    forState:UIControlStateNormal];
    [self.scrollView addSubview:self.typeSegment];

    // 名称
    self.nameField = [[UITextField alloc] initWithFrame:CGRectMake(pad, 64, W - pad * 2, 42)];
    self.nameField.placeholder = @"功能名称";
    self.nameField.font = [UIFont systemFontOfSize:15];
    self.nameField.textColor = SLColorText();
    self.nameField.backgroundColor = SLColorCard();
    self.nameField.layer.cornerRadius = 10;
    self.nameField.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    self.nameField.layer.borderColor = SLColorStroke().CGColor;
    self.nameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 42)];
    self.nameField.leftViewMode = UITextFieldViewModeAlways;
    self.nameField.clearButtonMode = UITextFieldViewModeWhileEditing;
    // 修复：改用公开 API attributedPlaceholder 设置占位文字颜色。
    // 旧写法 setValue:forKeyPath:@"_placeholderLabel.textColor" 访问 UITextField 私有属性，
    // 新版 iOS（16+）触发 UIKVCAccessProhibited 异常导致 viewDidLoad 阶段闪退。
    self.nameField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"功能名称"
        attributes:@{NSForegroundColorAttributeName: SLColorText3()}];
    [self.scrollView addSubview:self.nameField];

    // AI 辅助
    self.aiButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.aiButton.frame = CGRectMake(pad, 118, W - pad * 2, 42);
    [self.aiButton setTitle:@"🤖  让 AI 帮我写 / 优化脚本" forState:UIControlStateNormal];
    self.aiButton.backgroundColor = SLColorAccent();
    [self.aiButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.aiButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.aiButton.layer.cornerRadius = 10;
    [self.aiButton addTarget:self action:@selector(askAI) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.aiButton];

    // 脚本输入
    CGFloat tvY = 174;
    CGFloat tvH = H - tvY - 60;
    if (tvH < 220) tvH = 220;
    self.scriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(pad, tvY, W - pad * 2, tvH)];
    self.scriptTextView.font = [UIFont fontWithName:@"Menlo" size:13];
    self.scriptTextView.backgroundColor = SLColorCard();
    self.scriptTextView.textColor = SLColorText();
    self.scriptTextView.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    self.scriptTextView.layer.borderColor = SLColorStroke().CGColor;
    self.scriptTextView.layer.cornerRadius = 10;
    self.scriptTextView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    self.scriptTextView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.scriptTextView.autocorrectionType = UITextAutocorrectionTypeNo;
    [self.scrollView addSubview:self.scriptTextView];

    // 修复：手动 frame 布局必须显式设置 contentSize，否则小屏 / 横屏下脚本区无法滚动到底部
    self.scrollView.contentSize = CGSizeMake(W, tvY + tvH + 48);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.nameField becomeFirstResponder];
}

#pragma mark - 保存

- (void)save {
    [self.view endEditing:YES];

    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *script = [self.scriptTextView.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (!name.length)   { [self showToast:@"请填写功能名称"]; return; }
    if (!script.length) { [self showToast:@"脚本内容不能为空"]; return; }

    SLFeature *f = [[SLFeature alloc] init];
    f.featureId     = [[NSUUID UUID] UUIDString];
    f.name          = name;
    f.scriptType    = (self.typeSegment.selectedSegmentIndex == 1) ? @"py" : @"js";
    f.scriptContent = self.scriptTextView.text;
    f.enabled       = YES;

    [[SLScriptManager sharedInstance] saveFeature:f];
    [[SLLogManager sharedInstance] log:SLLogTypeSystem feature:@"添加"
                               message:[NSString stringWithFormat:@"已添加功能: %@", name]];

    if (self.onSave) self.onSave();
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - AI 辅助

- (void)askAI {
    [self.view endEditing:YES];

    if (![[SLAPIClient sharedInstance] apiKey].length) {
        [self showToast:@"请先在「设置」页填写 API Key"];
        return;
    }

    NSString *scriptType = (self.typeSegment.selectedSegmentIndex == 1) ? @"Python" : @"JavaScript";
    NSString *requirement = self.scriptTextView.text.length
        ? self.scriptTextView.text
        : self.nameField.text;
    if (!requirement.length) requirement = @"一个示例脚本";

    NSString *prompt = [NSString stringWithFormat:
        @"你是一个 iOS 游戏辅助脚本专家。请根据以下需求编写一段%@脚本。\n"
        @"脚本中可以调用 sl_log(消息) 打印日志、sl_alert(消息) 弹窗。\n"
        @"只输出脚本代码本身，不要任何解释或 markdown 代码块标记。\n\n需求：\n%@",
        scriptType, requirement];

    [self.aiButton setTitle:@"⏳ AI 生成中…" forState:UIControlStateNormal];
    self.aiButton.enabled = NO;

    NSArray *msgs = @[@{@"role": @"user", @"content": prompt}];
    __weak typeof(self) weakSelf = self;
    [[SLAPIClient sharedInstance] chatWithMessages:msgs completion:^(NSString *reply, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self2 = weakSelf;
            if (!self2) return;
            [self2.aiButton setTitle:@"🤖  让 AI 帮我写 / 优化脚本" forState:UIControlStateNormal];
            self2.aiButton.enabled = YES;
            if (error) {
                [self2 showToast:[NSString stringWithFormat:@"AI 请求失败: %@", error.localizedDescription]];
                return;
            }
            if (reply.length) {
                self2.scriptTextView.text = reply;
                [[SLLogManager sharedInstance] log:SLLogTypeAI feature:@"AI辅助"
                                           message:@"已生成脚本并填入编辑框"];
            }
        });
    }];
}

#pragma mark - 提示

- (void)showToast:(NSString *)msg {
    SLPresentToast(nil, msg);
}
@end
