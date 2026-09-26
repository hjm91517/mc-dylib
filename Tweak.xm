// Tweak.xm - Minecraft 独立音量音乐播放器
// 全手绘 UI，无 Emoji，无 fishhook，无材质注入

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

// ============================================================
// 1. 全局变量
// ============================================================

static AVAudioPlayer *gPlayer = nil;
static UIWindow *gWindow = nil;
static UIView *gPanel = nil;
static UIButton *gFloatBtn = nil;
static UIButton *gPlayBtn = nil;
static UIButton *gPrevBtn = nil;
static UIButton *gNextBtn = nil;
static UIButton *gCloseBtn = nil;
static UIButton *gMuteBtn = nil;
static UIImageView *gCover = nil;
static UILabel *gTitleLbl = nil;
static UILabel *gArtistLbl = nil;
static UILabel *gLyricLbl = nil;
static UILabel *gTimeLbl = nil;
static UILabel *gVolValueLbl = nil;
static UISlider *gProgress = nil;
static UISlider *gVolume = nil;
static NSArray *gSongs = nil;
static NSArray *gLyrics = nil;
static NSInteger gIndex = 0;
static NSInteger gLyricIdx = -1;
static NSTimer *gTimer = nil;
static BOOL gPanelOpen = NO;
static BOOL gUIInitialized = NO;
static CGFloat gMusicVolume = 0.30f;  // 默认音乐音量 30%
static BOOL gMuted = NO;

// ============================================================
// 2. 颜色定义
// ============================================================

static UIColor *cAccent(void) { return [UIColor colorWithRed:0.36 green:0.62 blue:1.00 alpha:1.0]; }
static UIColor *cBg(void) { return [UIColor colorWithRed:0.07 green:0.08 blue:0.12 alpha:0.97]; }
static UIColor *cSurface(void) { return [UIColor colorWithRed:0.13 green:0.14 blue:0.19 alpha:1.0]; }
static UIColor *cText(void) { return [UIColor colorWithWhite:0.96 alpha:1.0]; }
static UIColor *cSub(void) { return [UIColor colorWithWhite:0.60 alpha:1.0]; }

// ============================================================
// 3. 图标绘制引擎（全手绘，无 Emoji）
// ============================================================

typedef void (^IconDrawBlock)(CGContextRef ctx, CGRect rect);

static UIImage *drawIcon(CGSize size, UIColor *color, CGFloat lw, IconDrawBlock draw) {
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.opaque = NO;
    fmt.scale = [UIScreen mainScreen].scale;
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
        CGContextMoveToPoint(c, w*0.30, h*0.18); CGContextAddLineToPoint(c, w*0.84, h*0.50);
        CGContextAddLineToPoint(c, w*0.30, h*0.82); CGContextClosePath(c); CGContextFillPath(c);
    });
}

static UIImage *iconPause(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 0, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        UIBezierPath *p1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w*0.28, h*0.20, w*0.14, h*0.60) cornerRadius:w*0.06];
        UIBezierPath *p2 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w*0.58, h*0.20, w*0.14, h*0.60) cornerRadius:w*0.06];
        [p1 fill]; [p2 fill];
    });
}

static UIImage *iconPrev(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 0, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        UIBezierPath *bar = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w*0.20, h*0.20, w*0.10, h*0.60) cornerRadius:w*0.05];
        [bar fill];
        CGContextMoveToPoint(c, w*0.82, h*0.18); CGContextAddLineToPoint(c, w*0.36, h*0.50);
        CGContextAddLineToPoint(c, w*0.82, h*0.82); CGContextClosePath(c); CGContextFillPath(c);
    });
}

static UIImage *iconNext(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 0, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.18, h*0.18); CGContextAddLineToPoint(c, w*0.64, h*0.50);
        CGContextAddLineToPoint(c, w*0.18, h*0.82); CGContextClosePath(c); CGContextFillPath(c);
        UIBezierPath *bar = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w*0.70, h*0.20, w*0.10, h*0.60) cornerRadius:w*0.05];
        [bar fill];
    });
}

static UIImage *iconClose(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 2.0, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.28, h*0.28); CGContextAddLineToPoint(c, w*0.72, h*0.72); CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.72, h*0.28); CGContextAddLineToPoint(c, w*0.28, h*0.72); CGContextStrokePath(c);
    });
}

