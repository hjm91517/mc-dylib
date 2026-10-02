#import "SLFloatWindow.h"
#import "SLMainTabVC.h"
#import <UIKit/UIKit.h>

@interface SLFloatWindow () <UIAdaptivePresentationControllerDelegate>
@property (nonatomic, strong) UIWindow *floatWindow;
@property (nonatomic, strong) UIImageView *iconView;
@end

@implementation SLFloatWindow

+ (instancetype)sharedInstance {
    static SLFloatWindow *i; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[SLFloatWindow alloc] init]; });
    return i;
}

- (void)show {
    if (self.floatWindow) return;

    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat size = 56;
    self.floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, screen.size.height * 0.18, size, size)];
    // 保持比应用界面更高的层级，便于始终在最上层显示
    self.floatWindow.windowLevel = UIWindowLevelStatusBar + 1;
    self.floatWindow.backgroundColor = [UIColor clearColor];
    self.floatWindow.rootViewController = [UIViewController new];
    // 使用 makeKeyAndVisible 更可靠地展示 window
    [self.floatWindow makeKeyAndVisible];

    // 阴影放在 window 层（iconView 因 masksToBounds 无法显示阴影）
    self.floatWindow.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatWindow.layer.shadowOpacity = 0.35;
    self.floatWindow.layer.shadowOffset = CGSizeMake(0, 2);
    self.floatWindow.layer.shadowRadius = 4;

    self.iconView = [[UIImageView alloc] initWithFrame:self.floatWindow.bounds];
    self.iconView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconView.userInteractionEnabled = YES;
    self.iconView.layer.cornerRadius = size / 2.0;
    self.iconView.layer.masksToBounds = YES;
    self.iconView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];

    // 图标路径：优先 mainBundle（IPA 注入时把 icon.png 放到 App 目录下）
    NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"icon" ofType:@"png"];
    if (!iconPath) {
        iconPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"icon.png"];
    }
    UIImage *icon = iconPath ? [UIImage imageWithContentsOfFile:iconPath] : nil;
    if (icon) {
        self.iconView.image = icon;
    } else {
        // 无图标时绘制一个默认闪电字符，避免悬浮球隐形
        UILabel *placeholder = [[UILabel alloc] initWithFrame:self.iconView.bounds];
        placeholder.text = @"⚡";
        placeholder.font = [UIFont systemFontOfSize:26];
        placeholder.textAlignment = NSTextAlignmentCenter;
        placeholder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.iconView addSubview:placeholder];
    }

    [self.floatWindow.rootViewController.view addSubview:self.iconView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(iconTapped)];
    [self.iconView addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(iconPanned:)];
    [self.iconView addGestureRecognizer:pan];
}

// 获取当前应用的最顶层可用于 present 的 view controller（兼容 iOS 13 scene）
- (UIViewController *)topMostController {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if (s.activationState != UISceneActivationStateForegroundActive) continue;
            if (![s isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)s;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
            if (keyWindow) break;
        }
    } else {
        keyWindow = UIApplication.sharedApplication.keyWindow;
    }
    if (!keyWindow) {
        keyWindow = UIApplication.sharedApplication.delegate.window ?: UIApplication.sharedApplication.windows.firstObject;
    }
    UIViewController *root = keyWindow.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    return root;
}

- (void)iconTapped {
    // 先从应用主窗口拿 presenter，排除悬浮窗自身的 window
    UIViewController *presenter = [self topMostController];
    if (!presenter || presenter == self.floatWindow.rootViewController) {
        for (UIWindow *w in UIApplication.sharedApplication.windows.reverseObjectEnumerator) {
            if (w == self.floatWindow) continue;
            if (w.rootViewController) {
                presenter = w.rootViewController;
                break;
            }
        }
    }
    if (!presenter) return;
    if (presenter.presentedViewController) return;

    SLMainTabVC *tab = [[SLMainTabVC alloc] init];
    // iPhone 上使用全屏以避免样式差异；iPad 会自动使用 form sheet
    tab.modalPresentationStyle = UIModalPresentationFullScreen;
    if (tab.presentationController) tab.presentationController.delegate = self;

    // 不再直接隐藏悬浮窗（部分系统下隐藏后无法恢复），改为从应用窗口展示主面板
    [presenter presentViewController:tab animated:YES completion:nil];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    // 用户通过交互或系统关闭时确保悬浮窗仍可见
    self.floatWindow.hidden = NO;
}

- (void)iconPanned:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:self.floatWindow.rootViewController.view];
    CGPoint c = self.floatWindow.center;
    c.x += t.x; c.y += t.y;
    // 限制在屏幕范围内
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat half = self.floatWindow.bounds.size.width / 2.0;
    c.x = MAX(half, MIN(screen.size.width - half, c.x));
    c.y = MAX(half, MIN(screen.size.height - half, c.y));
    self.floatWindow.center = c;
    [pan setTranslation:CGPointZero inView:self.floatWindow.rootViewController.view];
}
@end
