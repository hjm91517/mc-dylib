#import "SLAIAssistantVC.h"
#import "SLAPIClient.h"
#import "SLLogManager.h"

#pragma mark - 聊天气泡 Cell

@interface SLChatBubbleCell : UITableViewCell
@property (nonatomic, strong) UIView *bubble;
@property (nonatomic, strong) UILabel *msgLabel;
@property (nonatomic, strong) NSLayoutConstraint *leadingC;
@property (nonatomic, strong) NSLayoutConstraint *trailingC;
- (void)configureWithText:(NSString *)text isUser:(BOOL)isUser;
@end

@implementation SLChatBubbleCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if (self = [super initWithStyle:style reuseIdentifier:rid]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];

        _bubble = [[UIView alloc] init];
        _bubble.layer.cornerRadius = 14;
        _bubble.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_bubble];

        _msgLabel = [[UILabel alloc] init];
        _msgLabel.numberOfLines = 0;
        _msgLabel.font = [UIFont systemFontOfSize:15];
        _msgLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_bubble addSubview:_msgLabel];

        _leadingC = [_bubble.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12];
        _trailingC = [_bubble.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12];

        [NSLayoutConstraint activateConstraints:@[
            [_bubble.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [_bubble.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [_bubble.widthAnchor constraintLessThanOrEqualToAnchor:self.contentView.widthAnchor multiplier:0.75],
            [_msgLabel.topAnchor constraintEqualToAnchor:_bubble.topAnchor constant:9],
            [_msgLabel.bottomAnchor constraintEqualToAnchor:_bubble.bottomAnchor constant:-9],
            [_msgLabel.leadingAnchor constraintEqualToAnchor:_bubble.leadingAnchor constant:12],
            [_msgLabel.trailingAnchor constraintEqualToAnchor:_bubble.trailingAnchor constant:-12],
        ]];
    }
    return self;
}

- (void)configureWithText:(NSString *)text isUser:(BOOL)isUser {
    self.msgLabel.text = text;
    self.leadingC.active = !isUser;
    self.trailingC.active = isUser;
    if (isUser) {
        self.bubble.backgroundColor = [UIColor systemBlueColor];
        self.msgLabel.textColor = [UIColor whiteColor];
    } else {
        self.bubble.backgroundColor = [UIColor secondarySystemBackgroundColor];
        self.msgLabel.textColor = [UIColor labelColor];
    }
}
@end

@interface SLAIAssistantVC () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *messages;
@property (nonatomic, strong) UITextField *input;
@property (nonatomic, strong) UIButton *sendButton;
@end

@implementation SLAIAssistantVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AI 助手";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.messages = [NSMutableArray array];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChange:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];

    [self layoutUI];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutUI {
    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;
    CGFloat bar = 56;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, W, H - bar)
                                                  style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.tableView];

    self.input = [[UITextField alloc] initWithFrame:CGRectMake(8, H - 52, W - 80, 44)];
    self.input.borderStyle = UITextBorderStyleRoundedRect;
    self.input.placeholder = @"向 AI 提问…";
    self.input.delegate = self;
    [self.view addSubview:self.input];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(W - 68, H - 52, 60, 44);
    [self.sendButton setTitle:@"发送" forState:UIControlStateNormal];
    [self.sendButton addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.sendButton];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"清空" style:UIBarButtonItemStylePlain
               target:self action:@selector(clearChat)];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // 旋转 / 分屏时保持布局
    if (!self.input.isEditing) [self relayoutWithKeyboard:0 animated:NO];
}

- (void)relayoutWithKeyboard:(CGFloat)kb animated:(BOOL)animated {
    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;
    void (^block)(void) = ^{
        self.input.frame = CGRectMake(8, H - 52 - kb, W - 80, 44);
        self.sendButton.frame = CGRectMake(W - 68, H - 52 - kb, 60, 44);
        self.tableView.frame = CGRectMake(0, 0, W, H - 56 - kb);
    };
    if (animated) [UIView animateWithDuration:0.25 animations:block];
    else block();
}

- (void)keyboardWillChange:(NSNotification *)note {
    CGRect end = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    end = [self.view convertRect:end fromView:nil];
    CGFloat kb = self.view.bounds.size.height - end.origin.y;
    if (kb < 0) kb = 0;
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;
    [UIView animateWithDuration:duration animations:^{
        self.input.frame = CGRectMake(8, H - 52 - kb, W - 80, 44);
        self.sendButton.frame = CGRectMake(W - 68, H - 52 - kb, 60, 44);
        self.tableView.frame = CGRectMake(0, 0, W, H - 56 - kb);
    }];
}

- (void)clearChat {
    [self.messages removeAllObjects];
    [self.tableView reloadData];
}

- (void)send {
    NSString *text = self.input.text;
    if (!text.length) return;
    self.input.text = @"";

    [self.messages addObject:@{@"role": @"user", @"content": text}];
    [self.tableView reloadData];
    [self scrollToBottom];

    NSArray *msgs = [self.messages copy];
    __weak typeof(self) weakSelf = self;
    [[SLAPIClient sharedInstance] chatWithMessages:msgs completion:^(NSString *reply, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [weakSelf.messages addObject:@{@"role": @"assistant",
                                               @"content": [NSString stringWithFormat:@"❌ 错误: %@",
                                                            error.localizedDescription]}];
            } else {
                [weakSelf.messages addObject:@{@"role": @"assistant", @"content": reply ?: @""}];
            }
            [weakSelf.tableView reloadData];
            [weakSelf scrollToBottom];
        });
    }];
}

- (void)scrollToBottom {
    if (!self.messages.count) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *m = self.messages[indexPath.row];
    BOOL user = [m[@"role"] isEqualToString:@"user"];
    NSString *rid = user ? @"bubble-user" : @"bubble-ai";
    SLChatBubbleCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
    if (!cell) cell = [[SLChatBubbleCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
    NSString *text = m[@"content"] ?: @"";
    [cell configureWithText:user ? text : [@"🤖 " stringByAppendingString:text] isUser:user];
    return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self send];
    return YES;
}
@end
