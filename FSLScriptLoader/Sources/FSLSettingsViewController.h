#import <UIKit/UIKit.h>

@class FSLFunction;

/// 功能设置页：总开关、屏幕快捷键开关、自动识别的脚本参数、删除功能
@interface FSLSettingsViewController : UITableViewController

- (instancetype)initWithFunction:(FSLFunction *)fn;

@end
