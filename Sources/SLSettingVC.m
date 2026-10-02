#import "SLSettingVC.h"
#import "SLScriptManager.h"
#import "SLScriptEngine.h"
#import "SLTheme.h"

static const NSInteger kFieldTagBase = 1000;

@interface SLSettingVC () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) SLFeature *feature;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *detectedVars;
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UISwitch *hotkeySwitch;
@end

@implementation SLSettingVC

- (instancetype)initWithFeature:(SLFeature *)feature {
    if (self = [super init]) {
        _feature = feature;
        _detectedVars = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.feature.name;
    self.view.backgroundColor = SLColorBG();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                             target:self action:@selector(save)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = SLColorStroke();
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.tableView];

    [self parseScriptVariables];
}

// 深色主题：表头 / 表尾文字颜色
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        ((UITableViewHeaderFooterView *)view).textLabel.textColor = SLColorText2();
    }
}
- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        ((UITableViewHeaderFooterView *)view).textLabel.textColor = SLColorText3();
    }
}

- (void)parseScriptVariables {
    [self.detectedVars removeAllObjects];
    NSString *pyPattern = @"^\\s*\\$(\\w+)\\s*=\\s*(.+?)\\s*$";
    NSString *jsPattern = @"var\\s+\\$(\\w+)\\s*=\\s*([^;]+);";
    NSString *pattern = [self.feature.scriptType isEqualToString:@"js"] ? jsPattern : pyPattern;

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionAnchorsMatchLines
                                                                             error:nil];
    NSString *content = self.feature.scriptContent ?: @"";
    NSArray *matches = [regex matchesInString:content options:0 range:NSMakeRange(0, content.length)];
    for (NSTextCheckingResult *m in matches) {
        if (m.numberOfRanges < 3) continue;
        NSString *name   = [content substringWithRange:[m rangeAtIndex:1]];
        NSString *defVal = [content substringWithRange:[m rangeAtIndex:2]];
        defVal = [defVal stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (defVal.length >= 2 &&
            (([defVal hasPrefix:@"\""] && [defVal hasSuffix:@"\""]) ||
             ([defVal hasPrefix:@"'"]  && [defVal hasSuffix:@"'"]))) {
            defVal = [defVal substringWithRange:NSMakeRange(1, defVal.length - 2)];
        }
        NSString *current = self.feature.settings[name] ?: defVal;
        [self.detectedVars addObject:[@{@"name": name, @"value": current} mutableCopy]];
    }
}

#pragma mark - 变量输入即时写回（修复：离屏 cell 取不到导致丢数据）

- (void)varFieldChanged:(UITextField *)tf {
    NSInteger idx = tf.tag - kFieldTagBase;
    if (idx < 0 || idx >= (NSInteger)self.detectedVars.count) return;
    self.detectedVars[idx][@"value"] = tf.text ?: @"";
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return self.detectedVars.count;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"开关";
    if (section == 1) return self.detectedVars.count ? @"脚本变量" : nil;
    return @"操作";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return @"在脚本中用 $变量名 = 默认值 声明（JS 用 var $变量名 = 值;），即可在此处修改。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = SLColorCard();

    CGFloat W = tableView.bounds.size.width;

    if (indexPath.section == 0) {
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, W - 100, 44)];
        l.text = indexPath.row == 0 ? @"启用功能" : @"显示快捷键悬浮按钮";
        l.font = [UIFont systemFontOfSize:15];
        l.textColor = SLColorText();
        [cell.contentView addSubview:l];

        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = SLColorAccent();
        if (indexPath.row == 0) {
            sw.on = self.feature.enabled;
            self.enableSwitch = sw;
        } else {
            sw.on = self.feature.hotkeyVisible;
            self.hotkeySwitch = sw;
        }
        cell.accessoryView = sw;
    } else if (indexPath.section == 1) {
        NSDictionary *v = self.detectedVars[indexPath.row];
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 110, 44)];
        l.text = v[@"name"];
        l.font = [UIFont boldSystemFontOfSize:14];
        l.textColor = SLColorText();
        [cell.contentView addSubview:l];

        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(130, 6, W - 146, 32)];
        tf.borderStyle = UITextBorderStyleRoundedRect;
        tf.text = v[@"value"];
        tf.font = [UIFont systemFontOfSize:14];
        tf.textColor = SLColorText();
        tf.backgroundColor = SLColorCardAlt();
        tf.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        tf.tag = kFieldTagBase + indexPath.row;
        [tf addTarget:self action:@selector(varFieldChanged:) forControlEvents:UIControlEventEditingDidEnd];
        [cell.contentView addSubview:tf];
    } else {
        cell.textLabel.text = @"▶️ 立即运行一次";
        cell.textLabel.textColor = SLColorAccent();
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2) {
        [self.view endEditing:YES];
        [self collectToFeature];
        [SLScriptEngine runScript:self.feature.scriptContent
                             type:self.feature.scriptType
                        variables:self.feature.settings
                      featureName:self.feature.name];
    }
}

/// 把界面状态收集回 feature（不保存）
- (void)collectToFeature {
    self.feature.enabled       = self.enableSwitch.on;
    self.feature.hotkeyVisible = self.hotkeySwitch.on;
    for (NSDictionary *v in self.detectedVars) {
        self.feature.settings[v[@"name"]] = v[@"value"] ?: @"";
    }
}

- (void)save {
    [self.view endEditing:YES];
    [self collectToFeature];
    [[SLScriptManager sharedInstance] saveFeature:self.feature];
    if (self.onSave) self.onSave();
    [self.navigationController popViewControllerAnimated:YES];
}
@end
