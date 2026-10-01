#import <Foundation/Foundation.h>

typedef void(^SLAPICompletion)(NSString *reply, NSError *error);

@interface SLAPIClient : NSObject
+ (instancetype)sharedInstance;
- (NSString *)apiKey;
- (void)setApiKey:(NSString *)key;
- (NSString *)baseURL;
- (void)setBaseURL:(NSString *)url;
- (NSString *)model;
- (void)setModel:(NSString *)model;
- (void)chatWithMessages:(NSArray<NSDictionary *> *)messages
              completion:(SLAPICompletion)completion;
@end
