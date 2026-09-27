// Tweak.xm - Minecraft 卡密验证（已查错 + 优化 UI + 对接后台状态）

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ============================================================
// 配置区：改成你的服务器地址（结尾不要带 /）
// ============================================================
static NSString * const kAPI = @"https://a1d46de8782258fee.app.workbuddy.host";

static NSString * const kCardKey = @"MCCardKey";
static NSString * const kExpireKey = @"MCCardExpire";

// ============================================================
// 全局变量
// ============================================================
static UIWindow *gHostWindow = nil;
static UIView *gMask = nil;
static UIView *gCard = nil;
static UITextField *gInput = nil;
static UIButton *gActivateBtn = nil;
static UIButton *gPasteBtn = nil;
static UILabel *gStatusLbl = nil;
static UILabel *gConnLbl = nil;
static UIActivityIndicatorView *gLoading = nil;
static BOOL gUILoaded = NO;
static CGRect gCardOriginalFrame = CGRectZero;

// ============================================================
// 颜色
// ============================================================
static UIColor *cAccent(void) { return [UIColor colorWithRed:0.49 green:0.36 blue:1.00 alpha:1.0]; }
static UIColor *cBg(void) { return [UIColor colorWithRed:0.03 green:0.04 blue:0.06 alpha:0.98]; }
static UIColor *cSurface(void) { return [UIColor colorWithWhite:1 alpha:0.06]; }
static UIColor *cText(void) { return [UIColor colorWithWhite:0.97 alpha:1.0]; }
static UIColor *cSub(void) { return [UIColor colorWithWhite:0.55 alpha:1.0]; }
static UIColor *cGreen(void) { return [UIColor colorWithRed:0.24 green:0.86 blue:0.59 alpha:1.0]; }
static UIColor *cRed(void) { return [UIColor colorWithRed:1.0 green:0.36 blue:0.36 alpha:1.0]; }

// ============================================================
// 遮罩视图（拦截背景触摸，但放行卡片内的子控件）
// ============================================================
@interface MCMaskView : UIView
@end

@implementation MCMaskView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit ? hit : self;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
@end

// ============================================================
// 事件处理器
// ============================================================
@interface MCHandler : NSObject <UITextFieldDelegate>
@end

@implementation MCHandler

- (void)setStatus:(NSString *)text color:(UIColor *)color {
    if (!gStatusLbl) return;
    gStatusLbl.text = text;
    gStatusLbl.textColor = color;
}

// 键盘弹出：把卡片上移到屏幕上半部，避免输入框被遮挡
- (void)keyboardWillShow:(NSNotification *)notif {
    if (!gCard) return;
    CGRect screen = [UIScreen mainScreen].bounds;
    CGRect f = gCard.frame;
    f.origin.y = MAX(20.0, (screen.size.height - f.size.height) * 0.16);
    [UIView animateWithDuration:0.25 animations:^{ if (gCard) gCard.frame = f; }];
}

// 键盘收起：还原卡片位置
- (void)keyboardWillHide:(NSNotification *)notif {
    if (!gCard) return;
    [UIView animateWithDuration:0.25 animations:^{ if (gCard) gCard.frame = gCardOriginalFrame; }];
}

// 粘贴卡密
- (void)onPaste {
    NSString *s = [UIPasteboard generalPasteboard].string;
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length > 0) {
        gInput.text = s;
        [self setStatus:@"已粘贴，点击激活" color:cSub()];
    } else {
        [self setStatus:@"剪贴板为空" color:cRed()];
    }
}

// 键盘回车直接激活
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self onActivate];
    return YES;
}

