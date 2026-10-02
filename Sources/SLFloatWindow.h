#import <UIKit/UIKit.h>

@interface SLFloatWindow : NSObject
+ (instancetype)sharedInstance;
- (void)show;
- (void)restoreAnimated;
@end
