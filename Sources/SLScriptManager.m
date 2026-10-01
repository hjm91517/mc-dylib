#import "SLScriptManager.h"

@interface SLScriptManager ()
@property (nonatomic, copy, readonly) NSString *storagePath;
@end

@implementation SLScriptManager

+ (instancetype)sharedInstance {
    static SLScriptManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLScriptManager alloc] init];
    });
    return instance;
}

- (NSString *)storagePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = paths.firstObject ?: NSTemporaryDirectory();
    NSString *dir = [doc stringByAppendingPathComponent:@"SLNetEaseMC"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return [dir stringByAppendingPathComponent:@"features.plist"];
}

- (void)saveFeatures:(NSArray<SLFeature *> *)features {
    if (!features) return;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:features
                                         requiringSecureCoding:YES
                                                         error:nil];
    if (data) {
        [data writeToFile:self.storagePath atomically:YES];
    }
}

- (NSMutableArray<SLFeature *> *)loadAllFeatures {
    NSData *data = [NSData dataWithContentsOfFile:self.storagePath];
    if (!data) {
        return [NSMutableArray array];
    }

    NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSMutableArray class],
                      [SLFeature class], [NSString class], [NSDictionary class],
                      [NSMutableDictionary class], [NSNumber class], [NSDate class], nil];

    NSArray *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                            fromData:data
                                                               error:nil];
    if (![decoded isKindOfClass:[NSArray class]]) {
        return [NSMutableArray array];
    }

    NSMutableArray *features = [NSMutableArray arrayWithCapacity:decoded.count];
    for (id obj in decoded) {
        if ([obj isKindOfClass:[SLFeature class]]) {
            [features addObject:obj];
        }
    }
    return features;
}

- (void)saveFeature:(SLFeature *)feature {
    if (!feature) return;

    NSMutableArray *items = [self loadAllFeatures];
    BOOL replaced = NO;
    for (NSUInteger i = 0; i < items.count; i++) {
        SLFeature *item = items[i];
        if ([item.featureId isEqualToString:feature.featureId]) {
            items[i] = feature;
            replaced = YES;
            break;
        }
    }
    if (!replaced) {
        [items addObject:feature];
    }

    [self saveFeatures:items];
}

- (void)deleteFeature:(SLFeature *)feature {
    if (!feature || !feature.featureId.length) return;

    NSMutableArray *items = [self loadAllFeatures];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"featureId != %@", feature.featureId];
    NSArray *filtered = [items filteredArrayUsingPredicate:predicate];
    [self saveFeatures:filtered];
}

@end
