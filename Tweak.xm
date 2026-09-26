// Tweak.xm - Minecraft 网易云音乐播放器
// 使用公开 API https://ncm.zhenxin.me

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import <stdlib.h>

// ============================================================
// 1. 配置区
// ============================================================
static NSString * const kAPIBaseURL = @"https://ncm.zhenxin.me";

// ============================================================
// 2. 全局变量
// ============================================================
static AVAudioPlayer *gPlayer = nil;
static UIWindow *gWindow = nil;
static UIView *gBgLayer = nil;
static UIView *gPanel = nil;
static UIView *gCoverWrap = nil;
static UIButton *gFloatBtn = nil;
static UIButton *gPlayBtn = nil;
static UIButton *gPrevBtn = nil;
static UIButton *gNextBtn = nil;
static UIButton *gCloseBtn = nil;
static UIButton *gMuteBtn = nil;
static UIButton *gLoopBtn = nil;
static UIButton *gShuffleBtn = nil;
static UIImageView *gCover = nil;
static UILabel *gTitleLbl = nil;
static UILabel *gArtistLbl = nil;
static UILabel *gTimeLbl = nil;
static UILabel *gVolValueLbl = nil;
static UILabel *gIndexLbl = nil;
static UISlider *gProgress = nil;
static UISlider *gVolume = nil;
static NSArray *gSongs = nil;
static NSInteger gIndex = 0;
static NSTimer *gTimer = nil;
static NSTimer *gAnimTimer = nil;
static BOOL gPanelOpen = NO;
static BOOL gUIInitialized = NO;
static CGFloat gMusicVolume = 0.30f;
static BOOL gMuted = NO;
static BOOL gLoopOne = NO;
static BOOL gShuffleOn = NO;
static CGFloat gCoverPulse = 0.0;

// ============================================================
// 3. 颜色
// ============================================================
static UIColor *cAccent(void) { return [UIColor colorWithRed:0.49 green:0.36 blue:1.00 alpha:1.0]; }
static UIColor *cAccent2(void) { return [UIColor colorWithRed:0.30 green:0.55 blue:1.00 alpha:1.0]; }
static UIColor *cBg(void) { return [UIColor colorWithRed:0.03 green:0.04 blue:0.06 alpha:0.98]; }
static UIColor *cSurface(void) { return [UIColor colorWithRed:1 green:1 blue:1 alpha:0.06]; }
static UIColor *cText(void) { return [UIColor colorWithWhite:0.97 alpha:1.0]; }
static UIColor *cSub(void) { return [UIColor colorWithWhite:0.55 alpha:1.0]; }

// ============================================================
// 4. 手绘图标
// ============================================================
typedef void (^IconDrawBlock)(CGContextRef ctx, CGRect rect);
static UIImage *drawIcon(CGSize size, UIColor *color, CGFloat lw, IconDrawBlock draw) {
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.opaque = NO; fmt.scale = [UIScreen mainScreen].scale;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGContextSetStrokeColorWithColor(c, color.CGColor);
        CGContextSetFillColorWithColor(c, color.CGColor);
        CGContextSetLineWidth(c, lw);
        CGContextSetLineCap(c, kCGLineCapRound);
        CGContextSetLineJoin(c, kCGLineJoinRound);
        draw(c, CGRectMake(0, 0, size.width, size.height));
    }];
}

