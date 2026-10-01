#import "FSLJSEngine.h"
#import "FSLFunction.h"
#import "FSLFunctionManager.h"
#import "FSLCommon.h"
#import <JavaScriptCore/JavaScriptCore.h>

@implementation FSLJSEngine

+ (void)runFunction:(FSLFunction *)fn {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            __weak FSLFunction *wfn = fn;
            JSContext *ctx = [[JSContext alloc] init];
            ctx.name = [NSString stringWithFormat:@"FSL-%@", fn.name];

            ctx.exceptionHandler = ^(JSContext *c, JSValue *exception) {
                FSLShowAlert([NSString stringWithFormat:@"「%@」JS 运行出错", wfn.name],
                             [exception toString]);
            };

            ctx[@"alert"] = ^(JSValue *msg) {
                FSLShowAlert(wfn.name, [msg toString]);
            };
            ctx[@"log"] = ^(JSValue *msg) {
                NSLog(@"[FSL-JS][%@] %@", wfn.name, [msg toString]);
            };
            ctx[@"console"] = @{
                @"log":   ^(JSValue *m) { NSLog(@"[FSL-JS][%@] %@", wfn.name, [m toString]); },
                @"warn":  ^(JSValue *m) { NSLog(@"[FSL-JS][%@][warn] %@", wfn.name, [m toString]); },
                @"error": ^(JSValue *m) { NSLog(@"[FSL-JS][%@][error] %@", wfn.name, [m toString]); }
            };
            ctx[@"getConfig"] = ^id(NSString *key) {
                return [[FSLFunctionManager shared] configValueForKey:key function:wfn];
            };
            ctx[@"shouldStop"] = ^BOOL {
                return [[FSLFunctionManager shared] shouldStop:wfn];
            };

            [ctx evaluateScript:fn.source withSourceURL:[NSURL URLWithString:fn.name]];
        }
        [[FSLFunctionManager shared] markFinished:fn];
    });
}

@end
