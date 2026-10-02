#import "SLMainTabVC.h"
#import "SLFeatureListVC.h"
#import "SLLogVC.h"
#import "SLAIAssistantVC.h"
#import "SLGlobalSettingVC.h"
#import "SLFloatWindow.h"
#import "SLTheme.h"

// MoonPack 风格主面板：左侧导航栏 + 右侧内容区，深色主题
@interface SLMainTabVC ()
@property (nonatomic, strong) UIView *sidebar;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) NSMutableArray<UIViewController *> *childNavs;
@property (nonatomic, strong) NSMutableArray<UIButton *> *sideButtons;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation SLMainTabVC

static const CGFloat kSidebarWidth = 92;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = SLColorBG();
    self.currentIndex = -1;

    [self buildSidebar];
    [self buildContent];

    // 初始选中「主页」
    [self selectIndex:0 animated:NO];

    // 关闭按钮（侧边栏底部）
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(10, self.view.bounds.size.height - 66, kSidebarWidth - 20, 44);
    closeBtn.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [closeBtn setTitle:@"✕  关闭" forState:UIControlStateNormal];
    [closeBtn setTitleColor:SLColorText2() forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    closeBtn.layer.cornerRadius = 10;
    closeBtn.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    closeBtn.layer.borderColor = SLColorStroke().CGColor;
    [closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.sidebar addSubview:closeBtn];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // 面板入场：轻微缩放 + 淡入
    self.view.alpha = 0.6;
    self.view.transform = CGAffineTransformMakeScale(0.96, 0.96);
    [UIView animateWithDuration:0.35
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.view.alpha = 1.0;
        self.view.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - UI 构建

- (void)buildSidebar {
    CGFloat W = kSidebarWidth;
    self.sidebar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, self.view.bounds.size.height)];
    self.sidebar.backgroundColor = SLColorSidebar();
    self.sidebar.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.sidebar];

    // 顶部 Logo 区
    UIView *logo = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 100)];
    logo.backgroundColor = [UIColor clearColor];
    [self.sidebar addSubview:logo];

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(W/2 - 20, 26, 40, 40)];
    icon.contentMode = UIViewContentModeScaleAspectFill;
    icon.layer.cornerRadius = 20;
    icon.layer.masksToBounds = YES;
    icon.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    icon.layer.borderColor = SLColorStroke().CGColor;
    NSString *p = [[NSBundle mainBundle] pathForResource:@"icon" ofType:@"png"];
    icon.image = [UIImage imageWithContentsOfFile:p] ?: [UIImage systemImageNamed:@"bolt.fill"];
    [logo addSubview:icon];

    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(0, 72, W, 14)];
    name.text = @"hjpythonzd";
    name.font = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
    name.textColor = SLColorText3();
    name.textAlignment = NSTextAlignmentCenter;
    [logo addSubview:name];

    // 导航项
    NSArray *items = @[
        @[@"主页", @"square.grid.2x2.fill"],
        @[@"日志", @"doc.text.fill"],
        @[@"AI",   @"bubble.left.and.bubble.right.fill"],
        @[@"设置", @"gearshape.fill"],
        @[@"帮助", @"questionmark.circle.fill"],
    ];
    self.sideButtons = [NSMutableArray array];
    CGFloat y = 110;
    CGFloat itemH = 54;
    for (NSUInteger i = 0; i < items.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(8, y + i * (itemH + 8), W - 16, itemH);
        b.tag = (NSInteger)i;
        b.layer.cornerRadius = 12;

        // 选中指示条（左侧 3pt 竖条，MoonPack 风格）
        UIView *ind = [[UIView alloc] initWithFrame:CGRectMake(0, 12, 3, itemH - 24)];
        ind.backgroundColor = SLColorAccent();
        ind.layer.cornerRadius = 1.5;
        ind.hidden = YES;
        ind.tag = 200;
        ind.userInteractionEnabled = NO;
        [b addSubview:ind];

        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake((W-16)/2 - 11, 8, 22, 22)];
        iv.image = [UIImage systemImageNamed:items[i][1]];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.tag = 100;
        iv.userInteractionEnabled = NO;
        [b addSubview:iv];

        UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(0, 33, W - 16, 15)];
        lb.text = items[i][0];
        lb.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
        lb.textAlignment = NSTextAlignmentCenter;
        lb.tag = 101;
        lb.userInteractionEnabled = NO;
        [b addSubview:lb];

        [b addTarget:self action:@selector(sideTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.sidebar addSubview:b];
        [self.sideButtons addObject:b];
    }

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(W - 1.0/[UIScreen mainScreen].scale, 0,
                                                            1.0/[UIScreen mainScreen].scale,
                                                            self.view.bounds.size.height)];
    line.backgroundColor = SLColorStroke();
    line.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.sidebar addSubview:line];
}