static UIImage *iconPlay(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 0, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.32, h*0.18);
        CGContextAddLineToPoint(c, w*0.82, h*0.50);
        CGContextAddLineToPoint(c, w*0.32, h*0.82);
        CGContextClosePath(c);
        CGContextFillPath(c);
    });
}
static UIImage *iconPause(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 0, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        UIBezierPath *p1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w*0.28, h*0.20, w*0.16, h*0.60) cornerRadius:w*0.06];
        UIBezierPath *p2 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w*0.56, h*0.20, w*0.16, h*0.60) cornerRadius:w*0.06];
        [p1 fill];
        [p2 fill];
    });
}
static UIImage *iconPrev(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 0, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        UIBezierPath *bar = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w*0.18, h*0.20, w*0.10, h*0.60) cornerRadius:w*0.05];
        [bar fill];
        CGContextMoveToPoint(c, w*0.82, h*0.18);
        CGContextAddLineToPoint(c, w*0.36, h*0.50);
        CGContextAddLineToPoint(c, w*0.82, h*0.82);
        CGContextClosePath(c);
        CGContextFillPath(c);
    });
}
static UIImage *iconNext(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 0, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.18, h*0.18);
        CGContextAddLineToPoint(c, w*0.64, h*0.50);
        CGContextAddLineToPoint(c, w*0.18, h*0.82);
        CGContextClosePath(c);
        CGContextFillPath(c);
        UIBezierPath *bar = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w*0.72, h*0.20, w*0.10, h*0.60) cornerRadius:w*0.05];
        [bar fill];
    });
}
static UIImage *iconClose(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 2.4, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.26, h*0.26);
        CGContextAddLineToPoint(c, w*0.74, h*0.74);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.74, h*0.26);
        CGContextAddLineToPoint(c, w*0.26, h*0.74);
        CGContextStrokePath(c);
    });
}
static UIImage *iconNote(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 2.2, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.60, h*0.20);
        CGContextAddLineToPoint(c, w*0.60, h*0.72);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.60, h*0.20);
        CGContextAddLineToPoint(c, w*0.82, h*0.26);
        CGContextAddLineToPoint(c, w*0.82, h*0.40);
        CGContextAddLineToPoint(c, w*0.60, h*0.34);
        CGContextClosePath(c);
        CGContextFillPath(c);
        CGContextFillEllipseInRect(c, CGRectMake(w*0.30, h*0.64, w*0.30, w*0.26));
    });
}
static UIImage *iconVolume(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 1.8, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.12, h*0.40);
        CGContextAddLineToPoint(c, w*0.32, h*0.40);
        CGContextAddLineToPoint(c, w*0.52, h*0.20);
        CGContextAddLineToPoint(c, w*0.52, h*0.80);
        CGContextAddLineToPoint(c, w*0.32, h*0.60);
        CGContextAddLineToPoint(c, w*0.12, h*0.60);
        CGContextClosePath(c);
        CGContextFillPath(c);
        CGContextMoveToPoint(c, w*0.64, h*0.38);
        CGContextAddQuadCurveToPoint(c, w*0.74, h*0.50, w*0.64, h*0.62);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.74, h*0.26);
        CGContextAddQuadCurveToPoint(c, w*0.92, h*0.50, w*0.74, h*0.74);
        CGContextStrokePath(c);
    });
}
static UIImage *iconMute(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 1.8, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.12, h*0.40);
        CGContextAddLineToPoint(c, w*0.32, h*0.40);
        CGContextAddLineToPoint(c, w*0.52, h*0.20);
        CGContextAddLineToPoint(c, w*0.52, h*0.80);
        CGContextAddLineToPoint(c, w*0.32, h*0.60);
        CGContextAddLineToPoint(c, w*0.12, h*0.60);
        CGContextClosePath(c);
        CGContextFillPath(c);
        CGContextMoveToPoint(c, w*0.64, h*0.38);
        CGContextAddLineToPoint(c, w*0.88, h*0.62);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.88, h*0.38);
        CGContextAddLineToPoint(c, w*0.64, h*0.62);
        CGContextStrokePath(c);
    });
}
static UIImage *iconLoop(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 1.8, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextAddArc(c, w/2, h/2, w*0.32, -M_PI*0.3, M_PI*1.2, 0);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.68, h*0.20);
        CGContextAddLineToPoint(c, w*0.86, h*0.30);
        CGContextAddLineToPoint(c, w*0.72, h*0.44);
        CGContextClosePath(c);
        CGContextFillPath(c);
    });
}
static UIImage *iconShuffle(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 1.8, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.14, h*0.30);
        CGContextAddLineToPoint(c, w*0.42, h*0.30);
        CGContextAddLineToPoint(c, w*0.62, h*0.70);
        CGContextAddLineToPoint(c, w*0.86, h*0.70);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.14, h*0.70);
        CGContextAddLineToPoint(c, w*0.32, h*0.70);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.42, h*0.30);
        CGContextAddLineToPoint(c, w*0.58, h*0.30);
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.72, h*0.60);
        CGContextAddLineToPoint(c, w*0.86, h*0.70);
        CGContextAddLineToPoint(c, w*0.72, h*0.80);
        CGContextClosePath(c);
        CGContextFillPath(c);
        CGContextMoveToPoint(c, w*0.72, h*0.20);
        CGContextAddLineToPoint(c, w*0.86, h*0.30);
        CGContextAddLineToPoint(c, w*0.72, h*0.40);
        CGContextClosePath(c);
        CGContextFillPath(c);
    });
}