static UIImage *iconNote(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 2.2, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.60, h*0.22); CGContextAddLineToPoint(c, w*0.60, h*0.70); CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.60, h*0.22); CGContextAddLineToPoint(c, w*0.78, h*0.28);
        CGContextAddLineToPoint(c, w*0.78, h*0.40); CGContextAddLineToPoint(c, w*0.60, h*0.34); CGContextClosePath(c); CGContextFillPath(c);
        CGContextFillEllipseInRect(c, CGRectMake(w*0.34, h*0.64, w*0.28, w*0.24));
    });
}

static UIImage *iconVolume(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 1.8, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.14, h*0.40); CGContextAddLineToPoint(c, w*0.34, h*0.40);
        CGContextAddLineToPoint(c, w*0.54, h*0.22); CGContextAddLineToPoint(c, w*0.54, h*0.78);
        CGContextAddLineToPoint(c, w*0.34, h*0.60); CGContextAddLineToPoint(c, w*0.14, h*0.60); CGContextClosePath(c); CGContextFillPath(c);
        CGContextMoveToPoint(c, w*0.66, h*0.38); CGContextAddQuadCurveToPoint(c, w*0.76, h*0.50, w*0.66, h*0.62); CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.76, h*0.28); CGContextAddQuadCurveToPoint(c, w*0.92, h*0.50, w*0.76, h*0.72); CGContextStrokePath(c);
    });
}

static UIImage *iconMute(CGFloat s, UIColor *color) {
    return drawIcon(CGSizeMake(s, s), color, 1.8, ^(CGContextRef c, CGRect r) {
        CGFloat w = r.size.width, h = r.size.height;
        CGContextMoveToPoint(c, w*0.14, h*0.40); CGContextAddLineToPoint(c, w*0.34, h*0.40);
        CGContextAddLineToPoint(c, w*0.54, h*0.22); CGContextAddLineToPoint(c, w*0.54, h*0.78);
        CGContextAddLineToPoint(c, w*0.34, h*0.60); CGContextAddLineToPoint(c, w*0.14, h*0.60); CGContextClosePath(c); CGContextFillPath(c);
        CGContextMoveToPoint(c, w*0.68, h*0.38); CGContextAddLineToPoint(c, w*0.88, h*0.62); CGContextStrokePath(c);
        CGContextMoveToPoint(c, w*0.88, h*0.38); CGContextAddLineToPoint(c, w*0.68, h*0.62); CGContextStrokePath(c);
    });
}

// ============================================================
// 4. 独立音量系统与播放核心
// ============================================================

static void setupAudioSession(void) {
    AVAudioSession *s = [AVAudioSession sharedInstance];
    NSError *err = nil;
    // 关键：MixWithOthers 允许游戏音频和音乐同时播放
    [s setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&err];
    if (err) NSLog(@"[MCPlugin] 音频会话设置失败: %@", err);
    [s setActive:YES error:&err];
    NSLog(@"[MCPlugin] 独立音量系统已就绪");
}

static void applyMusicVolume(void) {
    if (!gPlayer) return;
    if (gMuted) {
        gPlayer.volume = 0.0f;
    } else {
        gPlayer.volume = gMusicVolume;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gVolValueLbl) gVolValueLbl.text = gMuted ? @"静音" : [NSString stringWithFormat:@"%d%%", (int)(gMusicVolume * 100)];
        if (gMuteBtn) [gMuteBtn setImage:(gMuted ? iconMute(18, cSub()) : iconVolume(18, cSub())) forState:UIControlStateNormal];
    });
}

static NSArray *parseLRC(NSString *text) {
    if (!text || text.length == 0) return @[];
    NSMutableArray *out = [NSMutableArray array];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d+):(\\d+)(?:\\.(\\d+))?\\](.*)" options:0 error:nil];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        NSTextCheckingResult *m = [re firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if (!m) continue;
        NSInteger min = [[line substringWithRange:[m rangeAtIndex:1]] integerValue];
        NSInteger sec = [[line substringWithRange:[m rangeAtIndex:2]] integerValue];
        NSString *msStr = @"0";
        if (m.numberOfRanges > 3 && [m rangeAtIndex:3].location != NSNotFound) msStr = [line substringWithRange:[m rangeAtIndex:3]];
        NSInteger ms = [msStr integerValue];
        NSTimeInterval t = min * 60 + sec + ms / 100.0;
        NSString *txt = [[line substringWithRange:[m rangeAtIndex:4]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (txt.length == 0) continue;
        [out addObject:@{@"time": @(t), @"text": txt}];
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"time"] compare:b[@"time"]]; }];
    return out;
}