- (void)onActivate {
    NSString *card = [gInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (card.length == 0) {
        [self setStatus:@"请输入卡密" color:cRed()];
        return;
    }

    [gInput resignFirstResponder];
    gActivateBtn.enabled = NO;
    gActivateBtn.alpha = 0.6;
    [gLoading startAnimating];
    [self setStatus:@"验证中…" color:cSub()];

    NSString *device = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (!device) device = @"unknown-device";

    NSDictionary *body = @{@"card": card, @"device": device};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSString *urlStr = [kAPI stringByAppendingString:@"/api/verify"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = jsonData;
    req.timeoutInterval = 30;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            gActivateBtn.enabled = YES;
            gActivateBtn.alpha = 1.0;
            [gLoading stopAnimating];

            if (err || !data) {
                [self setStatus:@"网络错误，请检查连接" color:cRed()];
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![json isKindOfClass:[NSDictionary class]]) {
                [self setStatus:@"服务器返回异常" color:cRed()];
                return;
            }

            if ([json[@"ok"] boolValue]) {
                NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                [ud setObject:card forKey:kCardKey];
                NSNumber *exp = json[@"expire"];
                if ([exp isKindOfClass:[NSNumber class]]) {   // 防 setObject:nil 崩溃
                    [ud setObject:exp forKey:kExpireKey];
                }
                [ud synchronize];

                id days = json[@"days"];
                NSString *daysStr = [days respondsToSelector:@selector(stringValue)] ? [days stringValue] : @"";
                [self setStatus:[NSString stringWithFormat:@"✓ 验证成功 · 剩余 %@ 天", daysStr] color:cGreen()];

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:0.45 animations:^{
                        gMask.alpha = 0;
                    } completion:^(BOOL f) {
                        [gMask removeFromSuperview];   // 修复：真正移出视图层级，而非仅隐藏
                        gMask = nil;
                        gCard = nil;
                        gInput = nil;
                        gActivateBtn = nil;
                        gStatusLbl = nil;
                        gConnLbl = nil;
                        gLoading = nil;
                    }];
                });
            } else {
                NSString *msg = [json[@"msg"] isKindOfClass:[NSString class]] ? json[@"msg"] : @"验证失败";
                [self setStatus:msg color:cRed()];
            }
        });
    }] resume];
}

@end

static MCHandler *gHandler = nil;

// ============================================================
// 检测服务器连通性（对接后台：显示在线状态）
// ============================================================
static void checkServer(void) {
    if (!gConnLbl) return;
    gConnLbl.text = @"● 正在连接服务器…";
    gConnLbl.textColor = cSub();

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[kAPI stringByAppendingString:@"/"]]];
    req.timeoutInterval = 15;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!gConnLbl) return;
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
            if (!err && http.statusCode == 200) {
                gConnLbl.text = @"● 服务器在线";
                gConnLbl.textColor = cGreen();
            } else {
                gConnLbl.text = @"● 服务器连接失败";
                gConnLbl.textColor = cRed();
            }
        });
    }] resume];
}

// ============================================================
// 找游戏 keyWindow
// ============================================================
static UIWindow *findGameKeyWindow(void) {
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *w in windows) {
        if (w.isKeyWindow && w.windowLevel < UIWindowLevelAlert) return w;
    }
    for (UIWindow *w in windows) {
        if (w.windowLevel == UIWindowLevelNormal) return w;
    }
    if (windows.count > 0) return windows.firstObject;
    return nil;
}

