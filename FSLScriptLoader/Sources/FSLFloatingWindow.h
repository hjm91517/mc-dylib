#import <UIKit/UIKit.h>

/// 悬浮球窗口：点击打开/关闭主面板，按住拖动，位置记忆
@interface FSLFloatingWindow : UIWindow

- (instancetype)initWithKeyWindow:(UIWindow *)keyWindow;

@end
