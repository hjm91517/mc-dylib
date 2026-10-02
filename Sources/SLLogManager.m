#import "SLLogManager.h"
#import "SLConstants.h"
#import <signal.h>
#import <execinfo.h>

static const NSUInteger kMaxLogCount = 1000;

#pragma mark - SLLogEntry

@implementation SLLogEntry

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInteger:self.type        forKey:@"type"];
    [c encodeObject:self.featureName  forKey:@"featureName"];
    [c encodeObject:self.message      forKey:@"message"];
    [c encodeObject:self.timestamp    forKey:@"timestamp"];
}

- (instancetype)initWithCoder:(NSCoder *)c {
    if (self = [super init]) {
        _type        = [c decodeIntegerForKey:@"type"];
        _featureName = [c decodeObjectOfClass:[NSString class] forKey:@"featureName"] ?: @"";
        _message     = [c decodeObjectOfClass:[NSString class] forKey:@"message"] ?: @"";
        _timestamp   = [c decodeObjectOfClass:[NSDate class] forKey:@"timestamp"] ?: [NSDate date];
    }
    return self;
}

@end

#pragma mark - SLLogManager

@interface SLLogManager ()
@property (nonatomic, strong) NSMutableArray<SLLogEntry *> *logs;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) BOOL persistScheduled;
@end

@implementation SLLogManager

+ (instancetype)sharedInstance {
    static SLLogManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLLogManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("com.hjpythonzd.log", DISPATCH_QUEUE_SERIAL);
        _logs = [NSMutableArray array];
        [self loadFromDisk];
    }
    return self;
}

- (NSString *)storagePath {
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dir = [doc stringByAppendingPathComponent:kProjectFolderName];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"logs.plist"];
}

#pragma mark - 持久化

- (void)loadFromDisk {
    NSData *data = [NSData dataWithContentsOfFile:[self storagePath]];
    if (!data) return;
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSMutableArray class],
                      [SLLogEntry class], [NSString class], [NSDate class], nil];
    id decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:nil];
    if ([decoded isKindOfClass:[NSArray class]]) {
        for (id obj in (NSArray *)decoded) {
            if ([obj isKindOfClass:[SLLogEntry class]]) [_logs addObject:obj];
        }
    }
}

/// 合并写入：频繁打日志时 1 秒内只落盘一次
- (void)schedulePersist {
    if (self.persistScheduled) return;
    self.persistScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   self.queue, ^{
        self.persistScheduled = NO;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.logs
                                             requiringSecureCoding:YES error:nil];
        if (data) [data writeToFile:[self storagePath] atomically:YES];
    });
}

#pragma mark - 对外接口

- (void)log:(SLLogType)type feature:(NSString *)feature message:(NSString *)message {
    SLLogEntry *e = [[SLLogEntry alloc] init];
    e.type        = type;
    e.featureName = feature ?: @"";
    e.message     = message ?: @"";
    e.timestamp   = [NSDate date];

    dispatch_async(self.queue, ^{
        [self.logs addObject:e];
        if (self.logs.count > kMaxLogCount) {
            [self.logs removeObjectsInRange:NSMakeRange(0, self.logs.count - kMaxLogCount)];
        }
        [self schedulePersist];
    });
}

- (NSArray<SLLogEntry *> *)allLogs {
    __block NSArray *result = nil;
    dispatch_sync(self.queue, ^{ result = [self.logs copy]; });
    return result;
}

- (NSArray<SLLogEntry *> *)logsOfType:(SLLogType)type {
    __block NSMutableArray *result = [NSMutableArray array];
    dispatch_sync(self.queue, ^{
        for (SLLogEntry *e in self.logs) {
            if (e.type == type) [result addObject:e];
        }
    });
    return result;
}

- (void)clearAll {
    dispatch_async(self.queue, ^{
        [self.logs removeAllObjects];
        [[NSFileManager defaultManager] removeItemAtPath:[self storagePath] error:nil];
    });
}

#pragma mark - 崩溃捕获

static void SLUncaughtExceptionHandler(NSException *exception) {
    SLLogEntry *e = [[SLLogEntry alloc] init];
    e.type        = SLLogTypeCrash;
    e.featureName = @"Crash";
    e.message     = [NSString stringWithFormat:@"%@: %@\n%@",
                     exception.name, exception.reason,
                     [exception.callStackSymbols componentsJoinedByString:@"\n"]];
    e.timestamp   = [NSDate date];

    // 崩溃现场直接同步落盘（不走合并写入）
    SLLogManager *mgr = [SLLogManager sharedInstance];
    [mgr.logs addObject:e];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:mgr.logs
                                         requiringSecureCoding:YES error:nil];
    if (data) [data writeToFile:[mgr storagePath] atomically:YES];
}

static void SLSignalHandler(int sig) {
    // 记录信号崩溃，然后恢复默认行为让系统生成崩溃报告
    NSString *msg = [NSString stringWithFormat:@"收到信号 %d", sig];
    [SLLogManager sharedInstance]; // 确保单例存在
    SLUncaughtExceptionHandler([NSException exceptionWithName:@"SignalCrash"
                                                       reason:msg userInfo:nil]);
    signal(sig, SIG_DFL);
    raise(sig);
}

- (void)installCrashHandler {
    NSSetUncaughtExceptionHandler(&SLUncaughtExceptionHandler);
    signal(SIGABRT, SLSignalHandler);
    signal(SIGSEGV, SLSignalHandler);
    signal(SIGBUS,  SLSignalHandler);
    signal(SIGTRAP, SLSignalHandler);
    signal(SIGILL,  SLSignalHandler);
}

@end
