#import "FSLCore.h"
#import "FSLCommon.h"
#import "FSLFloatingWindow.h"
#import "FSLHotkeyWindow.h"
#import "FSLMenuViewController.h"

@interface FSLCore ()
@property (nonatomic, strong) FSLFloatingWindow *floatingWindow;
@property (nonatomic, strong) FSLHotkeyWindow *hotkeyWindow;
@property (nonatomic, strong) UIWindow *menuWindow;
@property (nonatomic, weak) UIWindow *previousKeyWindow;
@property (nonatomic, assign) NSInteger setupRetries;
@end

@implementation FSLCore

+ (instancetype)shared {
    static FSLCore *s = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [FSLCore new]; });
    return s;
}

- (void)setup {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatingWindow) return;
        UIWindow *kw = FSLGetKeyWindow();
        if (!kw && self.setupRetries < 15) {
            // App 尚未创建窗口，稍后重试
            self.setupRetries++;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self setup];
            });
            return;
        }
        self.floatingWindow = [[FSLFloatingWindow alloc] initWithKeyWindow:kw];
        self.hotkeyWindow = [[FSLHotkeyWindow alloc] initWithKeyWindow:kw];
        NSLog(@"[FSL] 悬浮窗已加载");
    });
}

#pragma mark - 主面板

- (void)toggleMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.menuWindow) {
            [self dismissMenu];
        } else {
            [self showMenu];
        }
    });
}

- (void)showMenu {
    UIWindow *keyWin = FSLGetKeyWindow();
    if (!keyWin) return;
    self.previousKeyWindow = keyWin;

    CGRect b = keyWin.bounds;
    if (CGRectIsEmpty(b)) b = UIScreen.mainScreen.bounds;
    CGFloat w = MIN(b.size.width - 40, 420);
    CGFloat h = MIN(b.size.height - 180, 560);

    UIWindow *win = nil;
    if (@available(iOS 13.0, *)) {
        if (keyWin.windowScene) win = [[UIWindow alloc] initWithWindowScene:keyWin.windowScene];
    }
    if (!win) win = [[UIWindow alloc] initWithFrame:b];
    win.frame = CGRectMake((b.size.width - w) / 2, (b.size.height - h) / 2, w, h);
    win.windowLevel = UIWindowLevelAlert + 2;
    win.backgroundColor = UIColor.clearColor;
    win.layer.cornerRadius = 16;
    win.clipsToBounds = YES;

    FSLMenuViewController *menu = [FSLMenuViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:menu];
    nav.view.layer.cornerRadius = 16;
    nav.view.clipsToBounds = YES;
    win.rootViewController = nav;

    win.alpha = 0;
    win.transform = CGAffineTransformMakeScale(0.85, 0.85);
    win.hidden = NO;
    [win makeKeyWindow];
    self.menuWindow = win;

    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        win.alpha = 1;
        win.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismissMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = self.menuWindow;
        if (!win) return;
        [UIView animateWithDuration:0.18 animations:^{
            win.alpha = 0;
            win.transform = CGAffineTransformMakeScale(0.9, 0.9);
        } completion:^(BOOL finished) {
            win.hidden = YES;
            self.menuWindow = nil;
            [self.previousKeyWindow makeKeyWindow];
        }];
    });
}

@end