// ============================================================
// 构建卡密验证遮罩
// ============================================================
static void buildMask(UIWindow *host) {
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat sw = screen.size.width;
    CGFloat sh = screen.size.height;

    gMask = [[MCMaskView alloc] initWithFrame:screen];
    gMask.backgroundColor = [UIColor colorWithWhite:0 alpha:0.88];
    gMask.hidden = NO;
    gMask.alpha = 1;
    [host addSubview:gMask];

    CGFloat cw = MIN(sw - 60, 420);
    CGFloat ch = 270;
    gCard = [[UIView alloc] initWithFrame:CGRectMake((sw - cw) / 2, (sh - ch) / 2, cw, ch)];
    gCardOriginalFrame = gCard.frame;
    gCard.backgroundColor = cBg();
    gCard.layer.cornerRadius = 24;
    gCard.layer.shadowColor = [UIColor blackColor].CGColor;
    gCard.layer.shadowOpacity = 0.8;
    gCard.layer.shadowRadius = 40;
    gCard.layer.shadowOffset = CGSizeMake(0, 16);
    gCard.layer.borderWidth = 1;
    gCard.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    [gMask addSubview:gCard];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 28, cw, 28)];
    title.text = @"卡密验证";
    title.textColor = cText();
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    [gCard addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(0, 58, cw, 18)];
    sub.text = @"请输入卡密以激活插件";
    sub.textColor = cSub();
    sub.font = [UIFont systemFontOfSize:13];
    sub.textAlignment = NSTextAlignmentCenter;
    [gCard addSubview:sub];

    // 服务器连接状态（对接后台）
    gConnLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, cw, 16)];
    gConnLbl.text = @"● 正在连接服务器…";
    gConnLbl.textColor = cSub();
    gConnLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    gConnLbl.textAlignment = NSTextAlignmentCenter;
    [gCard addSubview:gConnLbl];

    // 输入框 + 粘贴按钮
    CGFloat pasteW = 60;
    CGFloat inputW = cw - 48 - pasteW - 8;
    gInput = [[UITextField alloc] initWithFrame:CGRectMake(24, 108, inputW, 44)];
    gInput.backgroundColor = cSurface();
    gInput.layer.cornerRadius = 12;
    gInput.layer.borderWidth = 1;
    gInput.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    gInput.textColor = cText();
    gInput.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    gInput.textAlignment = NSTextAlignmentCenter;
    gInput.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    gInput.autocorrectionType = UITextAutocorrectionTypeNo;
    gInput.returnKeyType = UIReturnKeyGo;
    gInput.delegate = gHandler;
    gInput.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"XXXX-XXXX-XXXX-XXXX"
        attributes:@{NSForegroundColorAttributeName: cSub()}];
    [gCard addSubview:gInput];

    gPasteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    gPasteBtn.frame = CGRectMake(24 + inputW + 8, 108, pasteW, 44);
    gPasteBtn.backgroundColor = cSurface();
    gPasteBtn.layer.cornerRadius = 12;
    gPasteBtn.layer.borderWidth = 1;
    gPasteBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    gPasteBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [gPasteBtn setTitle:@"粘贴" forState:UIControlStateNormal];
    [gPasteBtn setTitleColor:cAccent() forState:UIControlStateNormal];
    [gPasteBtn addTarget:gHandler action:@selector(onPaste) forControlEvents:UIControlEventTouchUpInside];
    [gCard addSubview:gPasteBtn];

    gActivateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    gActivateBtn.frame = CGRectMake(24, 164, cw - 48, 44);
    gActivateBtn.backgroundColor = cAccent();
    gActivateBtn.layer.cornerRadius = 12;
    gActivateBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [gActivateBtn setTitle:@"激活" forState:UIControlStateNormal];
    [gActivateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [gActivateBtn addTarget:gHandler action:@selector(onActivate) forControlEvents:UIControlEventTouchUpInside];
    gActivateBtn.layer.shadowColor = cAccent().CGColor;
    gActivateBtn.layer.shadowOpacity = 0.5;
    gActivateBtn.layer.shadowRadius = 15;
    gActivateBtn.layer.shadowOffset = CGSizeMake(0, 6);   // 修复：原文是 CGSizeMake(0会, 6)
    [gCard addSubview:gActivateBtn];

    gStatusLbl = [[UILabel alloc] initWithFrame:CGRectMake(24, 216, cw - 48, 22)];
    gStatusLbl.text = @"";
    gStatusLbl.textColor = cSub();
    gStatusLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    gStatusLbl.textAlignment = NSTextAlignmentCenter;
    [gCard addSubview:gStatusLbl];

    gLoading = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    gLoading.frame = CGRectMake(cw - 60, 174, 24, 24);
    gLoading.color = [UIColor whiteColor];
    gLoading.hidesWhenStopped = YES;
    [gCard addSubview:gLoading];

    // 键盘监听（避免遮挡输入框）
    [[NSNotificationCenter defaultCenter] addObserver:gHandler selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:gHandler selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    // 启动时检测后台连通性
    checkServer();
}

// ============================================================
// 启动
// ============================================================
static void checkAndStart(void) {
    if (gUILoaded) return;

    UIWindow *host = findGameKeyWindow();
    if (!host) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            checkAndStart();
        });
        return;
    }
    gUILoaded = YES;
    gHostWindow = host;
    gHandler = [[MCHandler alloc] init];

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *savedCard = [ud stringForKey:kCardKey];
    NSNumber *savedExpire = [ud objectForKey:kExpireKey];

    BOOL localValid = NO;
    if (savedCard && savedExpire) {
        long long expire = [savedExpire longLongValue];
        long long now = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
        if (expire > now) localValid = YES;
    }

    if (localValid) {
        NSLog(@"[MCPlugin] 本地卡密有效，跳过验证");
    } else {
        buildMask(host);
    }
}

%ctor {
    NSLog(@"[MCPlugin] 加载");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        checkAndStart();
    });
}
