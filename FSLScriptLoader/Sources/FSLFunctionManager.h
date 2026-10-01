#import <Foundation/Foundation.h>

@class FSLFunction;

extern NSNotificationName const FSLFunctionsDidChangeNotification; ///< 功能列表变化（增删改）
extern NSNotificationName const FSLRunStateDidChangeNotification;  ///< 运行状态变化

@interface FSLFunctionManager : NSObject

+ (instancetype)shared;

@property (nonatomic, strong, readonly) NSMutableArray<FSLFunction *> *functions;

- (void)addFunction:(FSLFunction *)fn;
- (void)deleteFunction:(FSLFunction *)fn;
- (void)save;

- (BOOL)isRunning:(FSLFunction *)fn;
- (void)toggleRun:(FSLFunction *)fn;
- (void)runFunction:(FSLFunction *)fn;
- (void)requestStop:(FSLFunction *)fn;
- (BOOL)shouldStop:(FSLFunction *)fn;
- (void)markFinished:(FSLFunction *)fn;

/// 取参数值：优先用户设置，否则脚本中声明的默认值
- (id)configValueForKey:(NSString *)key function:(FSLFunction *)fn;

/// 数据目录（Documents/FSLScriptLoader）
- (NSString *)storeDir;

@end
