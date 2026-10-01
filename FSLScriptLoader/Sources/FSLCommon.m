#import "FSLCommon.h"
#import <dlfcn.h>

UIWindow *FSLGetKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:UIWindowScene.class]) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow) return w;
                }
            }
        }
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                NSArray *ws = ((UIWindowScene *)scene).windows;
                for (UIWindow *w in ws) {
                    if (!w.hidden && w.alpha > 0.01 &&
                        ![NSStringFromClass(w.class) containsString:@"FSL"]) return w;
                }
                if (ws.count) return ws.firstObject;
            }
        }
    }
    return UIApplication.sharedApplication.keyWindow;
}

void FSLShowAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        UIWindow *win = FSLGetKeyWindow();
        UIViewController *root = win.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        if (root) {
            [root presentViewController:ac animated:YES completion:nil];
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                UIViewController *r = FSLGetKeyWindow().rootViewController;
                while (r.presentedViewController) r = r.presentedViewController;
                if (r) [r presentViewController:ac animated:YES completion:nil];
            });
        }
    });
}

static UIImage *FSLDrawDefaultIcon(void) {
    CGSize size = CGSizeMake(96, 96);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 96, 96) cornerRadius:24];
        [[UIColor colorWithRed:0.25 green:0.35 blue:0.95 alpha:1.0] setFill];
        [bg fill];
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:44],
            NSForegroundColorAttributeName: UIColor.whiteColor
        };
        NSString *text = @"S";
        CGSize ts = [text sizeWithAttributes:attrs];
        [text drawAtPoint:CGPointMake((96 - ts.width) / 2, (96 - ts.height) / 2) withAttributes:attrs];
    }];
}

UIImage *FSLLoadFloatingIcon(void) {
    static UIImage *icon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray<NSString *> *paths = [NSMutableArray array];
        Dl_info info;
        if (dladdr((const void *)FSLLoadFloatingIcon, &info) && info.dli_fname) {
            NSString *dir = [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
            [paths addObject:[dir stringByAppendingPathComponent:@"FSLResources.bundle/icon.png"]];
            [paths addObject:[[dir stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"FSLResources.bundle/icon.png"]];
        }
        [paths addObject:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"FSLResources.bundle/icon.png"]];
        [paths addObject:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"icon.png"]];
        for (NSString *p in paths) {
            UIImage *img = [UIImage imageWithContentsOfFile:p];
            if (img) { icon = img; break; }
        }
        if (!icon) icon = FSLDrawDefaultIcon();
    });
    return icon;
}
