#import "SLHotkeyManager.h"
#import "SLScriptManager.h"
#import "SLScriptEngine.h"
#import "SLModel.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 快捷键悬浮按钮：为每个「启用 + 显示快捷键」的功能在屏幕右侧生成一个圆形快捷按钮，
// 点击立即运行对应脚本。按钮列可整体拖到任意位置，不与主猫咪悬浮球重叠。
@interface SLHotkeyManager ()
@property (nonatomic, strong) UIWindow *hotkeyWindow;
@property (nonatomic, strong) NSMutableArray<UIButton *> *buttons;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIButton *> *buttonByFeature;
@property (nonatomic, assign) BOOL windowBuilt;
@end

@implementation SLHotkeyManager

+ (instancetype)sharedInstance {
    static SLHotkeyManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLHotkeyManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _buttons = [NSMutableArray array];
        _buttonByFeature = [NSMutableDictionary dictionary];
    }
    return self;
}

static const CGFloat kBtnSize = 46;

- (void)rebuildAll {
    // 主线程执行（UI 操作）
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self rebuildAll];
        });
        return;
    }

    NSArray *features = [[SLScriptManager sharedInstance] loadAllFeatures];
    NSArray *keep = [features filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"enabled == YES AND hotkeyVisible == YES"]];

    // 1. 移除已关闭 / 已删除的按钮
    NSMutableSet *keepIds = [NSMutableSet set];
    for (SLFeature *f in keep) [keepIds addObject:f.featureId];
    for (NSString *fid in [self.buttonByFeature allKeys]) {
        if (![keepIds containsObject:fid]) {
            UIButton *b = self.buttonByFeature[fid];
            [b removeFromSuperview];
            [self.buttonByFeature removeObjectForKey:fid];
            [self.buttons removeObject:b];
        }
    }

    // 2. 为新增 feature 创建按钮
    for (SLFeature *f in keep) {
        if (self.buttonByFeature[f.featureId]) continue;
        UIButton *b = [self makeButtonForFeature:f];
        self.buttonByFeature[f.featureId] = b;
        [self.buttons addObject:b];
    }

    if (self.buttons.count == 0) {
        self.hotkeyWindow.hidden = YES;
        return;
    }

    // 3. 窗口 + 布局
    [self ensureWindow];
    [self layoutButtons];
    self.hotkeyWindow.hidden = NO;
}

- (void)removeHotkeyForFeatureId:(NSString *)fid {
    if (!fid) return;
    UIButton *b = self.buttonByFeature[fid];
    if (b) {
        [b removeFromSuperview];
        [self.buttonByFeature removeObjectForKey:fid];
        [self.buttons removeObject:b];
    }
    if (self.buttons.count == 0) self.hotkeyWindow.hidden = YES;
    else [self layoutButtons];
}

#pragma mark - 构建

- (UIButton *)makeButtonForFeature:(SLFeature *)f {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(0, 0, kBtnSize, kBtnSize);
    b.layer.cornerRadius = kBtnSize / 2.0;
    b.layer.borderWidth = 1.2;
    b.layer.borderColor = [UIColor colorWithRed:0.30 green:0.62 blue:1.00 alpha:0.55].CGColor;
    b.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.13 alpha:0.94];
    b.layer.shadowColor = [UIColor blackColor].CGColor;
    b.layer.shadowOpacity = 0.35;
    b.layer.shadowOffset = CGSizeMake(0, 2);
    b.layer.shadowRadius = 4;

    // 短标题：中文取前 2 字，英文取首字母大写
    NSString *title = f.name.length > 0 ? f.name : @"?";
    NSString *shortTitle = title;
    unichar first = [title characterAtIndex:0];
    BOOL isAscii = (first >= 0x21 && first <= 0x7E);
    if (isAscii) {
        shortTitle = [[title substringToIndex:1] uppercaseString];
    } else {
        shortTitle = title.length >= 2 ? [title substringToIndex:2] : title;
    }
    [b setTitle:shortTitle forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.6;
    b.contentEdgeInsets = UIEdgeInsetsMake(0, 2, 0, 2);

    // 类型小色点（JS 蓝 / PY 绿）
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(kBtnSize - 12, kBtnSize - 12, 8, 8)];
    dot.layer.cornerRadius = 4;
    dot.backgroundColor = [f.scriptType isEqualToString:@"py"]
        ? [UIColor colorWithRed:0.35 green:0.80 blue:0.45 alpha:1.0]
        : [UIColor colorWithRed:0.30 green:0.62 blue:1.00 alpha:1.0];
    dot.layer.borderWidth = 1;
    dot.layer.borderColor = [UIColor blackColor].CGColor;
    dot.userInteractionEnabled = NO;
    [b addSubview:dot];

    // 点击运行
    [b addTarget:self action:@selector(hotkeyTapped:) forControlEvents:UIControlEventTouchUpInside];
    // 用关联对象携带 feature
    objc_setAssociatedObject(b, "feature", f, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 拖拽
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(buttonPanned:)];
    [b addGestureRecognizer:pan];
    return b;
}

- (void)hotkeyTapped:(UIButton *)btn {
    SLFeature *f = objc_getAssociatedObject(btn, "feature");
    if (!f) return;
    [UIView animateWithDuration:0.12 animations:^{
        btn.transform = CGAffineTransformMakeScale(0.86, 0.86);
    } completion:^(BOOL done) {
        [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.5
              initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
            btn.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
    [SLScriptEngine runScript:f.scriptContent type:f.scriptType
                    variables:f.settings featureName:f.name];
}

- (void)buttonPanned:(UIPanGestureRecognizer *)pan {
    UIButton *b = (UIButton *)pan.view;
    if (!self.hotkeyWindow) return;
    CGPoint t = [pan translationInView:self.hotkeyWindow.rootViewController.view];
    CGPoint c = b.center;
    c.x += t.x; c.y += t.y;
    CGRect screen = [UIScreen mainScreen].bounds;
    c.x = MAX(kBtnSize/2, MIN(screen.size.width - kBtnSize/2, c.x));
    c.y = MAX(kBtnSize/2, MIN(screen.size.height - kBtnSize/2, c.y));
    b.center = c;
    [pan setTranslation:CGPointZero inView:self.hotkeyWindow.rootViewController.view];
}

- (void)ensureWindow {
    if (self.windowBuilt && self.hotkeyWindow) return;
    self.hotkeyWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.hotkeyWindow.windowLevel = UIWindowLevelStatusBar - 1; // 低于主悬浮球
    self.hotkeyWindow.backgroundColor = [UIColor clearColor];
    self.hotkeyWindow.rootViewController = [UIViewController new];
    self.hotkeyWindow.userInteractionEnabled = YES;
    self.hotkeyWindow.hidden = YES;
    self.windowBuilt = YES;
}

- (void)layoutButtons {
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat gap = 12;
    CGFloat totalH = self.buttons.count * kBtnSize + (self.buttons.count - 1) * gap;
    CGFloat y = MAX(80, (screen.size.height - totalH) / 2.0);
    for (NSUInteger i = 0; i < self.buttons.count; i++) {
        UIButton *b = self.buttons[i];
        b.center = CGPointMake(screen.size.width - kBtnSize/2.0 - 8, y + i * (kBtnSize + gap));
    }
}

@end