// ============================================================
// 5. 音频会话与音量
// ============================================================
static void setupAudioSession(void) {
    AVAudioSession *s = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [s setCategory:AVAudioSessionCategoryPlayback
       withOptions:AVAudioSessionCategoryOptionMixWithOthers
             error:&err];
    [s setActive:YES error:&err];
}

static void applyMusicVolume(void) {
    if (!gPlayer) return;
    if (gMuted) {
        gPlayer.volume = 0.0f;
    } else {
        gPlayer.volume = gMusicVolume;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gVolValueLbl) gVolValueLbl.text = gMuted ? @"静音" :
            [NSString stringWithFormat:@"%d%%", (int)(gMusicVolume * 100)];
        if (gMuteBtn) [gMuteBtn setImage:(gMuted ? iconMute(20, cSub()) : iconVolume(20, cSub()))
                                forState:UIControlStateNormal];
    });
}

// ============================================================
// 6. 网络请求获取播放链接
// ============================================================
static void fetchSongURLAndPlay(NSInteger idx) {
    if (!gSongs || idx < 0 || idx >= (NSInteger)gSongs.count) return;
    NSString *songId = gSongs[idx];
    NSString *urlStr = [NSString stringWithFormat:@"%@/song/url?id=%@", kAPIBaseURL, songId];
    NSURL *url = [NSURL URLWithString:urlStr];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (gTitleLbl) gTitleLbl.text = @"网络请求失败";
                if (gArtistLbl) gArtistLbl.text = @"请检查网络连接";
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *playUrl = json[@"data"][0][@"url"];

        if (playUrl && playUrl.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (gPlayer) { [gPlayer stop]; gPlayer = nil; }
                NSError *err = nil;
                gPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:playUrl] error:&err];
                if (err) return;
                gPlayer.numberOfLoops = gLoopOne ? -1 : 0;
                [gPlayer prepareToPlay];
                applyMusicVolume();
                [gPlayer play];
                gIndex = idx;

                if (gPlayBtn) [gPlayBtn setImage:iconPause(36, [UIColor whiteColor]) forState:UIControlStateNormal];
                if (gTitleLbl) gTitleLbl.text = [NSString stringWithFormat:@"歌曲 ID: %@", songId];
                if (gArtistLbl) gArtistLbl.text = @"来自网易云音乐";
                if (gIndexLbl) gIndexLbl.text = [NSString stringWithFormat:@"%ld / %lu", (long)(gIndex + 1), (unsigned long)gSongs.count];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (gTitleLbl) gTitleLbl.text = @"无法获取播放地址";
                if (gArtistLbl) gArtistLbl.text = @"可能是VIP或版权歌曲";
            });
        }
    }];
    [task resume];
}

static void togglePlay(void) {
    if (!gPlayer) { fetchSongURLAndPlay(gIndex); return; }
    if (gPlayer.isPlaying) {
        [gPlayer pause];
        if (gPlayBtn) [gPlayBtn setImage:iconPlay(36, [UIColor whiteColor]) forState:UIControlStateNormal];
    } else {
        [gPlayer play];
        if (gPlayBtn) [gPlayBtn setImage:iconPause(36, [UIColor whiteColor]) forState:UIControlStateNormal];
    }
}

static void playNext(void) {
    if (gShuffleOn && gSongs.count > 1) {
        NSInteger n = gIndex;
        while (n == gIndex) n = arc4random_uniform((uint32_t)gSongs.count);
        fetchSongURLAndPlay(n);
    } else {
        fetchSongURLAndPlay(gIndex + 1);
    }
}

