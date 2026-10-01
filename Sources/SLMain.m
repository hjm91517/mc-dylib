#import <UIKit/UIKit.h>
#import <Python/Python.h>
#import <stdlib.h>
#import "SLFloatWindow.h"
#import "SLPythonBridge.h"
#import "SLHookHelper.h"
#import "SLLogManager.h"
#import "SLHotkeyManager.h"

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
    NSString *pyDir = [doc stringByAppendingPathComponent:@"SLNetEaseMC/pylib"];
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
    // 同时额外校验 Frameworks/Python.framework/Resources/lib/python3.* 是否真实可用，
    // 避免在网易/改包环境下因为 Python 资源不完整导致崩溃。
    NSString *fwRes = [bundlePath stringByAppendingPathComponent:@"Frameworks/Python.framework/Resources"];
    NSString *fwRoot = [bundlePath stringByAppendingPathComponent:@"Frameworks/Python.framework"];
    BOOL hasPythonFramework = [fm fileExistsAtPath:fwRoot] || [fm fileExistsAtPath:fwRes];
    if (!hasPythonFramework) {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"Init"
                                   message:@"App 内未找到 Frameworks/Python.framework，跳过 Python 初始化以防止崩溃。"];
        return;
    }

    NSString *libDir = [fwRes stringByAppendingPathComponent:@"lib"];
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
                                   message:[NSString stringWithFormat:@"Python.framework 资源异常: %@，未发现 python3.x 目录，跳过初始化（BundleID=%@）", fwRes, bundleId]];
        return;
    }

    setenv("PYTHONHOME", fwRes.UTF8String, 1);
    setenv("PYTHONPATH", [[paths valueForKey:@"description"] componentsJoinedByString:@":"].UTF8String, 1);
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