static void playIndex(NSInteger idx) {
    if (!gSongs || idx < 0 || idx >= (NSInteger)gSongs.count) return;
    NSDictionary *song = gSongs[idx];
    NSString *songId = song[@"id"];
    NSString *title = song[@"title"] ?: @"未知歌曲";
    NSString *artist = song[@"artist"] ?: @"未知艺术家";

    NSString *urlStr = [NSString stringWithFormat:@"https://music.163.com/song/media/outer/url?id=%@.mp3", songId];
    NSURL *url = [NSURL URLWithString:urlStr];

    if (gPlayer) { [gPlayer stop]; gPlayer = nil; }
    NSError *err = nil;
    gPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    if (err) { NSLog(@"[MCPlugin] 播放失败: %@", err); return; }

    gPlayer.numberOfLoops = 0;
    [gPlayer prepareToPlay];
    applyMusicVolume();
    [gPlayer play];
    gIndex = idx;
    gLyricIdx = -1;

    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *lrcPath = [docs stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.lrc", songId]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:lrcPath]) {
        NSString *lrcText = [NSString stringWithContentsOfFile:lrcPath encoding:NSUTF8StringEncoding error:nil];
        gLyrics = parseLRC(lrcText);
    } else { gLyrics = @[]; }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (gTitleLbl) gTitleLbl.text = title;
        if (gArtistLbl) gArtistLbl.text = artist;
        if (gLyricLbl) gLyricLbl.text = @"";
        if (gPlayBtn) [gPlayBtn setImage:iconPause(28, [UIColor whiteColor]) forState:UIControlStateNormal];
    });
}

static void togglePlay(void) {
    if (!gPlayer) { playIndex(gIndex); return; }
    if (gPlayer.isPlaying) {
        [gPlayer pause];
        if (gPlayBtn) [gPlayBtn setImage:iconPlay(28, [UIColor whiteColor]) forState:UIControlStateNormal];
    } else {
        [gPlayer play];
        if (gPlayBtn) [gPlayBtn setImage:iconPause(28, [UIColor whiteColor]) forState:UIControlStateNormal];
    }
}

static void playNext(void) {
    if (!gSongs.count) return;
    NSInteger n = gIndex + 1;
    if (n >= (NSInteger)gSongs.count) n = 0;
    playIndex(n);
}

static void playPrev(void) {
    if (!gSongs.count) return;
    NSInteger n = gIndex - 1;
    if (n < 0) n = (NSInteger)gSongs.count - 1;
    playIndex(n);
}

static void refreshLyrics(void) {
    if (!gLyrics || gLyrics.count == 0 || !gPlayer) return;
    NSTimeInterval cur = gPlayer.currentTime;
    NSInteger idx = -1;
    for (NSInteger i = 0; i < (NSInteger)gLyrics.count; i++) {
        if (cur >= [gLyrics[i][@"time"] doubleValue]) idx = i; else break;
    }
    if (idx != gLyricIdx && idx >= 0) {
        gLyricIdx = idx;
        NSString *txt = gLyrics[idx][@"text"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!gLyricLbl) return;
            [UIView transitionWithView:gLyricLbl duration:0.35 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{ gLyricLbl.text = txt; } completion:nil];
        });
    }
}

// ============================================================
// 5. 事件处理 Target 类
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
        case 4: // 关闭面板
            [UIView animateWithDuration:0.28 animations:^{
                gPanel.alpha = 0; gPanel.transform = CGAffineTransformMakeScale(0.9, 0.9);
            } completion:^(BOOL f) {
                gPanel.hidden = YES; gPanel.transform = CGAffineTransformIdentity; gPanelOpen = NO;
            }];
            break;
        case 5: // 悬浮球
            gPanelOpen = !gPanelOpen;
            if (gPanelOpen) {
                gPanel.hidden = NO;
                [UIView animateWithDuration:0.38 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    gPanel.alpha = 1.0; gPanel.transform = CGAffineTransformIdentity;
                } completion:nil];
                if (!gPlayer) playIndex(gIndex);
            } else {
                [UIView animateWithDuration:0.25 animations:^{
                    gPanel.alpha = 0; gPanel.transform = CGAffineTransformMakeScale(0.9, 0.9);
                } completion:^(BOOL f) {
                    gPanel.hidden = YES; gPanel.transform = CGAffineTransformIdentity;
                }];
            }
            break;
        case 6: gMuted = !gMuted; applyMusicVolume(); break; // 静音
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
// 6. UI 构建函数
// ============================================================

