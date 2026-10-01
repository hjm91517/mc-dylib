#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, FSLScriptType) {
    FSLScriptTypeJS = 0,
    FSLScriptTypePython = 1
};

/// 一个"功能"：名称 + 脚本类型 + 脚本源码 + 开关/快捷键状态 + 参数值
@interface FSLFunction : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, assign) FSLScriptType type;
@property (nonatomic, assign) BOOL enabled;        ///< 功能总开关
@property (nonatomic, assign) BOOL hotkeyEnabled;  ///< 是否在屏幕上显示独立快捷键
@property (nonatomic, assign) CGPoint hotkeyPosition; ///< 快捷键位置 (0,0) = 自动
@property (nonatomic, strong) NSMutableDictionary *configValues; ///< @config 参数值

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;
- (NSString *)typeBadge; // @"JS" / @"PY"

@end
