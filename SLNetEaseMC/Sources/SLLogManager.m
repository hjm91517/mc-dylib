#import "SLLogManager.h"
#import <signal.h>
#import <execinfo.h>
#import <stdio.h>

@implementation SLLogEntry

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)init {
    if (self = [super init]) {
        _timestamp   = [NSDate date];
        _message     = @"";
        _featureName = @"-";
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInteger:self.type forKey:@"type"];
    [c encodeObject:self.featureName forKey:@"featureName"];
    [c encodeObject:self.message forKey:@"message"];
    [c encodeObject:self.timestamp forKey:@"timestamp"];
}

- (instancetype)initWithCoder:(NSCoder *)c {
    if (self = [super init]) {
        _type        = [c decodeIntegerForKey:@"type"];
        _featureName = [c decodeObjectOfClass:[NSString class] forKey:@"featureName"] ?: @"-";
        _message     = [c decodeObjectOfClass:[NSString class] forKey:@"message"] ?: @"";
        _timestamp   = [c decodeObjectOfClass:[NSDate class] forKey:@"timestamp"] ?: [NSDate date];
    }
    return self;
}
@end

static void SLCrashHandler(int sig) {
    void *callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    NSMutableString *sb = [NSMutableString string];
    [sb appendFormat:@"Signal %d\n", sig];
    if (strs) {
        for (int i = 0; i < frames; i++) [sb appendFormat:@"%s\n", strs[i]];
        free(strs);
    }
    [[SLLogManager sharedInstance] log:SLLogTypeCrash feature:@"App" message:sb];
    signal(sig, SIG_DFL);
    raise(sig);
}

@interface SLLogManager ()
@property (nonatomic, strong) NSMutableArray<SLLogEntry *> *logs;
@property (nonatomic, strong) NSString *path;
@end

@implementation SLLogManager

+ (instancetype)sharedInstance {
    static SLLogManager *i; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[SLLogManager alloc] init]; });
    return i;
}

- (instancetype)init {
    if (self = [super init]) {
        _logs = [NSMutableArray array];
        NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *dir = [doc stringByAppendingPathComponent:@"SLNetEaseMC/logs"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        _path = [dir stringByAppendingPathComponent:@"logs.plist"];
        [self load];
    }
    return self;
}

- (void)load {
    NSData *d = [NSData dataWithContentsOfFile:self.path];
    if (!d) return;
    NSError *e;
    NSSet *set = [NSSet setWithObjects:[NSArray class], [NSMutableArray class], [SLLogEntry class],
                                       [NSString class], [NSDate class], [NSNumber class], nil];
    NSArray *arr = [NSKeyedUnarchiver unarchivedObjectOfClasses:set fromData:d error:&e];
    if (arr) {
        self.logs = [arr mutableCopy];
        if (self.logs.count > 2000)
            [self.logs removeObjectsInRange:NSMakeRange(0, self.logs.count - 2000)];
    }
}

- (void)save {
    NSData *d = [NSKeyedArchiver archivedDataWithRootObject:self.logs
                                      requiringSecureCoding:YES error:nil];
    [d writeToFile:self.path atomically:YES];
}

- (void)log:(SLLogType)type feature:(NSString *)feature message:(NSString *)message {
    SLLogEntry *e = [[SLLogEntry alloc] init];
    e.type        = type;
    e.featureName = feature.length ? feature : @"-";
    e.message     = message ?: @"";
    @synchronized (self) {
        [self.logs addObject:e];
        if (self.logs.count > 2000) [self.logs removeObjectAtIndex:0];
        [self save];
    }
    NSLog(@"[SLNetEaseMC][%ld][%@] %@", (long)type, e.featureName, e.message);
}

- (NSArray<SLLogEntry *> *)allLogs {
    @synchronized (self) { return [self.logs copy]; }
}

- (NSArray<SLLogEntry *> *)logsOfType:(SLLogType)type {
    NSMutableArray *r = [NSMutableArray array];
    @synchronized (self) {
        for (SLLogEntry *e in self.logs) if (e.type == type) [r addObject:e];
    }
    return r;
}

- (void)clearAll {
    @synchronized (self) {
        [self.logs removeAllObjects];
        [self save];
    }
}

- (void)installCrashHandler {
    signal(SIGABRT, SLCrashHandler);
    signal(SIGSEGV, SLCrashHandler);
    signal(SIGBUS,  SLCrashHandler);
    signal(SIGILL,  SLCrashHandler);
    signal(SIGFPE,  SLCrashHandler);
    signal(SIGPIPE, SLCrashHandler);
}
@end
