#import "SLAPIClient.h"
#import "SLLogManager.h"
#import "SLConstants.h"

@interface SLAPIClient ()
@property (nonatomic, strong) NSString *configPath;
@end

@implementation SLAPIClient

+ (instancetype)sharedInstance {
    static SLAPIClient *i; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[SLAPIClient alloc] init]; });
    return i;
}

- (instancetype)init {
    if (self = [super init]) {
        NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *dir = [doc stringByAppendingPathComponent:kProjectFolderName];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        _configPath = [dir stringByAppendingPathComponent:@"ai_config.plist"];
    }
    return self;
}

- (NSMutableDictionary *)loadConfig {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:self.configPath];
    if (!d) d = [NSMutableDictionary dictionary];
    if (!d[@"baseURL"]) d[@"baseURL"] = @"https://api.openai.com/v1";
    if (!d[@"model"])   d[@"model"]   = @"gpt-3.5-turbo";
    return d;
}

- (void)saveConfig:(NSDictionary *)cfg { [cfg writeToFile:self.configPath atomically:YES]; }

- (NSString *)apiKey { return [self loadConfig][@"apiKey"] ?: @""; }
- (void)setApiKey:(NSString *)k  { NSMutableDictionary *d = [self loadConfig]; d[@"apiKey"]  = k ?: @""; [self saveConfig:d]; }
- (NSString *)baseURL { return [self loadConfig][@"baseURL"]; }
- (void)setBaseURL:(NSString *)u { NSMutableDictionary *d = [self loadConfig]; d[@"baseURL"] = u ?: @""; [self saveConfig:d]; }
- (NSString *)model { return [self loadConfig][@"model"]; }
- (void)setModel:(NSString *)m   { NSMutableDictionary *d = [self loadConfig]; d[@"model"]   = m ?: @""; [self saveConfig:d]; }

- (void)chatWithMessages:(NSArray<NSDictionary *> *)messages
              completion:(SLAPICompletion)completion {
    NSString *key = [self apiKey];
    if (!key.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SLAPI" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"请先在设置中填写 API Key"}]);
        return;
    }
    NSString *base = [self.baseURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    while ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    NSString *urlStr = [NSString stringWithFormat:@"%@/chat/completions", base];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SLAPI" code:-2
            userInfo:@{NSLocalizedDescriptionKey: @"Base URL 无效"}]);
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 60;
    [req setValue:[NSString stringWithFormat:@"Bearer %@", key] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *body = @{ @"model": [self model] ?: @"gpt-3.5-turbo",
                            @"messages": messages ?: @[],
                            @"temperature": @0.7 };

    NSData *b = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    req.HTTPBody = b;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
                                                                 completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) {
            if (completion) completion(nil, err);
            return;
        }
        if (!data) {
            if (completion) completion(nil, [NSError errorWithDomain:@"SLAPI" code:-3 userInfo:@{NSLocalizedDescriptionKey:@"空响应"}]);
            return;
        }
        NSError *jsonErr = nil;
        NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, jsonErr ?: [NSError errorWithDomain:@"SLAPI" code:-4 userInfo:@{NSLocalizedDescriptionKey:@"非 JSON 响应"}]);
            return;
        }
        // 兼容多种返回，先校验 choices 是数组
        id choices = obj[@"choices"];
        if (![choices isKindOfClass:[NSArray class]] || ((NSArray *)choices).count == 0) {
            if (completion) completion(nil, [NSError errorWithDomain:@"SLAPI" code:-5 userInfo:@{NSLocalizedDescriptionKey:@"未包含 choices"}]);
            return;
        }
        NSDictionary *first = ((NSArray *)choices).firstObject;
        if (![first isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, [NSError errorWithDomain:@"SLAPI" code:-6 userInfo:@{NSLocalizedDescriptionKey:@"choices 内容不合法"}]);
            return;
        }
        id content = first[@"message"][@"content"];
        NSString *reply = nil;
        if ([content isKindOfClass:[NSString class]]) {
            reply = content;
        } else if ([content isKindOfClass:[NSArray class]]) {
            // 多模态格式：[{@"type": @"text", @"text": @"..."}]
            NSMutableArray *parts = [NSMutableArray array];
            for (id item in (NSArray *)content) {
                if ([item isKindOfClass:[NSDictionary class]] &&
                    [item[@"text"] isKindOfClass:[NSString class]]) {
                    [parts addObject:item[@"text"]];
                }
            }
            reply = [parts componentsJoinedByString:@""];
        }
        if (!reply.length) {
            // 部分兼容接口把文本放在 message 外的字段
            id msg = first[@"message"];
            if ([msg isKindOfClass:[NSString class]]) reply = msg;
        }
        if (!reply.length) {
            if (completion) completion(nil, [NSError errorWithDomain:@"SLAPI" code:-7
                userInfo:@{NSLocalizedDescriptionKey:@"响应中未找到文本内容"}]);
            return;
        }
        if (completion) completion(reply, nil);
    }];
    [task resume];
}

@end
