#import "FSLFunctionManager.h"
#import "FSLFunction.h"
#import "FSLConfigParser.h"
#import "FSLJSEngine.h"
#import "FSLPythonEngine.h"
#import "FSLCommon.h"

NSNotificationName const FSLFunctionsDidChangeNotification = @"FSLFunctionsDidChangeNotification";
NSNotificationName const FSLRunStateDidChangeNotification = @"FSLRunStateDidChangeNotification";

@interface FSLFunctionManager ()
@property (nonatomic, strong) NSMutableArray<FSLFunction *> *functions;
@property (nonatomic, strong) NSMutableSet<NSString *> *runningIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *stopIDs;
@end

@implementation FSLFunctionManager

+ (instancetype)shared {
    static FSLFunctionManager *s = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [FSLFunctionManager new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _functions = [NSMutableArray array];
        _runningIDs = [NSMutableSet set];
        _stopIDs = [NSMutableSet set];
        [self load];
    }
    return self;
}

- (NSString *)storeDir {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                     stringByAppendingPathComponent:@"FSLScriptLoader"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (NSString *)storePath {
    return [[self storeDir] stringByAppendingPathComponent:@"functions.plist"];
}

- (void)load {
    NSArray *arr = [NSArray arrayWithContentsOfFile:[self storePath]];
    for (NSDictionary *d in arr) {
        if (![d isKindOfClass:NSDictionary.class]) continue;
        FSLFunction *f = [[FSLFunction alloc] initWithDictionary:d];
        if (f) [_functions addObject:f];
    }
}

- (void)save {
    NSMutableArray *arr = [NSMutableArray array];
    for (FSLFunction *f in _functions) [arr addObject:[f dictionaryRepresentation]];
    [arr writeToFile:[self storePath] atomically:YES];
}

- (void)postChange {
    [NSNotificationCenter.defaultCenter postNotificationName:FSLFunctionsDidChangeNotification object:nil];
}

- (void)postRunState {
    [NSNotificationCenter.defaultCenter postNotificationName:FSLRunStateDidChangeNotification object:nil];
}

- (void)addFunction:(FSLFunction *)fn {
    [_functions addObject:fn];
    [self save];
    [self postChange];
}

- (void)deleteFunction:(FSLFunction *)fn {
    [self requestStop:fn];
    [_functions removeObject:fn];
    [self save];
    [self postChange];
}

- (BOOL)isRunning:(FSLFunction *)fn {
    return [_runningIDs containsObject:fn.identifier];
}

- (BOOL)shouldStop:(FSLFunction *)fn {
    return [_stopIDs containsObject:fn.identifier];
}

- (void)requestStop:(FSLFunction *)fn {
    if (![self isRunning:fn]) return;
    [_stopIDs addObject:fn.identifier];
    [self postRunState];
}

- (void)toggleRun:(FSLFunction *)fn {
    if ([self isRunning:fn]) {
        [self requestStop:fn];
    } else {
        [self runFunction:fn];
    }
}

- (void)runFunction:(FSLFunction *)fn {
    if (!fn.enabled) {
        FSLShowAlert(@"无法运行", [NSString stringWithFormat:@"功能「%@」已关闭，请先长按进入设置开启。", fn.name]);
        return;
    }
    if ([self isRunning:fn]) return;
    [_runningIDs addObject:fn.identifier];
    [_stopIDs removeObject:fn.identifier];
    [self postRunState];
    if (fn.type == FSLScriptTypeJS) {
        [FSLJSEngine runFunction:fn];
    } else {
        [FSLPythonEngine runFunction:fn];
    }
}

- (void)markFinished:(FSLFunction *)fn {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_runningIDs removeObject:fn.identifier];
        [_stopIDs removeObject:fn.identifier];
        [self postRunState];
    });
}

- (id)configValueForKey:(NSString *)key function:(FSLFunction *)fn {
    id v = fn.configValues[key];
    if (v) return v;
    for (FSLConfigItem *item in [FSLConfigParser parseSource:fn.source type:fn.type]) {
        if ([item.key isEqualToString:key]) return item.defaultValue;
    }
    return nil;
}

@end
