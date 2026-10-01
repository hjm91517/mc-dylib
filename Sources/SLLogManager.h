#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SLLogType) {
    SLLogTypeRun    = 0,
    SLLogTypeError  = 1,
    SLLogTypeCrash  = 2,
    SLLogTypeAI     = 3,
    SLLogTypeSystem = 4
};

@interface SLLogEntry : NSObject <NSSecureCoding>
@property (nonatomic, assign) SLLogType type;
@property (nonatomic, copy)   NSString *featureName;
@property (nonatomic, copy)   NSString *message;
@property (nonatomic, strong) NSDate   *timestamp;
@end

@interface SLLogManager : NSObject
+ (instancetype)sharedInstance;
- (void)log:(SLLogType)type feature:(NSString *)feature message:(NSString *)message;
- (NSArray<SLLogEntry *> *)allLogs;
- (NSArray<SLLogEntry *> *)logsOfType:(SLLogType)type;
- (void)clearAll;
- (void)installCrashHandler;
@end
