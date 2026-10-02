#import "SLFloatWindow.h"
#import "SLMainTabVC.h"
#import <UIKit/UIKit.h>

@interface SLFloatWindow () <UIAdaptivePresentationControllerDelegate>
@property (nonatomic, strong) UIWindow *floatWindow;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, assign) BOOL panelOpen;
@end

@implementation SLFloatWindow

+ (instancetype)sharedInstance {
    static SLFloatWindow *i; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[SLFloatWindow alloc] init]; });
    return i;
}

- (void)show {
    if (self.floatWindow) {
        self.floatWindow.hidden = NO;
        return;
    }

    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat size = 56;
    self.floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, screen.size.height * 0.18, size, size)];
    // 保持比应用界面更高的层级，便于始终在最上层显示
    self.floatWindow.windowLevel = UIWindowLevelStatusBar + 1;
    self.floatWindow.backgroundColor = [UIColor clearColor];
    self.floatWindow.rootViewController = [UIViewController new];
    self.floatWindow.userInteractionEnabled = YES;
    [self.floatWindow makeKeyAndVisible];

    // 蓝色雷电气场光晕（iconView 因 masksToBounds 无法显示阴影，放在 window 层）
    self.floatWindow.layer.shadowColor = [UIColor colorWithRed:0.30 green:0.62 blue:1.00 alpha:1.0].CGColor;
    self.floatWindow.layer.shadowOpacity = 0.65;
    self.floatWindow.layer.shadowOffset = CGSizeMake(0, 0);
    self.floatWindow.layer.shadowRadius = 10;

    self.iconView = [[UIImageView alloc] initWithFrame:self.floatWindow.bounds];
    self.iconView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconView.userInteractionEnabled = YES;
    self.iconView.layer.cornerRadius = size / 2.0;
    self.iconView.layer.masksToBounds = YES;
    self.iconView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.72];
    self.iconView.layer.borderWidth = 1.5;
    self.iconView.layer.borderColor = [UIColor colorWithRed:0.30 green:0.62 blue:1.00 alpha:0.85].CGColor;

    // 猫咪图标：优先 mainBundle 的 icon.png（IPA 注入时放在 App 目录下）
    NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"icon" ofType:@"png"];
    if (!iconPath) {
        iconPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"icon.png"];
    }
    UIImage *icon = iconPath ? [UIImage imageWithContentsOfFile:iconPath] : nil;
    if (icon) {
        self.iconView.image = icon;
    } else {
        // 兜底：无图标时绘制默认闪电字符，避免悬浮球隐形
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

    // 入场弹性弹出
    self.floatWindow.transform = CGAffineTransformMakeScale(0.2, 0.2);
    self.floatWindow.alpha = 0;
    [UIView animateWithDuration:0.5 delay:0.15
         usingSpringWithDamping:0.55
          initialSpringVelocity:1.2
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.floatWindow.transform = CGAffineTransformIdentity;
        self.floatWindow.alpha = 1.0;
    } completion:nil];
}

#pragma mark - 展示 / 恢复悬浮球

- (void)hideAnimated {
    if (!self.floatWindow || self.floatWindow.hidden) return;
    [UIView animateWithDuration:0.2 animations:^{
        self.floatWindow.alpha = 0;
        self.floatWindow.transform = CGAffineTransformMakeScale(0.5, 0.5);
    } completion:^(BOOL done) {
        self.floatWindow.hidden = YES;
    }];
}

- (void)restoreAnimated {
    self.panelOpen = NO;
    if (!self.floatWindow) return;
    self.floatWindow.hidden = NO;
    self.floatWindow.alpha = 0;
    self.floatWindow.transform = CGAffineTransformMakeScale(0.6, 0.6);
    [UIView animateWithDuration:0.35 delay:0
         usingSpringWithDamping:0.6
          initialSpringVelocity:0.9
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.floatWindow.alpha = 1.0;
        self.floatWindow.transform = CGAffineTransformIdentity;
    } completion:nil];
}

// 获取应用最顶层可用于 present 的 view controller（兼容 iOS 13 scene，跳过小尺寸悬浮窗）
- (UIViewController *)topMostController {
    UIWindow *best = nil;
    CGFloat bestArea = 0;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if (s.activationState != UISceneActivationStateForegroundActive) continue;
            if (![s isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)s;
            for (UIWindow *w in ws.windows) {
                CGRect r = w.bounds;
                CGFloat area = r.size.width * r.size.height;
                if (area > bestArea) { bestArea = area; best = w; }
            }
        }
    } else {
        best = UIApplication.sharedApplication.delegate.window ?: UIApplication.sharedApplication.windows.firstObject;
    }
    if (!best) best = UIApplication.sharedApplication.windows.firstObject;
    UIViewController *root = best.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    return root;
}

- (void)iconTapped {
    if (self.panelOpen) return;

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

    // 按压反馈
    [UIView animateWithDuration:0.1 animations:^{
        self.iconView.transform = CGAffineTransformMakeScale(0.82, 0.82);
    } completion:^(BOOL done) {
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.5
              initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.iconView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    SLMainTabVC *tab = [[SLMainTabVC alloc] init];
    // 覆盖全屏 + 淡入，MoonPack 面板感；悬浮球随后隐藏，关闭时恢复
    tab.modalPresentationStyle = UIModalPresentationOverFullScreen;
    tab.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    if (tab.presentationController) tab.presentationController.delegate = self;

    // 先把应用主窗口设为 key，保证面板内键盘 / 弹窗正常
    UIWindow *mainWindow = presenter.view.window;
    if (mainWindow && mainWindow != self.floatWindow) {
        [mainWindow makeKeyWindow];
    }

    self.panelOpen = YES;
    [self hideAnimated];

    __weak typeof(self) weakSelf = self;
    [presenter presentViewController:tab animated:YES completion:^{
        // 若系统自动恢复了 key（部分系统行为），重新隐藏悬浮球
        if (weakSelf.panelOpen) {
            weakSelf.floatWindow.hidden = YES;
        }
    }];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    // 用户通过交互或系统关闭面板时恢复悬浮球
    [self restoreAnimated];
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

    // 拖拽中轻微缩放，模拟按住
    if (pan.state == UIGestureRecognizerStateBegan) {
        [UIView animateWithDuration:0.18 animations:^{
            self.floatWindow.transform = CGAffineTransformMakeScale(1.12, 1.12);
        }];
    }

    // 手势结束：弹簧吸附到最近的屏幕左右边缘
    if (pan.state == UIGestureRecognizerStateEnded ||
        pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat targetX = (c.x < screen.size.width / 2.0) ? half : (screen.size.width - half);
        CGFloat velocityX = [pan velocityInView:self.floatWindow.rootViewController.view].x;
        // 快速甩动时按速度方向吸附
        if (fabs(velocityX) > 600) {
            targetX = (velocityX > 0) ? (screen.size.width - half) : half;
        }
        [UIView animateWithDuration:0.4 delay:0
             usingSpringWithDamping:0.65
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.floatWindow.center = CGPointMake(targetX, c.y);
            self.floatWindow.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}
@end
