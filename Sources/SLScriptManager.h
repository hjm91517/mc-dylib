#import <Foundation/Foundation.h>
#import "SLModel.h"

@interface SLScriptManager : NSObject
+ (instancetype)sharedInstance;
- (NSMutableArray<SLFeature *> *)loadAllFeatures;
- (void)saveFeature:(SLFeature *)feature;
- (void)deleteFeature:(SLFeature *)feature;
@end
