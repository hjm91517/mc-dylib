#import "SLFeatureListVC.h"
#import "SLScriptManager.h"
#import "SLAddFeatureVC.h"
#import "SLSettingVC.h"
#import "SLScriptEngine.h"
#import "SLHotkeyManager.h"
#import "SLFloatWindow.h"
#import "SLTheme.h"

#pragma mark - 功能卡片 Cell

@interface SLFeatureCardCell : UICollectionViewCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *typeBadge;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIImageView *runArrow;
@end

@implementation SLFeatureCardCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.contentView.backgroundColor = [UIColor clearColor];

        _card = SLMakeCard();
        [self.contentView addSubview:_card];

        _statusDot = [[UIView alloc] init];
        _statusDot.layer.cornerRadius = 5;
        [self.contentView addSubview:_statusDot];

        _typeBadge = [[UILabel alloc] init];
        _typeBadge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        _typeBadge.textAlignment = NSTextAlignmentCenter;
        _typeBadge.textColor = SLColorAccent();
        _typeBadge.layer.cornerRadius = 7;
        _typeBadge.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        _typeBadge.layer.borderColor = SLColorAccent().CGColor;
        [self.contentView addSubview:_typeBadge];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _nameLabel.textColor = SLColorText();
        _nameLabel.numberOfLines = 2;
        [self.contentView addSubview:_nameLabel];

        _metaLabel = [[UILabel alloc] init];
        _metaLabel.font = [UIFont systemFontOfSize:11];
        _metaLabel.textColor = SLColorText3();
        _metaLabel.numberOfLines = 1;
        [self.contentView addSubview:_metaLabel];

        _runArrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.circle.fill"]];
        _runArrow.tintColor = SLColorAccent();
        [self.contentView addSubview:_runArrow];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.contentView.bounds.size.width;
    CGFloat H = self.contentView.bounds.size.height;
    _card.frame = CGRectMake(0, 0, W, H);

    _statusDot.frame = CGRectMake(14, 16, 10, 10);
    _typeBadge.frame = CGRectMake(34, 11, 40, 20);
    _runArrow.frame = CGRectMake(W - 34, 14, 22, 22);

    _nameLabel.frame = CGRectMake(14, 42, W - 28, 40);
    _metaLabel.frame = CGRectMake(14, H - 32, W - 28, 16);
}

- (void)configureWithFeature:(SLFeature *)f {
    if ([f.lastRunStatus isEqualToString:@"success"]) {
        self.statusDot.backgroundColor = SLColorOK();
        self.runArrow.tintColor = SLColorOK();
    } else if ([f.lastRunStatus isEqualToString:@"fail"]) {
        self.statusDot.backgroundColor = SLColorFail();
        self.runArrow.tintColor = SLColorFail();
    } else {
        self.statusDot.backgroundColor = SLColorNever();
        self.runArrow.tintColor = SLColorAccent();
    }
    self.typeBadge.text = [[f.scriptType uppercaseString] stringByReplacingOccurrencesOfString:@"PYTHON" withString:@"PY"];
    self.nameLabel.text = f.name;

    NSString *timeStr = @"从未运行";
    if (f.lastRunTime) {
        static NSDateFormatter *fmt = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            fmt = [[NSDateFormatter alloc] init];
            fmt.dateFormat = @"MM-dd HH:mm";
        });
        timeStr = [fmt stringFromDate:f.lastRunTime];
    }
    self.metaLabel.text = [NSString stringWithFormat:@"%@ · %@",
                           f.enabled ? @"已启用" : @"已停用", timeStr];
    self.card.alpha = f.enabled ? 1.0 : 0.55;
}
@end

#pragma mark - 功能列表（MoonPack「我的资源包」网格）

@interface SLFeatureListVC () <UICollectionViewDelegate, UICollectionViewDataSource>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<SLFeature *> *features;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation SLFeatureListVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = SLColorBG();

    // MoonPack 风格：大标题「我的资源包」+ 左侧 × 关闭 + 右侧 ＋ 添加
    self.navigationItem.title = @"我的资源包";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain
               target:self action:@selector(closePanel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"plus"] style:UIBarButtonItemStylePlain
               target:self action:@selector(addFeature)];

    [self buildCollection];
    [self loadFeatures];
    [[SLHotkeyManager sharedInstance] rebuildAll];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    [self loadFeatures];
}

