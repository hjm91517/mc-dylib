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

    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSFileManager *fm = [NSFileManager defaultManager];

    // 修复：Py_Initialize 之前必须设置 PYTHONHOME/PYTHONPATH，否则必崩；
    // 且动态探测 python3.x 目录，不再硬编码 3.11
    NSString *fwRes = [bundlePath stringByAppendingPathComponent:@"Frameworks/Python.framework/Resources"];
    if ([fm fileExistsAtPath:fwRes]) {
        setenv("PYTHONHOME", fwRes.UTF8String, 1);
        NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithObject:pyDir];
        NSString *lib = [fwRes stringByAppendingPathComponent:@"lib"];
        for (NSString *sub in [fm contentsOfDirectoryAtPath:lib error:nil] ?: @[]) {
            if (![sub hasPrefix:@"python3"]) continue;
            NSString *p = [lib stringByAppendingPathComponent:sub];
            [paths addObject:p];
            [paths addObject:[p stringByAppendingPathComponent:@"lib-dynload"]];
        }
        setenv("PYTHONPATH", [paths componentsJoinedByString:@":"].UTF8String, 1);
        setenv("PYTHONDONTWRITEBYTECODE", "1", 1);
        setenv("PYTHONUNBUFFERED", "1", 1);
    } else {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"Init"
                                   message:@"App 内未找到 Frameworks/Python.framework"];
    }

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
            SLInitPython();
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