static void playPrev(void) { fetchSongURLAndPlay(gIndex - 1); }

// ============================================================
// 7. 事件处理类
// ============================================================
@interface MCUIHandler : NSObject
- (void)onTap:(UIButton *)sender;
- (void)onProgress:(UISlider *)s;
- (void)onVolume:(UISlider *)s;
@end

@implementation MCUIHandler
- (void)onTap:(UIButton *)sender {
    switch (sender.tag) {
        case 1: togglePlay(); break;
        case 2: playPrev(); break;
        case 3: playNext(); break;
        case 4:
            [UIView animateWithDuration:0.35 animations:^{
                gPanel.alpha = 0;
                gPanel.transform = CGAffineTransformMakeScale(0.95, 0.95);
                gBgLayer.alpha = 0;
            } completion:^(BOOL f) {
                gPanel.hidden = YES;
                gBgLayer.hidden = YES;
                gPanel.transform = CGAffineTransformIdentity;
                gPanelOpen = NO;
            }];
            break;
        case 5:
            gPanelOpen = !gPanelOpen;
            if (gPanelOpen) {
                gBgLayer.hidden = NO;
                gPanel.hidden = NO;
                gBgLayer.alpha = 0;
                [UIView animateWithDuration:0.45 delay:0
                    usingSpringWithDamping:0.85 initialSpringVelocity:0.5
                    options:UIViewAnimationOptionCurveEaseOut
                    animations:^{
                        gBgLayer.alpha = 1.0;
                        gPanel.alpha = 1.0;
                        gPanel.transform = CGAffineTransformIdentity;
                    } completion:nil];
                if (!gPlayer) fetchSongURLAndPlay(gIndex);
            } else {
                [UIView animateWithDuration:0.3 animations:^{
                    gPanel.alpha = 0;
                    gPanel.transform = CGAffineTransformMakeScale(0.95, 0.95);
                    gBgLayer.alpha = 0;
                } completion:^(BOOL f) {
                    gPanel.hidden = YES;
                    gBgLayer.hidden = YES;
                    gPanel.transform = CGAffineTransformIdentity;
                }];
            }
            break;
        case 6: gMuted = !gMuted; applyMusicVolume(); break;
        case 7: gLoopOne = !gLoopOne;
            if (gPlayer) gPlayer.numberOfLoops = gLoopOne ? -1 : 0;
            [sender setImage:iconLoop(22, gLoopOne ? cAccent() : cSub()) forState:UIControlStateNormal];
            break;
        case 8: gShuffleOn = !gShuffleOn;
            [sender setImage:iconShuffle(22, gShuffleOn ? cAccent() : cSub()) forState:UIControlStateNormal];
            break;
    }
}
- (void)onProgress:(UISlider *)s {
    if (gPlayer && gPlayer.duration > 0) gPlayer.currentTime = s.value * gPlayer.duration;
}
- (void)onVolume:(UISlider *)s {
    gMusicVolume = s.value;
    if (gMuted) gMuted = NO;
    applyMusicVolume();
}
@end

static MCUIHandler *gHandler = nil;

