#import <Foundation/Foundation.h>
#import "FSLFunction.h"

/// 一个可配置参数（从脚本注释 @config 自动识别）
@interface FSLConfigItem : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *type; // bool / number / text
@property (nonatomic, strong) id defaultValue;
@end

@interface FSLConfigParser : NSObject

/// 解析脚本中的 @config 声明：
///   JS:     //@config {"key":"speed","type":"number","default":5,"label":"速度"}
///   Python: #@config {"key":"speed","type":"number","default":5,"label":"速度"}
+ (NSArray<FSLConfigItem *> *)parseSource:(NSString *)source type:(FSLScriptType)type;

@end
