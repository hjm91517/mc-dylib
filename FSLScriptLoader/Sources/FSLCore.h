#import <UIKit/UIKit.h>

/// 核心管理器：创建悬浮球窗口、快捷键窗口、主面板窗口
@interface FSLCore : NSObject

+ (instancetype)shared;

/// dylib 加载后调用，创建悬浮入口
- (void)setup;

/// 打开 / 关闭主面板
- (void)toggleMenu;
- (void)dismissMenu;

@end
