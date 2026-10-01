#import "SLMainTabVC.h"
#import "SLFeatureListVC.h"
#import "SLLogVC.h"
#import "SLAIAssistantVC.h"
#import "SLGlobalSettingVC.h"

@implementation SLMainTabVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    SLFeatureListVC *f = [[SLFeatureListVC alloc] init];
    UINavigationController *n1 = [[UINavigationController alloc] initWithRootViewController:f];
    n1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"功能"
                                                  image:[UIImage systemImageNamed:@"list.bullet"]
                                                    tag:0];

    SLLogVC *l = [[SLLogVC alloc] init];
    UINavigationController *n2 = [[UINavigationController alloc] initWithRootViewController:l];
    n2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"日志"
                                                  image:[UIImage systemImageNamed:@"doc.text"]
                                                    tag:1];

    SLAIAssistantVC *a = [[SLAIAssistantVC alloc] init];
    UINavigationController *n3 = [[UINavigationController alloc] initWithRootViewController:a];
    n3.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"AI"
                                                  image:[UIImage systemImageNamed:@"bubble.left.and.bubble.right"]
                                                    tag:2];

    SLGlobalSettingVC *s = [[SLGlobalSettingVC alloc] init];
    UINavigationController *n4 = [[UINavigationController alloc] initWithRootViewController:s];
    n4.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"设置"
                                                  image:[UIImage systemImageNamed:@"gearshape"]
                                                    tag:3];

    self.viewControllers = @[n1, n2, n3, n4];

    // 每个 tab 独立关闭按钮
    f.navigationItem.leftBarButtonItem = [self makeDoneButton];
    l.navigationItem.leftBarButtonItem = [self makeDoneButton];
    a.navigationItem.leftBarButtonItem = [self makeDoneButton];
    s.navigationItem.leftBarButtonItem = [self makeDoneButton];
}

- (UIBarButtonItem *)makeDoneButton {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                         target:self action:@selector(close)];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
