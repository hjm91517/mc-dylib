#import <Foundation/Foundation.h>

@class FSLFunction;

@interface FSLJSEngine : NSObject

/// 异步运行 JS 脚本（JavaScriptCore）
/// 注入 API: alert(msg) / log(msg) / console.log(msg) / getConfig(key) / shouldStop()
+ (void)runFunction:(FSLFunction *)fn;

@end
