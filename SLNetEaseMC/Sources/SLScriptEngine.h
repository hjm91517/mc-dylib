#import <Foundation/Foundation.h>

@interface SLScriptEngine : NSObject
+ (BOOL)runScript:(NSString *)script
             type:(NSString *)type
        variables:(NSDictionary *)vars
      featureName:(NSString *)name;
@end
