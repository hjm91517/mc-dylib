// Tweak.xm - Minecraft 网易云 WebView 播放器
// 悬浮球可拖动，窗口可拖动、可缩放，非交互区域触摸穿透

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

// ============================================================
// 穿透视图：只有当触摸点在某子视图上时才拦截
// ============================================================
@interface MCPassThroughView : UIView
@end

@implementation MCPassThroughView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *sub in self.subviews) {
        if (sub.hidden || sub.alpha < 0.01) continue;
        CGPoint p = [sub convertPoint:point fromView:self];
        if ([sub pointInside:p withEvent:event]) {
            return YES;
        }
    }
    return NO;
}

@end

// ============================================================
// 全局变量
// ============================================================
static UIWindow *gWin = nil;
static MCPassThroughView *gRootView = nil;
static UIButton *gBall = nil;
static UIView *gPanel = nil;
static UIView *gTitleBar = nil;
static WKWebView *gWebView = nil;
static UIView *gResizeHandle = nil;
static BOOL gUILoaded = NO;

// ============================================================
// 手势与事件处理
// ============================================================
@interface MCHandler : NSObject
@end

@implementation MCHandler

- (void)dragBall:(UIPanGestureRecognizer *)g {
    UIView *ball = g.view;
    CGPoint t = [g translationInView:ball.superview];
    CGPoint c = ball.center;
    c.x += t.x;
    c.y += t.y;
    CGRect bounds = ball.superview.bounds;
    CGFloat r = ball.frame.size.width / 2;
    c.x = MAX(r, MIN(bounds.size.width - r, c.x));
    c.y = MAX(r + 40, MIN(bounds.size.height - r - 40, c.y));
    ball.center = c;
    [g setTranslation:CGPointZero inView:ball.superview];

    if (g.state == UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGPoint(ball.center) forKey:@"MCBallCenter"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)dragWindow:(UIPanGestureRecognizer *)g {
    UIView *bar = g.view;
    UIView *win = bar.superview;
    CGPoint t = [g translationInView:win.superview];
    CGPoint c = win.center;
    c.x += t.x;
    c.y += t.y;
    CGRect b = win.superview.bounds;
    CGFloat w2 = win.frame.size.width / 2;
    CGFloat h2 = win.frame.size.height / 2;
    c.x = MAX(-w2 + 80, MIN(b.size.width + w2 - 80, c.x));
    c.y = MAX(h2 - 40, MIN(b.size.height - h2 + 40, c.y));
    win.center = c;
    [g setTranslation:CGPointZero inView:win.superview];

    if (g.state == UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGRect(win.frame) forKey:@"MCWindowFrame"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)resizeWindow:(UIPanGestureRecognizer *)g {
    UIView *handle = g.view;
    UIView *win = handle.superview;
    CGPoint t = [g translationInView:win];

    CGFloat newW = MAX(280, win.frame.size.width + t.x);
    CGFloat newH = MAX(360, win.frame.size.height + t.y);

    CGFloat maxW = win.superview.bounds.size.width - win.frame.origin.x;
    CGFloat maxH = win.superview.bounds.size.height - win.frame.origin.y;
    if (newW > maxW) newW = maxW;
    if (newH > maxH) newH = maxH;

    win.frame = CGRectMake(win.frame.origin.x, win.frame.origin.y, newW, newH);
    [self layoutPanelSubviews:win];
    [g setTranslation:CGPointZero inView:win];

    if (g.state == UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGRect(win.frame) forKey:@"MCWindowFrame"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)layoutPanelSubviews:(UIView *)win {
    CGFloat w = win.frame.size.width;
    CGFloat h = win.frame.size.height;
    UIView *bar = [win viewWithTag:1001];
    if (bar) bar.frame = CGRectMake(0, 0, w, 44);
    WKWebView *wv = (WKWebView *)[win viewWithTag:1002];
    if (wv) wv.frame = CGRectMake(0, 44, w, h - 44);
    UIView *rh = [win viewWithTag:1003];
    if (rh) rh.frame = CGRectMake(w - 36, h - 36, 36, 36);
    UIView *cb = [win viewWithTag:1004];
    if (cb) cb.frame = CGRectMake(w - 48, 6, 32, 32);
}

- (void)togglePanel {
    if (gPanel.hidden) {
        gPanel.hidden = NO;
        gPanel.alpha = 0;
        gPanel.transform = CGAffineTransformMakeScale(0.9, 0.9);
        [UIView animateWithDuration:0.4 delay:0
            usingSpringWithDamping:0.8 initialSpringVelocity:0.5
            options:UIViewAnimationOptionCurveEaseOut
            animations:^{
                gPanel.alpha = 1;
                gPanel.transform = CGAffineTransformIdentity;
            } completion:nil];
    } else {
        [UIView animateWithDuration:0.28 animations:^{
            gPanel.alpha = 0;
            gPanel.transform = CGAffineTransformMakeScale(0.9, 0.9);
        } completion:^(BOOL f) {
            gPanel.hidden = YES;
            gPanel.transform = CGAffineTransformIdentity;
        }];
    }
}

- (void)closePanel {
    [UIView animateWithDuration:0.28 animations:^{
        gPanel.alpha = 0;
        gPanel.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL f) {
        gPanel.hidden = YES;
        gPanel.transform = CGAffineTransformIdentity;
    }];
}

@end

static MCHandler *gHandler = nil;

// ============================================================
// 手绘图标
// ============================================================
static UIImage *makeBallIcon(CGFloat s) {
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGContextSetStrokeColorWithColor(c, [UIColor whiteColor].CGColor);
        CGContextSetFillColorWithColor(c, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(c, 2.4);
        CGContextSetLineCap(c, kCGLineCapRound);
        CGFloat w = s, h = s;
        CGContextMoveToPoint(c, w * 0.62, h * 0.22);
        CGContextAddLineToPoint(c, w * 0.62, h * 0.70);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, w * 0.62, h * 0.22);
        CGContextAddLineToPoint(c, w * 0.82, h * 0.30);
        CGContextAddLineToPoint(c, w * 0.82, h * 0.44);
        CGContextAddLineToPoint(c, w * 0.62, h * 0.36);
        CGContextClosePath(c);
        CGContextFillPath(c);
        CGContextFillEllipseInRect(c, CGRectMake(w * 0.30, h * 0.62, w * 0.32, w * 0.26));
    }];
}

static UIImage *makeCloseIcon(CGFloat s, UIColor *col) {
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGContextSetStrokeColorWithColor(c, col.CGColor);
        CGContextSetLineWidth(c, 2.2);
        CGContextSetLineCap(c, kCGLineCapRound);
        CGContextMoveToPoint(c, s * 0.28, s * 0.28);
        CGContextAddLineToPoint(c, s * 0.72, s * 0.72);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, s * 0.72, s * 0.28);
        CGContextAddLineToPoint(c, s * 0.28, s * 0.72);
        CGContextStrokePath(c);
    }];
}

