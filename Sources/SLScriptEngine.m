#import "SLScriptEngine.h"
#import <Python/Python.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <UIKit/UIKit.h>
#import <string.h>
#import "SLLogManager.h"

/// Python.framework 为 weak 链接，未嵌入时符号为 NULL
static BOOL SLPythonLinked(void) {
    return &Py_Initialize != NULL;
}

@implementation SLScriptEngine

+ (BOOL)runScript:(NSString *)script
             type:(NSString *)type
        variables:(NSDictionary *)vars
      featureName:(NSString *)name {
    if (!script.length) {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:name message:@"脚本为空"];
        return NO;
    }
    [[SLLogManager sharedInstance] log:SLLogTypeRun feature:name
                               message:[NSString stringWithFormat:@"开始执行 %@ 脚本", [type uppercaseString]]];
    BOOL ok = NO;
    @try {
        if ([type isEqualToString:@"js"])      ok = [self runJS:script variables:vars featureName:name];
        else if ([type isEqualToString:@"py"]) ok = [self runPython:script variables:vars featureName:name];
        else {
            [[SLLogManager sharedInstance] log:SLLogTypeError feature:name
                                       message:[NSString stringWithFormat:@"未知脚本类型: %@", type]];
            return NO;
        }
    } @catch (NSException *e) {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:name
                                   message:[NSString stringWithFormat:@"异常: %@", e.reason]];
        return NO;
    }
    [[SLLogManager sharedInstance] log:(ok ? SLLogTypeRun : SLLogTypeError)
                               feature:name message:(ok ? @"执行成功" : @"执行失败")];
    return ok;
}

#pragma mark - Python

/// Python 中 `$` 不是合法标识符字符：把脚本里的 $var 统一替换为 var。
/// （`$` 本身不可能出现在合法 Python 代码中，因此替换是安全的；
///   唯一例外是字符串字面量里手写的 "$xxx"，会被一并替换，请注意。）
static NSString *SLStripPythonDollarVars(NSString *script) {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\$(\\w+)"
                                                                        options:0 error:nil];
    return [re stringByReplacingMatchesInString:script options:0
                                          range:NSMakeRange(0, script.length) withTemplate:@"$1"];
}

+ (BOOL)runPython:(NSString *)script variables:(NSDictionary *)vars featureName:(NSString *)name {
    if (!SLPythonLinked()) {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:name
                                   message:@"未找到 Python.framework，无法运行 PY 脚本（JS 不受影响）"];
        return NO;
    }
    if (!Py_IsInitialized()) {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:name message:@"Python 未初始化"];
        return NO;
    }
    PyGILState_STATE state = PyGILState_Ensure();

    NSMutableString *prelude = [NSMutableString string];
    for (NSString *key in vars) {
        if (!key.length) continue;
        id val = vars[key];
        NSString *pyKey = [key hasPrefix:@"$"] ? [key substringFromIndex:1] : key;
        [prelude appendFormat:@"%@ = %@\n", pyKey, [self pythonReprFromObject:val]];
    }

    NSString *body = SLStripPythonDollarVars(script);
    NSString *full = [prelude stringByAppendingString:body];
    int rc = PyRun_SimpleString([full UTF8String]);
    PyGILState_Release(state);

    if (rc != 0) {
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:name
                                   message:[NSString stringWithFormat:@"Python 返回码 %d（详细错误见控制台 stderr）", rc]];
        return NO;
    }
    return YES;
}

+ (NSString *)pythonReprFromObject:(id)obj {
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id v in obj) [parts addObject:[self pythonReprFromObject:v]];
        return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@", "]];
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id k in obj)
            [parts addObject:[NSString stringWithFormat:@"%@: %@",
                              [self pythonReprFromObject:k], [self pythonReprFromObject:obj[k]]]];
        return [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@", "]];
    }
    if ([obj isKindOfClass:[NSString class]]) {
        // 用 JSON 转义生成安全的 Python 字符串字面量
        NSData *d = [NSJSONSerialization dataWithJSONObject:@[obj] options:0 error:nil];
        NSString *arr = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        if (arr.length >= 2) return [arr substringWithRange:NSMakeRange(1, arr.length - 2)];
        return @"''";
    }
    if ([obj isKindOfClass:[NSNumber class]]) {
        const char *t = [obj objCType];
        if (strcmp(t, @encode(BOOL)) == 0 || strcmp(t, @encode(char)) == 0)
            return [obj boolValue] ? @"True" : @"False";
        return [obj stringValue];
    }
    return @"None";
}

#pragma mark - JavaScript

+ (BOOL)runJS:(NSString *)script variables:(NSDictionary *)vars featureName:(NSString *)name {
    JSContext *context = [[JSContext alloc] init];
    for (NSString *key in vars) {
        if (!key.length) continue;
        id val = vars[key];
        context[key] = val;
        // 脚本里写的是 $变量名，注入带 $ 的别名
        if (![key hasPrefix:@"$"]) {
            context[[NSString stringWithFormat:@"$%@", key]] = val;
        }
    }
    context[@"sl_log"] = ^(JSValue *msg) {
        [[SLLogManager sharedInstance] log:SLLogTypeRun feature:name message:[msg toString] ?: @""];
    };
    context[@"sl_alert"] = ^(JSValue *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *a = [UIAlertController alertControllerWithTitle:name
                                                                       message:[msg toString]
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            // 修复：选面积最大的全屏窗口，跳过 56pt 悬浮窗，避免弹窗被裁切
            UIWindow *kw = nil;
            CGFloat bestArea = 0;
            for (UIWindow *w in UIApplication.sharedApplication.windows) {
                CGRect r = w.bounds;
                CGFloat area = r.size.width * r.size.height;
                if (area > bestArea) { bestArea = area; kw = w; }
            }
            UIViewController *root = kw.rootViewController;
            while (root.presentedViewController) root = root.presentedViewController;
            [root presentViewController:a animated:YES completion:nil];
        });
    };
    __block BOOL failed = NO;
    context.exceptionHandler = ^(JSContext *ctx, JSValue *exception) {
        failed = YES;
        [[SLLogManager sharedInstance] log:SLLogTypeError feature:name
                                   message:[NSString stringWithFormat:@"JS 异常: %@", [exception toString]]];
    };
    [context evaluateScript:script];
    return !failed;
}
@end
