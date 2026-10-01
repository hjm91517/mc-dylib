#import "FSLFloatingWindow.h"
#import "FSLCommon.h"
#import "FSLCore.h"

/// 透传根视图：只有落在悬浮按钮上的触摸才被本窗口消费
@interface FSLPassthroughView : UIView
@end

@implementation FSLPassthroughView
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *v in self.subviews) {
        if (!v.hidden && v.userInteractionEnabled && v.alpha > 0.01 &&
            CGRectContainsPoint(v.frame, point)) {
            return YES;
        }
    }
    return NO;
}
@end

@interface FSLPassthroughViewController : UIViewController
@end

@implementation FSLPassthroughViewController
- (void)loadView {
    self.view = [[FSLPassthroughView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}
@end

@interface FSLFloatingWindow ()
@property (nonatomic, strong) UIButton *floatButton;
@end

@implementation FSLFloatingWindow

- (instancetype)initWithKeyWindow:(UIWindow *)keyWindow {
    CGRect bounds = keyWindow.bounds.size.width > 0 ? keyWindow.bounds : UIScreen.mainScreen.bounds;
    self = nil;
    if (@available(iOS 13.0, *)) {
        if (keyWindow.windowScene) {
            self = [super initWithWindowScene:keyWindow.windowScene];
        }
    }
    if (!self) self = [super initWithFrame:bounds];
    if (!self) return nil;

    self.frame = bounds;
    self.windowLevel = UIWindowLevelStatusBar + 1;
    self.backgroundColor = UIColor.clearColor;
    self.rootViewController = [FSLPassthroughViewController new];
    self.hidden = NO;

    [self setupButton];
    return self;
}

- (void)setupButton {
    CGFloat size = 52.0;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, size, size);
    btn.layer.cornerRadius = size / 2.0;
    btn.clipsToBounds = YES;
    btn.layer.borderWidth = 1.5;
    btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.7].CGColor;
    btn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    [btn setImage:[FSLLoadFloatingIcon() imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
         forState:UIControlStateNormal];
    btn.imageView.contentMode = UIViewContentModeScaleAspectFill;
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    btn.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    btn.imageEdgeInsets = UIEdgeInsetsMake(3, 3, 3, 3);

    // 恢复上次位置
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    CGFloat x = [ud objectForKey:@"FSL.FloatX"] ? [ud doubleForKey:@"FSL.FloatX"] : self.bounds.size.width - 40;
    CGFloat y = [ud objectForKey:@"FSL.FloatY"] ? [ud doubleForKey:@"FSL.FloatY"] : self.bounds.size.height * 0.35;
    btn.center = CGPointMake(x, y);

    [btn addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [btn addGestureRecognizer:pan];

    [self.rootViewController.view addSubview:btn];
    self.floatButton = btn;
}

- (void)handleTap {
    [[FSLCore shared] toggleMenu];
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint loc = [g locationInView:self.rootViewController.view];
    self.floatButton.center = loc;
    if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        CGRect b = self.rootViewController.view.bounds;
        CGPoint c = self.floatButton.center;
        c.x = MAX(30, MIN(b.size.width - 30, c.x));
        c.y = MAX(50, MIN(b.size.height - 50, c.y));
        [UIView animateWithDuration:0.2 animations:^{
            self.floatButton.center = c;
        }];
        [NSUserDefaults.standardUserDefaults setDouble:c.x forKey:@"FSL.FloatX"];
        [NSUserDefaults.standardUserDefaults setDouble:c.y forKey:@"FSL.FloatY"];
    }
}

@end
