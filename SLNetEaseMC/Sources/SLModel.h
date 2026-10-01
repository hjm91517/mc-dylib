#import <Foundation/Foundation.h>

@interface SLFeature : NSObject <NSSecureCoding>
@property (nonatomic, copy)   NSString *featureId;
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSString *scriptType;   // "js" / "py"
@property (nonatomic, copy)   NSString *scriptContent;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL hotkeyVisible;
@property (nonatomic, strong) NSMutableDictionary *settings;
@property (nonatomic, copy)   NSString *lastRunStatus; // "success" / "fail" / "never"
@property (nonatomic, strong) NSDate   *lastRunTime;
@end
