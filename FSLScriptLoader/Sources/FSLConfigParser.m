#import "FSLConfigParser.h"

@implementation FSLConfigItem
@end

@implementation FSLConfigParser

+ (NSArray<FSLConfigItem *> *)parseSource:(NSString *)source type:(FSLScriptType)type {
    NSMutableArray<FSLConfigItem *> *items = [NSMutableArray array];
    if (source.length == 0) return items;

    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"@config\\s*(\\{[^\\n]*\\})"
                                                                        options:0 error:nil];
    [re enumerateMatchesInString:source options:0 range:NSMakeRange(0, source.length)
                     usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        if (match.numberOfRanges < 2) return;
        NSString *json = [source substringWithRange:[match rangeAtIndex:1]];
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0 error:nil];
        if (![d isKindOfClass:NSDictionary.class] || ![d[@"key"] isKindOfClass:NSString.class]) return;

        FSLConfigItem *it = [FSLConfigItem new];
        it.key = d[@"key"];
        it.type = [d[@"type"] isKindOfClass:NSString.class] ? d[@"type"] : @"text";
        it.label = [d[@"label"] isKindOfClass:NSString.class] ? d[@"label"] : it.key;
        it.defaultValue = d[@"default"] ?: @"";
        // 去重
        for (FSLConfigItem *exist in items) {
            if ([exist.key isEqualToString:it.key]) return;
        }
        [items addObject:it];
    }];
    return items;
}

@end