// ============================================================
// 8. UI 构建
// ============================================================
static UIButton *makeButton(CGRect frame, NSInteger tag) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame;
    b.tag = tag;
    [b addTarget:gHandler action:@selector(onTap:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void buildUI(void) {
    if (gWindow || gUIInitialized) return;
    gUIInitialized = YES;
    gHandler = [[MCUIHandler alloc] init];

    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat sw = screen.size.width, sh = screen.size.height;

    gWindow = [[UIWindow alloc] initWithFrame:screen];
    gWindow.windowLevel = UIWindowLevelAlert + 100;
    gWindow.backgroundColor = [UIColor clearColor];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    gWindow.rootViewController = vc;

    // 悬浮球
    CGFloat fb = 62;
    gFloatBtn = makeButton(CGRectMake(sw - fb - 24, 140, fb, fb), 5);
    gFloatBtn.backgroundColor = cAccent();
    gFloatBtn.layer.cornerRadius = fb / 2;
    gFloatBtn.layer.shadowColor = cAccent().CGColor;
    gFloatBtn.layer.shadowOpacity = 0.7;
    gFloatBtn.layer.shadowRadius = 20;
    gFloatBtn.layer.shadowOffset = CGSizeMake(0, 6);
    [gFloatBtn setImage:iconNote(28, [UIColor whiteColor]) forState:UIControlStateNormal];
    [vc.view addSubview:gFloatBtn];

    // 背景遮罩
    gBgLayer = [[UIView alloc] initWithFrame:screen];
    gBgLayer.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    gBgLayer.hidden = YES;
    [vc.view addSubview:gBgLayer];

    // 主面板
    CGFloat margin = 30;
    gPanel = [[UIView alloc] initWithFrame:CGRectMake(margin, margin, sw - margin*2, sh - margin*2)];
    gPanel.backgroundColor = cBg();
    gPanel.layer.cornerRadius = 32;
    gPanel.layer.shadowColor = [UIColor blackColor].CGColor;
    gPanel.layer.shadowOpacity = 0.8;
    gPanel.layer.shadowRadius = 40;
    gPanel.layer.shadowOffset = CGSizeMake(0, 20);
    gPanel.hidden = YES;
    gPanel.alpha = 0;
    [vc.view addSubview:gPanel];

    // 顶部装饰渐变
    CAGradientLayer *topGlow = [CAGradientLayer layer];
    topGlow.frame = CGRectMake(0, 0, gPanel.bounds.size.width, 400);
    topGlow.colors = @[(id)[cAccent() colorWithAlphaComponent:0.15].CGColor,
                       (id)[UIColor clearColor].CGColor];
    topGlow.startPoint = CGPointMake(0.5, 0);
    topGlow.endPoint = CGPointMake(0.5, 1);
    [gPanel.layer insertSublayer:topGlow atIndex:0];

    // 关闭
    gCloseBtn = makeButton(CGRectMake(gPanel.bounds.size.width - 62, 20, 42, 42), 4);
    [gCloseBtn setImage:iconClose(20, cSub()) forState:UIControlStateNormal];
    gCloseBtn.backgroundColor = cSurface();
    gCloseBtn.layer.cornerRadius = 21;
    [gPanel addSubview:gCloseBtn];

    // 循环 & 随机
    gLoopBtn = makeButton(CGRectMake(20, 20, 42, 42), 7);
    [gLoopBtn setImage:iconLoop(22, gLoopOne ? cAccent() : cSub()) forState:UIControlStateNormal];
    gLoopBtn.backgroundColor = cSurface();
    gLoopBtn.layer.cornerRadius = 21;
    [gPanel addSubview:gLoopBtn];

    gShuffleBtn = makeButton(CGRectMake(74, 20, 42, 42), 8);
    [gShuffleBtn setImage:iconShuffle(22, gShuffleOn ? cAccent() : cSub()) forState:UIControlStateNormal];
    gShuffleBtn.backgroundColor = cSurface();
    gShuffleBtn.layer.cornerRadius = 21;
    [gPanel addSubview:gShuffleBtn];

    // 封面区域
    CGFloat coverSize = MIN(gPanel.bounds.size.width * 0.42, 340);
    CGFloat coverY = 100;
    gCoverWrap = [[UIView alloc] initWithFrame:CGRectMake((gPanel.bounds.size.width - coverSize)/2, coverY, coverSize, coverSize)];
    [gPanel addSubview:gCoverWrap];

    UIView *glow = [[UIView alloc] initWithFrame:CGRectMake(-coverSize*0.15, -coverSize*0.15, coverSize*1.3, coverSize*1.3)];
    glow.backgroundColor = cAccent();
    glow.alpha = 0.35;
    glow.layer.cornerRadius = coverSize * 0.65;
    glow.layer.shadowColor = cAccent().CGColor;
    glow.layer.shadowOpacity = 1.0;
    glow.layer.shadowRadius = 60;
    glow.layer.shadowOffset = CGSizeZero;
    [gCoverWrap addSubview:glow];

    gCover = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, coverSize, coverSize)];
    gCover.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.18 alpha:1.0];
    gCover.layer.cornerRadius = 24;
    gCover.layer.masksToBounds = YES;
    gCover.contentMode = UIViewContentModeCenter;
    gCover.image = iconNote(coverSize * 0.42, [cSub() colorWithAlphaComponent:0.7]);
    gCover.layer.borderWidth = 1;
    gCover.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [gCoverWrap addSubview:gCover];

    // 歌名
    CGFloat titleY = coverY + coverSize + 40;
    gTitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(30, titleY, gPanel.bounds.size.width - 60, 48)];
    gTitleLbl.textColor = cText();
    gTitleLbl.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    gTitleLbl.textAlignment = NSTextAlignmentCenter;
    gTitleLbl.text = @"未在播放";
    gTitleLbl.adjustsFontSizeToFitWidth = YES;
    gTitleLbl.minimumScaleFactor = 0.5;
    [gPanel addSubview:gTitleLbl];

    // 艺术家
    gArtistLbl = [[UILabel alloc] initWithFrame:CGRectMake(30, titleY + 54, gPanel.bounds.size.width - 60, 24)];
    gArtistLbl.textColor = cSub();
    gArtistLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    gArtistLbl.textAlignment = NSTextAlignmentCenter;
    gArtistLbl.text = @"来自网易云音乐";
    [gPanel addSubview:gArtistLbl];

    // 进度条
    CGFloat progY = titleY + 110;
    CGFloat progX = 50;
    CGFloat progW = gPanel.bounds.size.width - 100;

    gProgress = [[UISlider alloc] initWithFrame:CGRectMake(progX, progY, progW, 24)];
    gProgress.minimumValue = 0;
    gProgress.maximumValue = 1;
    gProgress.value = 0;
    gProgress.minimumTrackTintColor = cAccent();
    gProgress.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.1];
    [gProgress addTarget:gHandler action:@selector(onProgress:) forControlEvents:UIControlEventValueChanged];
    [gPanel addSubview:gProgress];

    // 时间
    gTimeLbl = [[UILabel alloc] initWithFrame:CGRectMake(progX, progY + 28, progW, 18)];
    gTimeLbl.textColor = cSub();
    gTimeLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    gTimeLbl.textAlignment = NSTextAlignmentCenter;
    gTimeLbl.text = @"0:00 / 0:00";
    [gPanel addSubview:gTimeLbl];

    // 控制按钮
    CGFloat ctrlY = progY + 80;
    CGFloat playSize = 90;
    CGFloat sideSize = 62;
    CGFloat gap = 30;
    CGFloat totalW = playSize + (sideSize + gap) * 2;
    CGFloat startX = (gPanel.bounds.size.width - totalW) / 2;
    CGFloat playX = startX + sideSize + gap;

    // 上一首
    gPrevBtn = makeButton(CGRectMake(startX, ctrlY + (playSize - sideSize)/2, sideSize, sideSize), 2);
    gPrevBtn.backgroundColor = cSurface();
    gPrevBtn.layer.cornerRadius = sideSize / 2;
    gPrevBtn.layer.borderWidth = 1;
    gPrevBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [gPrevBtn setImage:iconPrev(28, cText()) forState:UIControlStateNormal];
    [gPanel addSubview:gPrevBtn];

    // 播放
    gPlayBtn = makeButton(CGRectMake(playX, ctrlY, playSize, playSize), 1);
    CAGradientLayer *playGrad = [CAGradientLayer layer];
    playGrad.frame = CGRectMake(0, 0, playSize, playSize);
    playGrad.colors = @[(id)cAccent().CGColor, (id)cAccent2().CGColor];
    playGrad.startPoint = CGPointMake(0, 0);
    playGrad.endPoint = CGPointMake(1, 1);
    playGrad.cornerRadius = playSize / 2;
    [gPlayBtn.layer addSublayer:playGrad];
    gPlayBtn.layer.cornerRadius = playSize / 2;
    gPlayBtn.layer.shadowColor = cAccent().CGColor;
    gPlayBtn.layer.shadowOpacity = 0.6;
    gPlayBtn.layer.shadowRadius = 30;
    gPlayBtn.layer.shadowOffset = CGSizeMake(0, 10);
    [gPlayBtn setImage:iconPlay(36, [UIColor whiteColor]) forState:UIControlStateNormal];
    [gPanel addSubview:gPlayBtn];

    // 下一首
    gNextBtn = makeButton(CGRectMake(playX + playSize + gap, ctrlY + (playSize - sideSize)/2, sideSize, sideSize), 3);
    gNextBtn.backgroundColor = cSurface();
    gNextBtn.layer.cornerRadius = sideSize / 2;
    gNextBtn.layer.borderWidth = 1;
    gNextBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [gNextBtn setImage:iconNext(28, cText()) forState:UIControlStateNormal];
    [gPanel addSubview:gNextBtn];

    // 音量区
    CGFloat volY = ctrlY + 140;
    CGFloat volX = 60;
    CGFloat volW = gPanel.bounds.size.width - 120;

    UILabel *volTitle = [[UILabel alloc] initWithFrame:CGRectMake(volX, volY, 100, 20)];
    volTitle.text = @"音乐音量";
    volTitle.textColor = cSub();
    volTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [gPanel addSubview:volTitle];

    gVolValueLbl = [[UILabel alloc] initWithFrame:CGRectMake(volX + volW - 60, volY, 60, 20)];
    gVolValueLbl.text = @"30%";
    gVolValueLbl.textColor = cAccent();
    gVolValueLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    gVolValueLbl.textAlignment = NSTextAlignmentRight;
    [gPanel addSubview:gVolValueLbl];

    gMuteBtn = makeButton(CGRectMake(volX, volY + 30, 36, 36), 6);
    [gMuteBtn setImage:iconVolume(20, cSub()) forState:UIControlStateNormal];
    [gPanel addSubview:gMuteBtn];

    gVolume = [[UISlider alloc] initWithFrame:CGRectMake(volX + 46, volY + 36, volW - 46, 24)];
    gVolume.minimumValue = 0;
    gVolume.maximumValue = 1;
    gVolume.value = gMusicVolume;
    gVolume.minimumTrackTintColor = cAccent();
    gVolume.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.1];
    [gVolume addTarget:gHandler action:@selector(onVolume:) forControlEvents:UIControlEventValueChanged];
    [gPanel addSubview:gVolume];

    // 底部索引
    gIndexLbl = [[UILabel alloc] initWithFrame:CGRectMake(30, gPanel.bounds.size.height - 46, gPanel.bounds.size.width - 60, 20)];
    gIndexLbl.textColor = cSub();
    gIndexLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    gIndexLbl.textAlignment = NSTextAlignmentCenter;
    gIndexLbl.text = @"";
    [gPanel addSubview:gIndexLbl];

    [gWindow makeKeyAndVisible];
    NSLog(@"[MCPlugin] 全屏 UI 已就绪");
}

