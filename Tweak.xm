// Tweak.xm - Minecraft Bedrock iOS 辅助插件
// 功能：网易云音乐后台播放（音量小）、游戏音量保持正常、材质注入

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "fishhook.h"

// ============================================================
// 1. 全局变量
// ============================================================

static AVAudioPlayer *gMusicPlayer = nil;
static AVAudioSession *gAudioSession = nil;

// 音乐音量（0.0 - 1.0），默认 0.2，即 20% 音量
static float gMusicVolume = 0.2f;

// ============================================================
// 2. 音频会话配置 —— 关键：让音乐小声，游戏声音大
// ============================================================

static void setupAudioSession() {
    gAudioSession = [AVAudioSession sharedInstance];

    NSError *error = nil;
    [gAudioSession setCategory:AVAudioSessionCategoryPlayback
                   withOptions:AVAudioSessionCategoryOptionMixWithOthers
                         error:&error];

    if (error) {
        NSLog(@"[MCPlugin] 音频会话设置失败: %@", error);
    }

    [gAudioSession setActive:YES error:&error];

    NSLog(@"[MCPlugin] 音频会话已设置：音乐音量 %.0f%%，游戏音量不变", gMusicVolume * 100);
}

// ============================================================
// 3. 网易云音乐播放
// ============================================================

static void playAudioWithUrl(NSString *urlStr);

// 方式 A：通过自建 Meting-Agent API 获取播放链接
static void playNeteaseMusic(NSString *songId) {
    NSString *apiUrl = [NSString stringWithFormat:@"http://your-server:3000/url?server=netease&type=song&id=%@", songId];

    NSURL *url = [NSURL URLWithString:apiUrl];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"[MCPlugin] 获取播放地址失败: %@", error);
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *playUrl = json[@"url"];

            if (playUrl && playUrl.length > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    playAudioWithUrl(playUrl);
                });
            } else {
                NSLog(@"[MCPlugin] 返回数据中没有播放链接: %@", json);
            }
        }];
    [task resume];
}

// 方式 B：直接拼接网易云音乐外链（部分歌曲可用，音质受限）
static void playNeteaseMusicDirect(NSString *songId) {
    NSString *playUrl = [NSString stringWithFormat:@"https://music.163.com/song/media/outer/url?id=%@.mp3", songId];
    dispatch_async(dispatch_get_main_queue(), ^{
        playAudioWithUrl(playUrl);
    });
}

// 播放音频（核心：单独设置音乐音量）
static void playAudioWithUrl(NSString *urlStr) {
    NSURL *url = [NSURL URLWithString:urlStr];
    NSError *error = nil;

    if (gMusicPlayer) {
        [gMusicPlayer stop];
        gMusicPlayer = nil;
    }

    gMusicPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];

    if (error) {
        NSLog(@"[MCPlugin] 播放器创建失败: %@", error);
        return;
    }

    // ★★★ 关键：单独设置音乐音量 ★★★
    gMusicPlayer.volume = gMusicVolume;

    // 循环播放
    gMusicPlayer.numberOfLoops = -1;

    [gMusicPlayer prepareToPlay];
    [gMusicPlayer play];

    NSLog(@"[MCPlugin] 正在播放: %@，音乐音量: %.0f%%", urlStr, gMusicVolume * 100);
}

// 调整音乐音量
static void setMusicVolume(float volume) {
    gMusicVolume = MAX(0.0f, MIN(1.0f, volume));
    if (gMusicPlayer) {
        gMusicPlayer.volume = gMusicVolume;
    }
    NSLog(@"[MCPlugin] 音乐音量已调整为: %.0f%%", gMusicVolume * 100);
}

// ============================================================
// 4. 材质注入（基于 HynisLoader 原理）
// ============================================================

static FILE *(*orig_fopen)(const char *path, const char *mode) = NULL;

static FILE *my_fopen(const char *path, const char *mode) {
    if (!path) return orig_fopen(path, mode);

    NSString *pathStr = [NSString stringWithUTF8String:path];

    if ([pathStr containsString:@"renderer/"] ||
        [pathStr containsString:@"textures/"] ||
        [pathStr containsString:@".material.bin"]) {

        NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *customTexturePath = [docsPath stringByAppendingPathComponent:@"CustomTextures"];

        NSString *relativePath = pathStr;
        NSRange rendererRange = [pathStr rangeOfString:@"renderer/"];
        if (rendererRange.location != NSNotFound) {
            relativePath = [pathStr substringFromIndex:rendererRange.location];
        }

        NSString *newPath = [customTexturePath stringByAppendingPathComponent:relativePath];

        if ([[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            NSLog(@"[MCPlugin] 材质重定向: %@ -> %@", pathStr, newPath);
            return orig_fopen([newPath UTF8String], mode);
        }
    }

    return orig_fopen(path, mode);
}

static void setupTextureInjection() {
    struct rebinding rebindings[] = {
        {"fopen", (void *)my_fopen, (void **)&orig_fopen}
    };

    int result = rebind_symbols(rebindings, 1);
    if (result == 0) {
        NSLog(@"[MCPlugin] 材质注入已成功初始化");
    } else {
        NSLog(@"[MCPlugin] 材质注入初始化失败，错误码: %d", result);
    }
}

// ============================================================
// 5. 初始化
// ============================================================

%ctor {
    NSLog(@"[MCPlugin] 插件初始化中...");

    setupAudioSession();
    setupTextureInjection();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[MCPlugin] 资源加载就绪，可以开始播放音乐");

        // playNeteaseMusic(@"1234567890");
        // playNeteaseMusicDirect(@"1234567890");
        // setMusicVolume(0.15f);
    });
}
