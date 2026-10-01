#import "SLAPIClient.h"
#import "SLLogManager.h"

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
        NSString *dir = [doc stringByAppendingPathComponent:@"SLNetEaseMC"];
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
    NSString *base = [self.baseURL stringByTrimmingCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@"/"]];
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
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    if (!bodyData) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SLAPI" code:-3
            userInfo:@{NSLocalizedDescriptionKey: @"请求体序列化失败"}]);
        return;
    }
    req.HTTPBody = bodyData;

    [[SLLogManager sharedInstance] log:SLLogTypeAI feature:@"Request"
                               message:[NSString stringWithFormat:@"发送 %lu 条消息", (unsigned long)messages.count]];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        if (error) {
            [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"AI" message:error.localizedDescription];
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]] || ![json[@"choices"] isKindOfClass:NSArray.class]) {
            NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
            [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"AI"
                                       message:[NSString stringWithFormat:@"响应解析失败: %@", s]];
            if (completion) completion(nil, [NSError errorWithDomain:@"SLAPI" code:-4
                userInfo:@{NSLocalizedDescriptionKey: @"响应解析失败"}]);
            return;
        }
        id first = [json[@"choices"] firstObject];
        NSString *reply = nil;
        if ([first isKindOfClass:NSDictionary.class]) reply = first[@"message"][@"content"];
        reply = reply ?: @"";
        [[SLLogManager sharedInstance] log:SLLogTypeAI feature:@"Response"
                                   message:[NSString stringWithFormat:@"收到 %lu 字符", (unsigned long)reply.length]];
        if (completion) completion(reply, nil);
    }];
    [task resume];
}
@end
