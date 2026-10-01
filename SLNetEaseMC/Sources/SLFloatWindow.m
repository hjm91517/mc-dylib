#import "SLFloatWindow.h"
#import "SLMainTabVC.h"

@interface SLFloatWindow ()
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
    self.floatWindow.windowLevel = UIWindowLevelStatusBar + 1;
    self.floatWindow.backgroundColor = [UIColor clearColor];
    self.floatWindow.rootViewController = [UIViewController new];
    self.floatWindow.hidden = NO;

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

- (void)iconTapped {
    if (self.floatWindow.rootViewController.presentedViewController) return;
    SLMainTabVC *tab = [[SLMainTabVC alloc] init];
    tab.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.floatWindow.rootViewController presentViewController:tab animated:YES completion:nil];
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
