#import <Foundation/Foundation.h>

@interface SLHotkeyManager : NSObject
+ (instancetype)sharedInstance;
- (void)rebuildAll;
- (void)removeHotkeyForFeatureId:(NSString *)fid;
@end
