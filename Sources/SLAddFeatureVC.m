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
    // 安全起见默认选 JS，避免在未嵌入 Python.framework 的环境误以为 Python 可用
    self.typeSegment.selectedSegmentIndex = 0;
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
    [self.scrollView addSubview:self.scriptTextView];
}
