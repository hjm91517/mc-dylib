#import "SLScriptManager.h"

@interface SLScriptManager ()
@property (nonatomic, strong) NSString *storagePath;
@end

@implementation SLScriptManager

+ (instancetype)sharedInstance {
    static SLScriptManager *i; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[SLScriptManager alloc] init]; });
    return i;
}

- (instancetype)init {
    if (self = [super init]) {
        NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *dir = [doc stringByAppendingPathComponent:@"SLNetEaseMC"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        _storagePath = [dir stringByAppendingPathComponent:@"features.plist"];
    }
    return self;
}

- (NSMutableArray<SLFeature *> *)loadAllFeatures {
    NSData *data = [NSData dataWithContentsOfFile:self.storagePath];
    if (!data) return [NSMutableArray array];
    NSError *err;
    NSSet *set = [NSSet setWithObjects:[NSArray class], [SLFeature class],
                                       [NSMutableDictionary class], [NSDictionary class],
                                       [NSString class], [NSNumber class], [NSDate class], nil];
    NSArray *arr = [NSKeyedUnarchiver unarchivedObjectOfClasses:set fromData:data error:&err];
    return arr ? [arr mutableCopy] : [NSMutableArray array];
}

- (void)saveFeature:(SLFeature *)feature {
    NSMutableArray *all = [self loadAllFeatures];
    BOOL found = NO;
    for (NSInteger i = 0; i < all.count; i++) {
        SLFeature *existing = all[i];
        if ([existing.featureId isEqualToString:feature.featureId]) {
            all[i] = feature; found = YES; break;
        }
    }
    if (!found) [all addObject:feature];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:all
                                       requiringSecureCoding:YES error:nil];
    [data writeToFile:self.storagePath atomically:YES];
}

- (void)deleteFeature:(SLFeature *)feature {
    NSMutableArray *all = [self loadAllFeatures];
    for (SLFeature *f in [all copy]) {
        if ([f.featureId isEqualToString:feature.featureId]) { [all removeObject:f]; break; }
    }
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:all
                                       requiringSecureCoding:YES error:nil];
    [data writeToFile:self.storagePath atomically:YES];
}
@end
