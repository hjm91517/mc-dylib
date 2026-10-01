#import "SLModel.h"

@implementation SLFeature

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)init {
    if (self = [super init]) {
        _settings      = [NSMutableDictionary dictionary];
        _lastRunStatus = @"never";
        _enabled       = YES;
        _hotkeyVisible = NO;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:self.featureId     forKey:@"featureId"];
    [c encodeObject:self.name          forKey:@"name"];
    [c encodeObject:self.scriptType    forKey:@"scriptType"];
    [c encodeObject:self.scriptContent forKey:@"scriptContent"];
    [c encodeBool:self.enabled         forKey:@"enabled"];
    [c encodeBool:self.hotkeyVisible   forKey:@"hotkeyVisible"];
    [c encodeObject:self.settings      forKey:@"settings"];
    [c encodeObject:self.lastRunStatus forKey:@"lastRunStatus"];
    [c encodeObject:self.lastRunTime   forKey:@"lastRunTime"];
}

- (instancetype)initWithCoder:(NSCoder *)c {
    if (self = [super init]) {
        _featureId     = [c decodeObjectOfClass:[NSString class] forKey:@"featureId"];
        _name          = [c decodeObjectOfClass:[NSString class] forKey:@"name"];
        _scriptType    = [c decodeObjectOfClass:[NSString class] forKey:@"scriptType"];
        _scriptContent = [c decodeObjectOfClass:[NSString class] forKey:@"scriptContent"];
        _enabled       = [c decodeBoolForKey:@"enabled"];
        _hotkeyVisible = [c decodeBoolForKey:@"hotkeyVisible"];

        NSSet *set = [NSSet setWithObjects:[NSMutableDictionary class], [NSDictionary class],
                                           [NSString class], [NSNumber class], [NSArray class], nil];
        _settings = [[c decodeObjectOfClasses:set forKey:@"settings"] mutableCopy];
        if (!_settings) _settings = [NSMutableDictionary dictionary];

        _lastRunStatus = [c decodeObjectOfClass:[NSString class] forKey:@"lastRunStatus"] ?: @"never";
        _lastRunTime   = [c decodeObjectOfClass:[NSDate class] forKey:@"lastRunTime"];
    }
    return self;
}
@end