static UIImage *makeResizeIcon(CGFloat s, UIColor *col) {
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGContextSetStrokeColorWithColor(c, col.CGColor);
        CGContextSetLineWidth(c, 1.8);
        CGContextSetLineCap(c, kCGLineCapRound);
        CGContextMoveToPoint(c, s * 0.40, s * 0.80);
        CGContextAddLineToPoint(c, s * 0.80, s * 0.40);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, s * 0.55, s * 0.85);
        CGContextAddLineToPoint(c, s * 0.85, s * 0.55);
        CGContextStrokePath(c);
    }];
}

// ============================================================
// UI 构建
// ============================================================
static void buildUI(void) {
    if (gUILoaded) return;
    gUILoaded = YES;
    gHandler = [[MCHandler alloc] init];

    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat sw = screen.size.width;
    CGFloat sh = screen.size.height;

    gWin = [[UIWindow alloc] initWithFrame:screen];
    gWin.windowLevel = UIWindowLevelAlert + 100;
    gWin.backgroundColor = [UIColor clearColor];
    // 关键：不要用 makeKeyAndVisible，避免抢走游戏的 key window
    gWin.hidden = NO;

    // 关键：根视图使用穿透视图，非交互区域全部透传
    gRootView = [[MCPassThroughView alloc] initWithFrame:screen];
    gRootView.backgroundColor = [UIColor clearColor];
    gRootView.userInteractionEnabled = YES;
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view = gRootView;
    gWin.rootViewController = vc;

    // ===== 悬浮球 =====
    CGFloat bs = 56;
    CGPoint ballCenter = CGPointMake(sw - bs / 2 - 16, sh * 0.4);
    NSString *savedCenter = [[NSUserDefaults standardUserDefaults] stringForKey:@"MCBallCenter"];
    if (savedCenter) ballCenter = CGPointFromString(savedCenter);

    gBall = [UIButton buttonWithType:UIButtonTypeCustom];
    gBall.frame = CGRectMake(ballCenter.x - bs / 2, ballCenter.y - bs / 2, bs, bs);
    gBall.backgroundColor = [UIColor colorWithRed:0.49 green:0.36 blue:1.0 alpha:0.95];
    gBall.layer.cornerRadius = bs / 2;
    gBall.layer.shadowColor = [UIColor blackColor].CGColor;
    gBall.layer.shadowOpacity = 0.5;
    gBall.layer.shadowRadius = 12;
    gBall.layer.shadowOffset = CGSizeMake(0, 4);
    [gBall setImage:makeBallIcon(30) forState:UIControlStateNormal];
    [gBall addTarget:gHandler action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [gRootView addSubview:gBall];

    UIPanGestureRecognizer *ballPan = [[UIPanGestureRecognizer alloc] initWithTarget:gHandler action:@selector(dragBall:)];
    [gBall addGestureRecognizer:ballPan];

    // ===== 面板 =====
    CGFloat pw = MIN(sw * 0.85, 520);
    CGFloat ph = MIN(sh * 0.78, 720);
    CGRect panelFrame = CGRectMake((sw - pw) / 2, (sh - ph) / 2, pw, ph);
    NSString *savedFrame = [[NSUserDefaults standardUserDefaults] stringForKey:@"MCWindowFrame"];
    if (savedFrame) panelFrame = CGRectFromString(savedFrame);

    gPanel = [[UIView alloc] initWithFrame:panelFrame];
    gPanel.backgroundColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.09 alpha:0.98];
    gPanel.layer.cornerRadius = 16;
    gPanel.layer.masksToBounds = YES;
    gPanel.layer.shadowColor = [UIColor blackColor].CGColor;
    gPanel.layer.shadowOpacity = 0.7;
    gPanel.layer.shadowRadius = 30;
    gPanel.layer.shadowOffset = CGSizeMake(0, 12);
    gPanel.hidden = YES;
    gPanel.alpha = 0;
    gPanel.tag = 1000;
    [gRootView addSubview:gPanel];

    // ===== 标题栏 =====
    gTitleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelFrame.size.width, 44)];
    gTitleBar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    gTitleBar.tag = 1001;
    [gPanel addSubview:gTitleBar];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, panelFrame.size.width - 80, 44)];
    title.text = @"网易云音乐";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [gTitleBar addSubview:title];

    UIPanGestureRecognizer *winPan = [[UIPanGestureRecognizer alloc] initWithTarget:gHandler action:@selector(dragWindow:)];
    [gTitleBar addGestureRecognizer:winPan];

    // ===== 关闭按钮 =====
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(panelFrame.size.width - 48, 6, 32, 32);
    closeBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    closeBtn.layer.cornerRadius = 16;
    closeBtn.tag = 1004;
    [closeBtn setImage:makeCloseIcon(16, [UIColor colorWithWhite:0.7 alpha:1]) forState:UIControlStateNormal];
    [closeBtn addTarget:gHandler action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [gTitleBar addSubview:closeBtn];

    // ===== WKWebView =====
    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.allowsInlineMediaPlayback = YES;
    if (@available(iOS 10.0, *)) {
        cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }

    gWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 44, panelFrame.size.width, panelFrame.size.height - 44) configuration:cfg];
    gWebView.backgroundColor = [UIColor blackColor];
    gWebView.opaque = YES;
    gWebView.tag = 1002;
    gWebView.customUserAgent = @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";
    [gPanel addSubview:gWebView];

    NSURL *url = [NSURL URLWithString:@"https://music.163.com"];
    [gWebView loadRequest:[NSURLRequest requestWithURL:url]];

    // ===== 缩放手柄 =====
    gResizeHandle = [[UIView alloc] initWithFrame:CGRectMake(panelFrame.size.width - 36, panelFrame.size.height - 36, 36, 36)];
    gResizeHandle.backgroundColor = [UIColor clearColor];
    gResizeHandle.tag = 1003;
    UIImageView *ri = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 36, 36)];
    ri.image = makeResizeIcon(36, [UIColor colorWithWhite:0.55 alpha:0.9]);
    [gResizeHandle addSubview:ri];
    [gPanel addSubview:gResizeHandle];

    UIPanGestureRecognizer *rsPan = [[UIPanGestureRecognizer alloc] initWithTarget:gHandler action:@selector(resizeWindow:)];
    [gResizeHandle addGestureRecognizer:rsPan];

    // ===== 音频会话 =====
    NSError *err = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                           error:&err];
    [[AVAudioSession sharedInstance] setActive:YES error:&err];

    NSLog(@"[MCPlugin] UI 就绪");
}

// ============================================================
// 入口
// ============================================================
%ctor {
    NSLog(@"[MCPlugin] 加载");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        buildUI();
    });
}
