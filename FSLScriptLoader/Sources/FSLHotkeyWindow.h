#import <UIKit/UIKit.h>

/// 快捷键窗口：为每个开启"屏幕快捷键"的功能生成独立悬浮按钮
/// 点击 = 运行 / 停止，长按拖动到屏幕任意位置
@interface FSLHotkeyWindow : UIWindow

- (instancetype)initWithKeyWindow:(UIWindow *)keyWindow;
- (void)reloadButtons;

@end
