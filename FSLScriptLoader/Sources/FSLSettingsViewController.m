#import "FSLSettingsViewController.h"
#import "FSLFunction.h"
#import "FSLFunctionManager.h"
#import "FSLConfigParser.h"

@interface FSLSettingsViewController () <UITextFieldDelegate>
@property (nonatomic, strong) FSLFunction *fn;
@property (nonatomic, strong) NSArray<FSLConfigItem *> *configItems;
@end

@implementation FSLSettingsViewController

- (instancetype)initWithFunction:(FSLFunction *)fn {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _fn = fn;
        // 自动识别脚本里 @config 声明的可设置项
        _configItems = [FSLConfigParser parseSource:fn.source type:fn.type];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"设置 · %@", self.fn.name];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone
                                        target:self action:@selector(saveTapped)];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.view endEditing:YES];
    [[FSLFunctionManager shared] save];
    [NSNotificationCenter.defaultCenter postNotificationName:FSLFunctionsDidChangeNotification object:nil];
}

- (void)saveTapped {
    [self.view endEditing:YES];
    [[FSLFunctionManager shared] save];
    [NSNotificationCenter.defaultCenter postNotificationName:FSLFunctionsDidChangeNotification object:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - 开关回调

- (void)enabledChanged:(UISwitch *)sw {
    self.fn.enabled = sw.on;
    [[FSLFunctionManager shared] save];
    [NSNotificationCenter.defaultCenter postNotificationName:FSLFunctionsDidChangeNotification object:nil];
}

- (void)hotkeyChanged:(UISwitch *)sw {
    self.fn.hotkeyEnabled = sw.on;
    [[FSLFunctionManager shared] save];
    [NSNotificationCenter.defaultCenter postNotificationName:FSLFunctionsDidChangeNotification object:nil];
}

- (void)boolParamChanged:(UISwitch *)sw {
    FSLConfigItem *item = self.configItems[sw.tag];
    self.fn.configValues[item.key] = @(sw.on);
}

#pragma mark - 文本参数

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.tag < 0 || textField.tag >= (NSInteger)self.configItems.count) return;
    FSLConfigItem *item = self.configItems[textField.tag];
    NSString *text = textField.text ?: @"";
    if ([item.type isEqualToString:@"number"]) {
        self.fn.configValues[item.key] = @([text doubleValue]);
    } else {
        self.fn.configValues[item.key] = text;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"状态";
    if (section == 1) return self.configItems.count ? @"脚本参数（自动识别）" : nil;
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return @"在脚本中用注释声明参数即可在此处自动出现：\n"
               @"JS： //@config {\"key\":\"speed\",\"type\":\"number\",\"default\":5,\"label\":\"速度\"}\n"
               @"PY： #@config {\"key\":\"debug\",\"type\":\"bool\",\"default\":true}\n"
               @"type 支持 bool / number / text";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return self.configItems.count;
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.textLabel.textColor = UIColor.labelColor;

    if (indexPath.section == 0) {
        UISwitch *sw = [UISwitch new];
        if (indexPath.row == 0) {
            cell.textLabel.text = @"开启功能";
            sw.on = self.fn.enabled;
            [sw addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
        } else {
            cell.textLabel.text = @"屏幕快捷键";
            sw.on = self.fn.hotkeyEnabled;
            [sw addTarget:self action:@selector(hotkeyChanged:) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = sw;
    } else if (indexPath.section == 1) {
        FSLConfigItem *item = self.configItems[indexPath.row];
        cell.textLabel.text = item.label;
        id value = self.fn.configValues[item.key] ?: item.defaultValue;

        if ([item.type isEqualToString:@"bool"]) {
            UISwitch *sw = [UISwitch new];
            sw.on = [value boolValue];
            sw.tag = indexPath.row;
            [sw addTarget:self action:@selector(boolParamChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        } else {
            UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 140, 32)];
            tf.textAlignment = NSTextAlignmentRight;
            tf.font = [UIFont systemFontOfSize:15];
            tf.delegate = self;
            tf.tag = indexPath.row;
            tf.returnKeyType = UIReturnKeyDone;
            if ([item.type isEqualToString:@"number"]) {
                tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
                tf.text = [value respondsToSelector:@selector(stringValue)] ? [value stringValue] : [value description];
            } else {
                tf.text = [value description];
            }
            tf.placeholder = item.key;
            cell.accessoryView = tf;
        }
    } else {
        cell.textLabel.text = @"删除此功能";
        cell.textLabel.textColor = UIColor.systemRedColor;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 2) return;

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"删除功能"
                                                                message:[NSString stringWithFormat:@"确定删除「%@」吗？", self.fn.name]
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) wself = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[FSLFunctionManager shared] deleteFunction:wself.fn];
        [wself.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
