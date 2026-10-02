#import <UIKit/UIKit.h>

// MoonPack 风格深色主题统一色板
static inline UIColor *SLColorBG(void)     { return [UIColor colorWithRed:0.055 green:0.067 blue:0.086 alpha:1.0]; } // #0E1116 页面底
static inline UIColor *SLColorSidebar(void) { return [UIColor colorWithRed:0.09 green:0.11 blue:0.14 alpha:1.0]; }   // #171C24 侧边栏
static inline UIColor *SLColorCard(void)    { return [UIColor colorWithRed:0.12 green:0.14 blue:0.18 alpha:1.0]; }   // #1F242E 卡片
static inline UIColor *SLColorCardAlt(void) { return [UIColor colorWithRed:0.17 green:0.20 blue:0.25 alpha:1.0]; }   // #2B333F 卡片高亮
static inline UIColor *SLColorAccent(void)  { return [UIColor colorWithRed:0.30 green:0.62 blue:1.00 alpha:1.0]; }   // #4D9EFF 强调蓝
static inline UIColor *SLColorAccentDim(void) { return [UIColor colorWithRed:0.30 green:0.62 blue:1.00 alpha:0.18]; }
static inline UIColor *SLColorText(void)    { return [UIColor colorWithWhite:0.93 alpha:1.0]; }
static inline UIColor *SLColorText2(void)   { return [UIColor colorWithWhite:0.62 alpha:1.0]; }
static inline UIColor *SLColorText3(void)   { return [UIColor colorWithWhite:0.42 alpha:1.0]; }
static inline UIColor *SLColorStroke(void)  { return [UIColor colorWithWhite:1.0 alpha:0.08]; }
static inline UIColor *SLColorOK(void)      { return [UIColor colorWithRed:0.25 green:0.80 blue:0.45 alpha:1.0]; }
static inline UIColor *SLColorFail(void)    { return [UIColor colorWithRed:1.00 green:0.32 blue:0.32 alpha:1.0]; }
static inline UIColor *SLColorNever(void)   { return [UIColor colorWithWhite:0.45 alpha:1.0]; }

static inline UIView *SLMakeCard(void) {
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = SLColorCard();
    v.layer.cornerRadius = 14;
    v.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    v.layer.borderColor = SLColorStroke().CGColor;
    return v;
}

// 统一提示弹窗（在可用的全屏 window 上 present）
static inline void SLPresentToast(NSString *title, NSString *message) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    UIWindow *target = nil;
    CGFloat best = 0;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if (s.activationState != UISceneActivationStateForegroundActive) continue;
            if (![s isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)s;
            for (UIWindow *w in ws.windows) {
                CGRect r = w.bounds;
                CGFloat area = r.size.width * r.size.height;
                if (area > best) { best = area; target = w; }
            }
        }
    }
    if (!target) target = UIApplication.sharedApplication.windows.firstObject;
    UIViewController *root = target.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    if (root) [root presentViewController:a animated:YES completion:nil];
}