static UIButton *makeButton(CGRect frame, NSInteger tag) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame; b.tag = tag;
    [b addTarget:gHandler action:@selector(onTap:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void buildUI(void) {
    if (gWindow || gUIInitialized) return;
    gUIInitialized = YES;
    gHandler = [[MCUIHandler alloc] init];

    CGRect screen = [UIScreen mainScreen].bounds;
    gWindow = [[UIWindow alloc] initWithFrame:screen];
    gWindow.windowLevel = UIWindowLevelAlert + 100;
    gWindow.backgroundColor = [UIColor clearColor];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    gWindow.rootViewController = vc;

    // 悬浮球
    gFloatBtn = makeButton(CGRectMake(screen.size.width - 66, 130, 48, 48), 5);
    gFloatBtn.backgroundColor = cAccent();
    gFloatBtn.layer.cornerRadius = 24;
    gFloatBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    gFloatBtn.layer.shadowOpacity = 0.45; gFloatBtn.layer.shadowRadius = 10; gFloatBtn.layer.shadowOffset = CGSizeMake(0, 4);
    [gFloatBtn setImage:iconNote(24, [UIColor whiteColor]) forState:UIControlStateNormal];
    [vc.view addSubview:gFloatBtn];

    // 主面板
    CGFloat pw = 320, ph = 560;
    gPanel = [[UIView alloc] initWithFrame:CGRectMake((screen.size.width - pw) / 2, (screen.size.height - ph) / 2 - 20, pw, ph)];
    gPanel.backgroundColor = cBg();
    gPanel.layer.cornerRadius = 22;
    gPanel.layer.shadowColor = [UIColor blackColor].CGColor;
    gPanel.layer.shadowOpacity = 0.6; gPanel.layer.shadowRadius = 24; gPanel.layer.shadowOffset = CGSizeMake(0, 12);
    gPanel.hidden = YES; gPanel.alpha = 0;
    [vc.view addSubview:gPanel];

    // 关闭按钮
    gCloseBtn = makeButton(CGRectMake(pw - 46, 16, 30, 30), 4);
    [gCloseBtn setImage:iconClose(16, cSub()) forState:UIControlStateNormal];
    [gPanel addSubview:gCloseBtn];

    // 封面
    gCover = [[UIImageView alloc] initWithFrame:CGRectMake((pw - 200) / 2, 56, 200, 200)];
    gCover.backgroundColor = cSurface(); gCover.layer.cornerRadius = 18; gCover.layer.masksToBounds = YES;
    gCover.contentMode = UIViewContentModeCenter; gCover.image = iconNote(60, cSub());
    [gPanel addSubview:gCover];

    // 标题、艺术家、歌词
    gTitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 272, pw - 40, 26)];
    gTitleLbl.textColor = cText(); gTitleLbl.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; gTitleLbl.textAlignment = NSTextAlignmentCenter; gTitleLbl.text = @"未在播放";
    [gPanel addSubview:gTitleLbl];

    gArtistLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 302, pw - 40, 20)];
    gArtistLbl.textColor = cSub(); gArtistLbl.font = [UIFont systemFontOfSize:13]; gArtistLbl.textAlignment = NSTextAlignmentCenter; gArtistLbl.text = @"--";
    [gPanel addSubview:gArtistLbl];

    gLyricLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 332, pw - 40, 44)];
    gLyricLbl.textColor = cSub(); gLyricLbl.font = [UIFont systemFontOfSize:13]; gLyricLbl.textAlignment = NSTextAlignmentCenter; gLyricLbl.numberOfLines = 2; gLyricLbl.text = @"";
    [gPanel addSubview:gLyricLbl];

    // 进度条与时间
    gProgress = [[UISlider alloc] initWithFrame:CGRectMake(20, 392, pw - 40, 20)];
    gProgress.minimumValue = 0; gProgress.maximumValue = 1; gProgress.value = 0;
    gProgress.minimumTrackTintColor = cAccent(); gProgress.maximumTrackTintColor = cSurface();
    [gProgress addTarget:gHandler action:@selector(onProgress:) forControlEvents:UIControlEventValueChanged];
    [gPanel addSubview:gProgress];

    gTimeLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 414, pw - 40, 16)];
    gTimeLbl.textColor = cSub(); gTimeLbl.font = [UIFont systemFontOfSize:11]; gTimeLbl.textAlignment = NSTextAlignmentCenter; gTimeLbl.text = @"0:00 / 0:00";
    [gPanel addSubview:gTimeLbl];

    // 控制按钮
    gPrevBtn = makeButton(CGRectMake(54, 448, 48, 48), 2);
    [gPrevBtn setImage:iconPrev(26, cText()) forState:UIControlStateNormal];
    [gPanel addSubview:gPrevBtn];

    gPlayBtn = makeButton(CGRectMake((pw - 64) / 2, 442, 64, 64), 1);
    gPlayBtn.backgroundColor = cAccent(); gPlayBtn.layer.cornerRadius = 32;
    gPlayBtn.layer.shadowColor = cAccent().CGColor; gPlayBtn.layer.shadowOpacity = 0.5; gPlayBtn.layer.shadowRadius = 12; gPlayBtn.layer.shadowOffset = CGSizeMake(0, 4);
    [gPlayBtn setImage:iconPlay(28, [UIColor whiteColor]) forState:UIControlStateNormal];
    [gPanel addSubview:gPlayBtn];

    gNextBtn = makeButton(CGRectMake(pw - 102, 448, 48, 48), 3);
    [gNextBtn setImage:iconNext(26, cText()) forState:UIControlStateNormal];
    [gPanel addSubview:gNextBtn];

    // 独立音量区
    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(20, 514, pw - 40, 1)];
    divider.backgroundColor = cSurface(); [gPanel addSubview:divider];

    UILabel *volTitle = [[UILabel alloc] initWithFrame:CGRectMake(20, 520, 100, 14)];
    volTitle.text = @"音乐音量"; volTitle.textColor = cSub(); volTitle.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    [gPanel addSubview:volTitle];

    gVolValueLbl = [[UILabel alloc] initWithFrame:CGRectMake(pw - 80, 520, 60, 14)];
    gVolValueLbl.text = @"30%"; gVolValueLbl.textColor = cAccent(); gVolValueLbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold]; gVolValueLbl.textAlignment = NSTextAlignmentRight;
    [gPanel add),Subview:gVolValueLbl];

    gM dispatchuteBtn = makeButton(CGRect_getMake(20, 538, 28_main, 28), 6);
    [g_queueMuteBtn setImage:iconVolume(18, cSub()) forState:UIControlStateNormal];
    [gPanel addSubview:gMuteBtn];

    gVolume = [[UISlider alloc] initWithFrame:CGRectMake(56, 542, pw - 76, 20)];
    gVolume.minimumValue = 0; gVolume.maximumValue = 1; gVolume.value = gMusicVolume;
    gVolume.minimumTrackTintColor = cAccent(); gVolume.maximumTrackTintColor = cSurface();
    [gVolume addTarget:gHandler action:@selector(onVolume:) forControlEvents:UIControlEventValueChanged];
    [gPanel addSubview:gVolume];

    [gWindow makeKeyAndVisible];
}

// ============================================================
// 7. 定时器与生命周期
// ============================================================

static void startTimer(void) {
    if (gTimer) [gTimer invalidate];
    gTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *t) {
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
        refreshLyrics();
    }];
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC(), ^{
            buildUI();
            startTimer();
        });
    });
}

%end

// ============================================================
// 8. 入口
// ============================================================

%ctor {
    NSLog(@"[MCPlugin] 加载中...");
    setupAudioSession();

    // 替换为你的歌曲 ID
    gSongs = @[
        @{@"id": @"186016",     @"title": @"晴天",           @"artist": @"周杰伦"},
        @{@"id": @"1330348068", @"title": @"起风了",         @"artist": @"买辣椒也用券"},
    ];

    NSLog(@"[MCPlugin] 独立音量系统初始化完成");
}
