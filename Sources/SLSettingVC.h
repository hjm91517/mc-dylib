#import <UIKit/UIKit.h>
#import "SLModel.h"

@interface SLSettingVC : UIViewController
- (instancetype)initWithFeature:(SLFeature *)feature;
@property (nonatomic, copy) void (^onSave)(void);
@end
