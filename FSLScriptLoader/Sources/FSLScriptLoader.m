#import "FSLCore.h"

/// dylib 注入 App 后的入口：延迟几秒等 App 窗口创建完毕再显示悬浮球
__attribute__((constructor))
static void FSLScriptLoaderInit(void) {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[FSLCore shared] setup];
        });
    }
}
