#import "FSLHotkeyWindow.h"
#import "FSLFunction.h"
#import "FSLFunctionManager.h"

@interface FSLHotkeyPassthroughView : UIView
@end

@implementation FSLHotkeyPassthroughView
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

@interface FSLHotkeyPassthroughVC : UIViewController
@end

@implementation FSLHotkeyPassthroughVC
- (void)loadView {
    self.view = [[FSLHotkeyPassthroughView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}
@end

#pragma mark - 单个快捷键按钮

@interface FSLHotkeyButton : UIButton
@property (nonatomic, strong) FSLFunction *fn;
@end

@implementation FSLHotkeyButton

- (instancetype)initWithFunction:(FSLFunction *)fn {
    CGFloat size = 46.0;
    if ((self = [super initWithFrame:CGRectMake(0, 0, size, size)])) {
        _fn = fn;
        self.layer.cornerRadius = size / 2.0;
        self.clipsToBounds = YES;
        self.layer.borderWidth = 2.0;
        NSString *title = fn.name.length ? [fn.name substringToIndex:1] : @"?";
        [self setTitle:title forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.backgroundColor = fn.type == FSLScriptTypePython
            ? [UIColor colorWithRed:0.20 green:0.45 blue:0.85 alpha:0.85]
            : [UIColor colorWithRed:0.90 green:0.65 blue:0.10 alpha:0.85];

        [self addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(handleLongPress:)];
        lp.minimumPressDuration = 0.35;
        [self addGestureRecognizer:lp];
        [self updateAppearance];
    }
    return self;
}

- (void)tapped {
    [[FSLFunctionManager shared] toggleRun:self.fn];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self updateAppearance];
    });
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    UIView *container = self.superview;
    if (!container) return;
    CGPoint loc = [g locationInView:container];
    switch (g.state) {
        case UIGestureRecognizerStateBegan:
            [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformMakeScale(1.15, 1.15); }];
            break;
        case UIGestureRecognizerStateChanged:
            self.center = loc;
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            [UIView animateWithDuration:0.15 animations:^{ self.transform = CGAffineTransformIdentity; }];
            CGRect b = container.bounds;
            CGPoint c = self.center;
            c.x = MAX(28, MIN(b.size.width - 28, c.x));
            c.y = MAX(50, MIN(b.size.height - 50, c.y));
            [UIView animateWithDuration:0.2 animations:^{ self.center = c; }];
            self.fn.hotkeyPosition = c;
            [[FSLFunctionManager shared] save];
            break;
        }
        default: break;
    }
}

- (void)updateAppearance {
    BOOL running = [[FSLFunctionManager shared] isRunning:self.fn];
    self.layer.borderColor = running
        ? [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0].CGColor
        : [UIColor colorWithWhite:1.0 alpha:0.8].CGColor;
}

@end

#pragma mark - 快捷键窗口

@interface FSLHotkeyWindow ()
@property (nonatomic, strong) NSMutableArray<FSLHotkeyButton *> *buttons;
@end

@implementation FSLHotkeyWindow

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
    self.windowLevel = UIWindowLevelStatusBar + 2;
    self.backgroundColor = UIColor.clearColor;
    self.rootViewController = [FSLHotkeyPassthroughVC new];
    self.hidden = NO;
    _buttons = [NSMutableArray array];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reloadButtons)
                                               name:FSLFunctionsDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateButtonStates)
                                               name:FSLRunStateDidChangeNotification object:nil];
    [self reloadButtons];
    return self;
}

- (void)reloadButtons {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (FSLHotkeyButton *b in self.buttons) [b removeFromSuperview];
        [self.buttons removeAllObjects];

        UIView *container = self.rootViewController.view;
        NSInteger autoIndex = 0;
        for (FSLFunction *fn in [FSLFunctionManager shared].functions) {
            if (!fn.enabled || !fn.hotkeyEnabled) continue;
            FSLHotkeyButton *btn = [[FSLHotkeyButton alloc] initWithFunction:fn];
            if (fn.hotkeyPosition.x > 1 && fn.hotkeyPosition.y > 1) {
                btn.center = fn.hotkeyPosition;
            } else {
                btn.center = CGPointMake(self.bounds.size.width - 40, 260 + autoIndex * 56);
                autoIndex++;
            }
            [container addSubview:btn];
            [self.buttons addObject:btn];
        }
    });
}

- (void)updateButtonStates {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (FSLHotkeyButton *b in self.buttons) [b updateAppearance];
    });
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end
