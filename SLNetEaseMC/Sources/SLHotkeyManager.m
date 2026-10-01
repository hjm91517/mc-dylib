#import "SLHotkeyManager.h"
#import <UIKit/UIKit.h>
#import "SLModel.h"
#import "SLScriptManager.h"
#import "SLScriptEngine.h"

#pragma mark - SLHotkeyView

@interface SLHotkeyView : NSObject
@property (nonatomic, strong) SLFeature *feature;
@property (nonatomic, strong) UIWindow  *hotkeyWindow;
- (instancetype)initWithFeature:(SLFeature *)feature;
- (void)destroy;
@end

@implementation SLHotkeyView

- (instancetype)initWithFeature:(SLFeature *)feature {
    if (self = [super init]) {
        _feature = feature;
        [self setupWindow];
    }
    return self;
}

- (void)setupWindow {
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat size = 44;
    self.hotkeyWindow = [[UIWindow alloc] initWithFrame:CGRectMake(screen.size.width - 80,
                                                                    screen.size.height * 0.35,
                                                                    size, size)];
    self.hotkeyWindow.windowLevel = UIWindowLevelStatusBar + 2;
    self.hotkeyWindow.backgroundColor = [UIColor clearColor];
    self.hotkeyWindow.rootViewController = [UIViewController new];
    self.hotkeyWindow.hidden = NO;
    self.hotkeyWindow.layer.shadowColor = [UIColor blackColor].CGColor;
    self.hotkeyWindow.layer.shadowOpacity = 0.3;
    self.hotkeyWindow.layer.shadowOffset = CGSizeMake(0, 2);
    self.hotkeyWindow.layer.shadowRadius = 3;

    UILabel *label = [[UILabel alloc] initWithFrame:self.hotkeyWindow.bounds];
    label.text = @"⚡";
    label.font = [UIFont systemFontOfSize:22];
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = YES;
    label.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.9];
    label.layer.cornerRadius = size / 2.0;
    label.layer.masksToBounds = YES;
    [self.hotkeyWindow.rootViewController.view addSubview:label];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(toggle)];
    [label addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(panned:)];
    [label addGestureRecognizer:pan];
}

- (void)toggle {
    self.feature.enabled = !self.feature.enabled;
    [[SLScriptManager sharedInstance] saveFeature:self.feature];
    if (self.feature.enabled) {
        [SLScriptEngine runScript:self.feature.scriptContent
                             type:self.feature.scriptType
                        variables:self.feature.settings
                      featureName:self.feature.name];
    }
}

- (void)panned:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.hotkeyWindow.rootViewController.view];
    CGPoint c = self.hotkeyWindow.center;
    c.x += t.x; c.y += t.y;
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat half = self.hotkeyWindow.bounds.size.width / 2.0;
    c.x = MAX(half, MIN(screen.size.width - half, c.x));
    c.y = MAX(half, MIN(screen.size.height - half, c.y));
    self.hotkeyWindow.center = c;
    [g setTranslation:CGPointZero inView:self.hotkeyWindow.rootViewController.view];
}

- (void)destroy {
    self.hotkeyWindow.hidden = YES;
    self.hotkeyWindow.rootViewController = nil;
    self.hotkeyWindow = nil;
}
@end

#pragma mark - SLHotkeyManager

@interface SLHotkeyManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, SLHotkeyView *> *hotkeys;
@end

@implementation SLHotkeyManager

+ (instancetype)sharedInstance {
    static SLHotkeyManager *i; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[SLHotkeyManager alloc] init]; });
    return i;
}

- (instancetype)init {
    if (self = [super init]) _hotkeys = [NSMutableDictionary dictionary];
    return self;
}

- (void)rebuildAll {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SLHotkeyView *v in self.hotkeys.allValues) [v destroy];
        [self.hotkeys removeAllObjects];

        for (SLFeature *f in [[SLScriptManager sharedInstance] loadAllFeatures]) {
            if (f.hotkeyVisible) {
                self.hotkeys[f.featureId] = [[SLHotkeyView alloc] initWithFeature:f];
            }
        }
    });
}

- (void)removeHotkeyForFeatureId:(NSString *)fid {
    SLHotkeyView *v = self.hotkeys[fid];
    if (v) { [v destroy]; [self.hotkeys removeObjectForKey:fid]; }
}
@end