// ============================================================
// 9. 定时器
// ============================================================
static void startTimer(void) {
    if (gTimer) [gTimer invalidate];
    gTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *t) {
        if (!gPlayer) return;
        NSTimeInterval cur = gPlayer.currentTime;
        NSTimeInterval dur = gPlayer.duration;
        if (dur > 0) {
            float p = (float)(cur / dur);
            int cm = (int)cur / 60, cs = (int)cur % 60;
            int dm = (int)dur / 60, ds = (int)dur % 60;
            dispatch_async(dispatch_get_main_queue(), ^{
                gProgress.value = p;
                gTimeLbl.text = [NSString stringWithFormat:@"%d:%02d / %d:%02d", cm, cs, dm, ds];
            });
        }
    }];

    if (gAnimTimer) [gAnimTimer invalidate];
    gAnimTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *t) {
        if (!gPanelOpen || !gCoverWrap) return;
        gCoverPulse += 0.08;
        CGFloat scale = 1.0 + sin(gCoverPulse) * 0.015;
        gCoverWrap.transform = CGAffineTransformMakeScale(scale, scale);
    }];
}

// ============================================================
// 10. 入口
// ============================================================
%ctor {
    NSLog(@"[MCPlugin] 插件加载");
    setupAudioSession();

    // 网易云歌曲 ID 列表（可自行替换）
    gSongs = @[@"186016", @"1330348068", @"569213220"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        buildUI();
        startTimer();
    });
}