- (void)buildCollection {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumLineSpacing = 12;
    layout.minimumInteritemSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(16, 16, 24, 16);

    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds
                                             collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[SLFeatureCardCell class]
            forCellWithReuseIdentifier:@"card"];
    [self.view addSubview:self.collectionView];

    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 180,
                                                                self.view.bounds.size.width, 90)];
    self.emptyLabel.text = @"暂无功能\n点右上角 ＋ 添加你的第一个脚本";
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = SLColorText3();
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.emptyLabel];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleLongPress:)];
    [self.collectionView addGestureRecognizer:lp];
}

#pragma mark - 数据

- (void)loadFeatures {
    self.features = [[SLScriptManager sharedInstance] loadAllFeatures];
    self.emptyLabel.hidden = self.features.count > 0;
    [self.collectionView reloadData];
}

- (void)addFeature {
    SLAddFeatureVC *vc = [[SLAddFeatureVC alloc] init];
    __weak typeof(self) weakSelf = self;
    vc.onSave = ^{
        [weakSelf loadFeatures];
        [[SLHotkeyManager sharedInstance] rebuildAll];
    };
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)closePanel {
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
        [[SLFloatWindow sharedInstance] restoreAnimated];
    }];
}

#pragma mark - CollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.features.count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat W = collectionView.bounds.size.width;
    CGFloat inset = 16;
    CGFloat gap = 12;
    CGFloat itemW = (W - inset * 2 - gap) / 2.0;
    if (itemW > 180) itemW = 180; // iPad 上限制卡片宽度，保持资源包网格感
    return CGSizeMake(itemW, 116);
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SLFeatureCardCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"card"
                                                                        forIndexPath:indexPath];
    [cell configureWithFeature:self.features[indexPath.row]];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    SLFeature *f = self.features[indexPath.row];

    // 卡片按压反馈
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        cell.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(BOOL done) {
        [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.5
              initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    BOOL ok = [SLScriptEngine runScript:f.scriptContent
                                    type:f.scriptType
                               variables:f.settings
                             featureName:f.name];
    f.lastRunStatus = ok ? @"success" : @"fail";
    f.lastRunTime = [NSDate date];
    [[SLScriptManager sharedInstance] saveFeature:f];
    [self loadFeatures];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint p = [g locationInView:self.collectionView];
    NSIndexPath *ip = [self.collectionView indexPathForItemAtPoint:p];
    if (!ip) return;
    SLFeature *f = self.features[ip.row];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:f.name
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *run = [UIAlertAction actionWithTitle:@"▶️ 立即运行" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
        BOOL ok = [SLScriptEngine runScript:f.scriptContent type:f.scriptType
                                  variables:f.settings featureName:f.name];
        f.lastRunStatus = ok ? @"success" : @"fail";
        f.lastRunTime = [NSDate date];
        [[SLScriptManager sharedInstance] saveFeature:f];
        [self loadFeatures];
    }];
    UIAlertAction *setting = [UIAlertAction actionWithTitle:@"⚙️ 设置" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
        SLSettingVC *vc = [[SLSettingVC alloc] initWithFeature:f];
        __weak typeof(self) weakSelf = self;
        vc.onSave = ^{
            [weakSelf loadFeatures];
            [[SLHotkeyManager sharedInstance] rebuildAll];
        };
        [self.navigationController pushViewController:vc animated:YES];
    }];
    UIAlertAction *del = [UIAlertAction actionWithTitle:@"🗑 删除" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *a) {
        [[SLScriptManager sharedInstance] deleteFeature:f];
        [[SLHotkeyManager sharedInstance] removeHotkeyForFeatureId:f.featureId];
        [self loadFeatures];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [sheet addAction:run];
    [sheet addAction:setting];
    [sheet addAction:del];
    [sheet addAction:cancel];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
