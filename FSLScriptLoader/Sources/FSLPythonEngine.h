#import <Foundation/Foundation.h>

@class FSLFunction;

@interface FSLPythonEngine : NSObject

/// 异步运行 Python 脚本。
/// 通过 dlopen 运行时加载 Python.framework（BeeWare Python-Apple-support），
/// 未随 App 嵌入该 framework 时会弹窗提示，不影响 dylib 加载。
/// 注入模块 fsl: fsl.get_config(key) / fsl.should_stop() / fsl.alert(msg) / fsl.log(msg)
+ (void)runFunction:(FSLFunction *)fn;

@end