- (void)buildContent {
    CGFloat x = kSidebarWidth;
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(x, 0,
                                                                self.view.bounds.size.width - x,
                                                                self.view.bounds.size.height)];
    self.contentView.backgroundColor = SLColorBG();
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentView];

    SLFeatureListVC *f = [[SLFeatureListVC alloc] init];
    UINavigationController *n1 = [[UINavigationController alloc] initWithRootViewController:f];
    [self styleNavBar:n1.navigationBar];

    SLLogVC *l = [[SLLogVC alloc] init];
    UINavigationController *n2 = [[UINavigationController alloc] initWithRootViewController:l];
    [self styleNavBar:n2.navigationBar];

    SLAIAssistantVC *a = [[SLAIAssistantVC alloc] init];
    UINavigationController *n3 = [[UINavigationController alloc] initWithRootViewController:a];
    [self styleNavBar:n3.navigationBar];

    SLGlobalSettingVC *s = [[SLGlobalSettingVC alloc] init];
    UINavigationController *n4 = [[UINavigationController alloc] initWithRootViewController:s];
    [self styleNavBar:n4.navigationBar];

    self.childNavs = [NSMutableArray arrayWithArray:@[n1, n2, n3, n4]];
}

// MoonPack 深色导航条统一样式（对同导航栈内所有页面生效）
- (void)styleNavBar:(UINavigationBar *)bar {
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = NO;
    bar.barTintColor = SLColorBG();
    bar.tintColor = SLColorAccent();
    bar.titleTextAttributes = @{NSForegroundColorAttributeName: SLColorText()};
    bar.largeTitleTextAttributes = @{NSForegroundColorAttributeName: SLColorText()};
}

- (void)sideTapped:(UIButton *)btn {
    NSInteger idx = btn.tag;
    if (idx == 4) { // 帮助
        [self showHelp];
        return;
    }
    [self selectIndex:idx animated:YES];
}

- (void)selectIndex:(NSInteger)idx animated:(BOOL)animated {
    if (idx < 0 || idx >= (NSInteger)self.childNavs.count) return;
    if (idx == self.currentIndex) return;

    // 侧边栏高亮
    for (NSUInteger i = 0; i < self.sideButtons.count; i++) {
        UIButton *b = self.sideButtons[i];
        BOOL sel = (i == (NSUInteger)idx);
        [UIView animateWithDuration:0.2 animations:^{
            b.backgroundColor = sel ? SLColorAccentDim() : [UIColor clearColor];
        }];
        UIImageView *iv = [b viewWithTag:100];
        iv.tintColor = sel ? SLColorAccent() : SLColorText3();
        UILabel *lb = [b viewWithTag:101];
        lb.textColor = sel ? SLColorAccent() : SLColorText2();
        UIView *ind = [b viewWithTag:200];
        ind.hidden = !sel;
    }

    UIViewController *target = self.childNavs[idx];
    target.view.frame = self.contentView.bounds;
    target.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    if (self.currentIndex >= 0) {
        UIViewController *old = self.childNavs[self.currentIndex];
        if (animated) {
            [UIView transitionFromView:old.view
                                toView:target.view
                              duration:0.28
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            completion:nil];
        } else {
            [old.view removeFromSuperview];
            [self.contentView addSubview:target.view];
        }
    } else {
        [self.contentView addSubview:target.view];
    }
    self.currentIndex = idx;
}

- (void)showHelp {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"hjpythonzd 使用帮助"
        message:@"• 主页：点按功能卡片立即运行；长按卡片可设置 / 删除。\n"
              "• 添加：点右上角 ＋，选择 JS 或 Python 脚本，可让 AI 生成。\n"
              "• 日志：查看运行 / 失败 / 崩溃 / AI / 系统日志。\n"
              "• AI：配置 API Key 后可对话，也能生成脚本。\n"
              "• 悬浮球：拖动吸附边缘，点按打开本面板。"
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:^{
        [[SLFloatWindow sharedInstance] restoreAnimated];
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 手势 / 系统方式关闭时也要恢复悬浮球
    if (self.isBeingDismissed) {
        [[SLFloatWindow sharedInstance] restoreAnimated];
    }
}

@end
