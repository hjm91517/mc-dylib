#import <UIKit/UIKit.h>
#import <Python/Python.h>
#import <stdlib.h>
#import "SLFloatWindow.h"
#import "SLPythonBridge.h"
#import "SLHookHelper.h"
#import "SLLogManager.h"
#import "SLHotkeyManager.h"
#import "SLConstants.h"

static id gLaunchObserver = nil;

static void SLInitPython(void) {
    // weak 链接：未嵌入 Python.framework 时符号为 NULL，直接跳过（JS 不受影响）
    if (&Py_Initialize == NULL) {
        [[SLLogManager sharedInstance] log:SLLogTypeSystem feature:@"Init"
                                   message:@"未检测到 Python.framework，PY 脚本不可用（JS 正常）"];
        return;
    }
    if (Py_IsInitialized()) return;

    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    // 修复：使用统一项目目录常量，避免与仓库 / Constants 不一致
    NSString *pyDir = [[doc stringByAppendingPathComponent:kProjectFolderName] stringByAppendingPathComponent:@"pylib"];
    [[NSFileManager defaultManager] createDirectoryAtPath:pyDir
                              withIntermediateDirectories:YES attributes:nil error:nil];

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundlePath = [mainBundle bundlePath];
    NSString *bundleId = [mainBundle bundleIdentifier] ?: @"";
    NSString *buildVer = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
    NSFileManager *fm = [NSFileManager defaultManager];

    // 兼容网易版基岩我的世界/自定义改包（如 com.YantPacks-iOS@YiXiang.mc）
    if ([bundleId containsString:@"YantPacks"] ||
        [bundleId containsString:@"YiXiang"] ||
        [bundleId containsString:@"netease"] ||
        [bundleId containsString:@"minecraft"]) {
        [[SLLogManager sharedInstance] log:SLLogTypeSystem feature:@"Init"
                                   message:[NSString stringWithFormat:@"检测到目标包: %@ (%@)", bundleId, buildVer]];
    }

    // 修复：Py_Initialize 之前必须设置 PYTHONHOME / PYTHONPATH，否则必崩。
    // 多路径查找 Python.framework（Frameworks/、App 根目录、Documents），
    // 找不到时把搜索过的路径写进日志，便于排查注入位置。
    NSString *fwRoot = nil;
    NSMutableArray *searched = [NSMutableArray array];
    NSArray<NSString *> *candidates = @[
        [bundlePath stringByAppendingPathComponent:@"Frameworks/Python.framework"],
        [bundlePath stringByAppendingPathComponent:@"Python.framework"],
        [doc stringByAppendingPathComponent:@"Python.framework"],
    ];
    for (NSString *c in candidates) {
        if ([fm fileExistsAtPath:c]) {
            fwRoot = c;
            break;
        }
        [searched addObject:c];
    }
    if (!fwRoot) {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"Init"
                                   message:[NSString stringWithFormat:@"未找到 Python.framework（已搜索: %@），跳过 Python 初始化（JS 正常）",
                                            [searched componentsJoinedByString:@" / "]]];
        return;
    }
    // 兼容两种 framework 布局：
    //   布局 A（BeeWare 等标准）：framework/Resources/lib/python3.x  → PYTHONHOME=Resources
    //   布局 B（无 Resources）：   framework/lib/python3.x            → PYTHONHOME=framework 根
    NSString *fwRes = [fwRoot stringByAppendingPathComponent:@"Resources"];
    NSString *libDir = nil;
    NSString *pythonHome = nil;
    if ([fm fileExistsAtPath:fwRes]) {
        libDir = [fwRes stringByAppendingPathComponent:@"lib"];
        pythonHome = fwRes;
    } else {
        libDir = [fwRoot stringByAppendingPathComponent:@"lib"];
        pythonHome = fwRoot;
    }

    BOOL foundPythonLib = NO;
    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithObject:pyDir];
    NSArray *entries = [fm contentsOfDirectoryAtPath:libDir error:nil] ?: @[];
    for (NSString *sub in entries) {
        if (![sub hasPrefix:@"python3"]) continue;
        NSString *p = [libDir stringByAppendingPathComponent:sub];
        [paths addObject:p];
        NSString *dynload = [p stringByAppendingPathComponent:@"lib-dynload"];
        if ([fm fileExistsAtPath:dynload]) {
            [paths addObject:dynload];
        }
        foundPythonLib = YES;
    }

    if (!foundPythonLib) {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"Init"
                                   message:[NSString stringWithFormat:@"Python.framework 资源异常: %@ 下未发现 python3.x 标准库目录（已检查 %@ 与 %@），跳过初始化（BundleID=%@）",
                                            fwRoot, fwRes, libDir, bundleId]];
        return;
    }

    setenv("PYTHONHOME", pythonHome.UTF8String, 1);
    setenv("PYTHONPATH", [paths componentsJoinedByString:@":"].UTF8String, 1);
    setenv("PYTHONDONTWRITEBYTECODE", "1", 1);
    setenv("PYTHONUNBUFFERED", "1", 1);

    Py_Initialize();
    if (!Py_IsInitialized()) {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"Init" message:@"Py_Initialize 失败"]; 
        return;
    }

    NSString *code = [NSString stringWithFormat:
        @"import sys\n"
        @"sys.path.insert(0, '%@')\n", pyDir];
    PyRun_SimpleString([code UTF8String]);

    [SLPythonBridge registerAll];
    [[SLLogManager sharedInstance] log:SLLogTypeSystem feature:@"Init" message:@"Python 初始化完成"]; 
}

__attribute__((constructor))
static void SLNetEaseMCInit(void) {
    [[SLLogManager sharedInstance] installCrashHandler];
    [SLHookHelper installAntiDetectionHooks];

    gLaunchObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
        @try {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                @try {
                    SLInitPython();
                } @catch (NSException *e) {
                    [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"Init"
                                               message:[NSString stringWithFormat:@"Python 初始化失败: %@", e.reason]];
                }
            });
        } @catch (NSException *e) {
            [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"Init"
                                       message:[NSString stringWithFormat:@"Python 初始化失败: %@", e.reason]];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[SLFloatWindow sharedInstance] show];
            [[SLHotkeyManager sharedInstance] rebuildAll];
        });
    }];
}
