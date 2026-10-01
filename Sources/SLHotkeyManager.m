#import "SLHotkeyManager.h"

@implementation SLHotkeyManager

+ (instancetype)sharedInstance {
    static SLHotkeyManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLHotkeyManager alloc] init];
    });
    return instance;
}

- (void)rebuildAll {
    // TODO: rebuild registered hotkeys for enabled features.
}

- (void)removeHotkeyForFeatureId:(NSString *)fid {
    // TODO: unregister the hotkey associated with the given feature id.
    (void)fid;
}

@end
