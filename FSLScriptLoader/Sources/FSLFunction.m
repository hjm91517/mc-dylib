#import "FSLFunction.h"

@implementation FSLFunction

- (instancetype)init {
    if ((self = [super init])) {
        _identifier = NSUUID.UUID.UUIDString;
        _enabled = YES;
        _configValues = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if ((self = [self init])) {
        _identifier = [dict[@"id"] isKindOfClass:NSString.class] ? dict[@"id"] : NSUUID.UUID.UUIDString;
        _name = [dict[@"name"] isKindOfClass:NSString.class] ? dict[@"name"] : @"未命名";
        _source = [dict[@"source"] isKindOfClass:NSString.class] ? dict[@"source"] : @"";
        _type = [dict[@"type"] integerValue] == FSLScriptTypePython ? FSLScriptTypePython : FSLScriptTypeJS;
        _enabled = dict[@"enabled"] ? [dict[@"enabled"] boolValue] : YES;
        _hotkeyEnabled = [dict[@"hotkeyEnabled"] boolValue];
        CGFloat x = [dict[@"hotkeyX"] doubleValue];
        CGFloat y = [dict[@"hotkeyY"] doubleValue];
        _hotkeyPosition = CGPointMake(x, y);
        if ([dict[@"configValues"] isKindOfClass:NSDictionary.class]) {
            _configValues = [dict[@"configValues"] mutableCopy];
        }
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"id": self.identifier ?: @"",
        @"name": self.name ?: @"",
        @"source": self.source ?: @"",
        @"type": @(self.type),
        @"enabled": @(self.enabled),
        @"hotkeyEnabled": @(self.hotkeyEnabled),
        @"hotkeyX": @(self.hotkeyPosition.x),
        @"hotkeyY": @(self.hotkeyPosition.y),
        @"configValues": self.configValues ?: @{}
    };
}

- (NSString *)typeBadge {
    return self.type == FSLScriptTypePython ? @"PY" : @"JS";
}

@end
