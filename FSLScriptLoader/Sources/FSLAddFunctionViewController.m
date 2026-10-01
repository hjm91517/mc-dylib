#import "FSLAddFunctionViewController.h"
#import "FSLFunction.h"
#import "FSLFunctionManager.h"
#import "FSLConfigParser.h"
#import "FSLCommon.h"

static NSString *const kJSTemplate =
@"// 新建 JS 脚本\n"
@"// 用 //@config 声明可在设置页修改的参数（单行 JSON）：\n"
@"//@config {\"key\":\"times\",\"type\":\"number\",\"default\":3,\"label\":\"循环次数\"}\n"
@"//@config {\"key\":\"showAlert\",\"type\":\"bool\",\"default\":true,\"label\":\"完成后弹窗\"}\n"
@"\n"
@"var times = getConfig(\"times\") || 3;\n"
@"for (var i = 0; i < times; i++) {\n"
@"    if (shouldStop()) { break; }\n"
@"    log(\"第 \" + (i + 1) + \" 次\");\n"
@"}\n"
@"if (getConfig(\"showAlert\")) {\n"
@"    alert(\"JS 脚本执行完成\");\n"
@"}\n";

static NSString *const kPYTemplate =
@"# 新建 Python 脚本\n"
@"# 用 #@config 声明可在设置页修改的参数（单行 JSON）：\n"
@"#@config {\"key\":\"times\",\"type\":\"number\",\"default\":3,\"label\":\"循环次数\"}\n"
@"\n"
@"import fsl\n"
@"\n"
@"times = fsl.get_config(\"times\") or 3\n"
@"for i in range(times):\n"
@"    if fsl.should_stop():\n"
@"        break\n"
@"    fsl.log(\"第 %d 次\" % (i + 1))\n"
@"\n"
@"fsl.alert(\"Python 脚本执行完成\")\n";

@interface FSLAddFunctionViewController ()
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UISegmentedControl *typeSeg;
@property (nonatomic, strong) UITextView *sourceView;
@property (nonatomic, assign) BOOL sourceEdited;
@end

@implementation FSLAddFunctionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"添加功能";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone
                                        target:self action:@selector(saveTapped)];

    _nameField = [[UITextField alloc] init];
    _nameField.placeholder = @"功能名称";
    _nameField.borderStyle = UITextBorderStyleRoundedRect;
    _nameField.backgroundColor = UIColor.secondarySystemBackgroundColor;
    [self.view addSubview:_nameField];

    _typeSeg = [[UISegmentedControl alloc] initWithItems:@[@"JS 脚本", @"PY 脚本"]];
    _typeSeg.selectedSegmentIndex = 0;
    [_typeSeg addTarget:self action:@selector(typeChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_typeSeg];

    _sourceView = [[UITextView alloc] init];
    _sourceView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    _sourceView.layer.cornerRadius = 8;
    _sourceView.layer.borderWidth = 0.5;
    _sourceView.layer.borderColor = UIColor.separatorColor.CGColor;
    _sourceView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _sourceView.autocorrectionType = UITextAutocorrectionTypeNo;
    _sourceView.smartQuotesType = UITextSmartQuotesTypeNo;
    _sourceView.smartDashesType = UITextSmartDashesTypeNo;
    _sourceView.text = kJSTemplate;
    [self.view addSubview:_sourceView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self.view
                                                                          action:@selector(endEditing:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.view.safeAreaInsets.top + 12;
    CGFloat w = self.view.bounds.size.width - 32;
    self.nameField.frame = CGRectMake(16, top, w, 40);
    self.typeSeg.frame = CGRectMake(16, top + 52, w, 32);
    self.sourceView.frame = CGRectMake(16, top + 96, w, self.view.bounds.size.height - top - 120);
}

- (void)typeChanged {
    // 未手动改过内容时，切换类型自动换模板
    NSString *current = self.sourceView.text;
    if (!self.sourceEdited || [current isEqualToString:kJSTemplate] || [current isEqualToString:kPYTemplate]) {
        self.sourceView.text = self.typeSeg.selectedSegmentIndex == 0 ? kJSTemplate : kPYTemplate;
    }
}

- (void)saveTapped {
    [self.view endEditing:YES];
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *source = self.sourceView.text ?: @"";
    if (name.length == 0) {
        FSLShowAlert(@"无法保存", @"请先填写功能名称。");
        return;
    }
    if (source.length == 0) {
        FSLShowAlert(@"无法保存", @"脚本内容不能为空。");
        return;
    }

    FSLFunction *fn = [FSLFunction new];
    fn.name = name;
    fn.source = source;
    fn.type = self.typeSeg.selectedSegmentIndex == 0 ? FSLScriptTypeJS : FSLScriptTypePython;
    fn.enabled = YES;

    // 按 @config 声明预填默认值
    for (FSLConfigItem *item in [FSLConfigParser parseSource:source type:fn.type]) {
        fn.configValues[item.key] = item.defaultValue;
    }

    [[FSLFunctionManager shared] addFunction:fn];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
