#import <UIKit/UIKit.h>

/// 获取 App 当前关键窗口（兼容 Scene）
UIWindow *FSLGetKeyWindow(void);

/// 主线程弹窗提示
void FSLShowAlert(NSString *title, NSString *message);

/// 加载悬浮窗图标：优先 dylib 同级 FSLResources.bundle/icon.png，找不到则绘制默认图标
UIImage *FSLLoadFloatingIcon(void);
