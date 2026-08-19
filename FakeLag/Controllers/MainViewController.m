#import "MainViewController.h"
#import "SettingsViewController.h"
#import "RemoteLinkManager.h"
#import "HUDLauncher.h"
#import <notify.h>

@interface MainViewController () <UITextFieldDelegate> {
    // Toggles điều khiển trong app
    UISwitch *_fakeLagSwitch;
    UISwitch *_teleKillSwitch;
    UISwitch *_ghostSwitch;
    
    // Toggles hiển thị trên menu nổi
    UISwitch *_showFakeLagSwitch;
    UISwitch *_showTeleKillSwitch;
    UISwitch *_showGhostSwitch;
    
    // Chọn kích thước nút nổi
    UISegmentedControl *_sizeSegmentControl;
    
    UIButton *_overlayToggleButton;
    UIButton *_resetHUDButton;
    UILabel *_overlayStatusLabel;
    
    // Cài đặt link nhanh
    UITextField *_serverUrlField;
    UITextField *_fakeLagUrlField;
    UITextField *_teleKillUrlField;
    UITextField *_ghostUrlField;
    
    UITextView *_logTextView;
    NSMutableArray<NSString *> *_logs;
    
    int _remoteNotifyToken;
}

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"VIP Control Center";
    self.view.backgroundColor = [UIColor colorWithRed:0.03 green:0.04 blue:0.06 alpha:1.0];
    
    _logs = [NSMutableArray array];
    
    // Nút Cài Đặt Chi Tiết trên Nav Bar
    UIBarButtonItem *settingsBtn = [[UIBarButtonItem alloc] initWithTitle:@"⚙️ Nâng Cao"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(openSettingsTapped)];
    settingsBtn.tintColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    self.navigationItem.rightBarButtonItem = settingsBtn;
    
    [self setupUI];
    [self setupLogHandler];
    [self setupNotifications];
    [self refreshState];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _scrollView.frame = self.view.bounds;
    _scrollView.contentSize = _contentView.bounds.size;
}

- (void)setupUI {
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = YES;
    _scrollView.backgroundColor = [UIColor colorWithRed:0.03 green:0.04 blue:0.06 alpha:1.0];
    [self.view addSubview:_scrollView];
    
    _contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 1400)];
    [_scrollView addSubview:_contentView];
    
    CGFloat width = self.view.bounds.size.width - 32;
    CGFloat currentY = 16.0;
    
    // 1. Header Banner OLED Sang Trọng
    UIView *bannerView = [[UIView alloc] initWithFrame:CGRectMake(16, currentY, width, 88)];
    bannerView.backgroundColor = [UIColor colorWithRed:0.06 green:0.08 blue:0.12 alpha:0.95];
    bannerView.layer.cornerRadius = 18.0;
    bannerView.layer.borderWidth = 1.2;
    bannerView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:0.4].CGColor;
    
    bannerView.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:0.25].CGColor;
    bannerView.layer.shadowOffset = CGSizeMake(0, 4);
    bannerView.layer.shadowRadius = 10.0;
    bannerView.layer.shadowOpacity = 0.8;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, width - 32, 28)];
    titleLabel.text = @"⚡ HOANGHA VIP CONTROL";
    titleLabel.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    titleLabel.font = [UIFont systemFontOfSize:18.5 weight:UIFontWeightHeavy];
    [bannerView addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 46, width - 32, 24)];
    subtitleLabel.text = @"Nút Gạt Rời Độc Lập • Xoay / Tắt / Kéo Thả Tự Do";
    subtitleLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    subtitleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    [bannerView addSubview:subtitleLabel];
    
    [_contentView addSubview:bannerView];
    currentY += 100.0;
    
    // 2. Card: Nút Nổi Overlay Trong Suốt & Kích Thước
    UIView *hudCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 245) title:@"1. ĐIỀU KHIỂN & KÍCH THƯỚC NÚT NỔI"];
    
    _overlayStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 38, width - 32, 20)];
    _overlayStatusLabel.text = @"Trạng Thái: Đang tắt";
    _overlayStatusLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    _overlayStatusLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    [hudCard addSubview:_overlayStatusLabel];
    
    _overlayToggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _overlayToggleButton.frame = CGRectMake(16, 62, width - 32, 44);
    _overlayToggleButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.48 alpha:1.0];
    _overlayToggleButton.layer.cornerRadius = 12.0;
    [_overlayToggleButton setTitle:@"▶ BẬT CÁC NÚT GẠT TRÊN MÀN HÌNH" forState:UIControlStateNormal];
    [_overlayToggleButton setTitleColor:[UIColor colorWithRed:0.02 green:0.12 blue:0.06 alpha:1.0] forState:UIControlStateNormal];
    _overlayToggleButton.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightHeavy];
    [_overlayToggleButton addTarget:self action:@selector(toggleOverlayTapped) forControlEvents:UIControlEventTouchUpInside];
    [hudCard addSubview:_overlayToggleButton];
    
    // Segment Chọn Kích Thước Nút Gạt
    UILabel *sizeLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 114, width - 32, 18)];
    sizeLbl.text = @"📐 Kích Thước Nút Gạt:";
    sizeLbl.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    sizeLbl.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    [hudCard addSubview:sizeLbl];
    
    _sizeSegmentControl = [[UISegmentedControl alloc] initWithItems:@[@"Nhỏ (0.85x)", @"Vừa (1.0x)", @"Lớn (1.18x)"]];
    _sizeSegmentControl.frame = CGRectMake(16, 136, width - 32, 34);
    _sizeSegmentControl.selectedSegmentIndex = 1;
    _sizeSegmentControl.backgroundColor = [UIColor colorWithRed:0.08 green:0.11 blue:0.16 alpha:1.0];
    _sizeSegmentControl.selectedSegmentTintColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.95 alpha:1.0];
    [_sizeSegmentControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightBold]} forState:UIControlStateSelected];
    [_sizeSegmentControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.65 alpha:1.0], NSFontAttributeName: [UIFont systemFontOfSize:12]} forState:UIControlStateNormal];
    [_sizeSegmentControl addTarget:self action:@selector(sizeSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    [hudCard addSubview:_sizeSegmentControl];
    
    _resetHUDButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _resetHUDButton.frame = CGRectMake(16, 180, width - 32, 40);
    _resetHUDButton.backgroundColor = [UIColor colorWithRed:0.10 green:0.13 blue:0.19 alpha:0.9];
    _resetHUDButton.layer.cornerRadius = 10.0;
    _resetHUDButton.layer.borderWidth = 1.0;
    _resetHUDButton.layer.borderColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:0.35].CGColor;
    [_resetHUDButton setTitle:@"📍 ĐẶT LẠI VỊ TRÍ 3 NÚT NỔI" forState:UIControlStateNormal];
    [_resetHUDButton setTitleColor:[UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0] forState:UIControlStateNormal];
    _resetHUDButton.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    [_resetHUDButton addTarget:self action:@selector(resetHUDPositionsTapped) forControlEvents:UIControlEventTouchUpInside];
    [hudCard addSubview:_resetHUDButton];
    
    [_contentView addSubview:hudCard];
    currentY += 257.0;
    
    // 3. Card: Tùy Chỉnh Ẩn/Hiện Từng Nút Trên Menu
    UIView *visCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 175) title:@"2. CHỌN TÍNH NĂNG HIỆN TRÊN MÀN HÌNH"];
    
    CGFloat rowW = width - 32;
    CGFloat vStartY = 42;
    
    _showFakeLagSwitch = [self addSwitchRowToCard:visCard frame:CGRectMake(16, vStartY, rowW, 36)
                                             title:@"🧊 Hiện Nút Freeze (FakeLag)"
                                             color:[UIColor colorWithRed:0.0 green:0.80 blue:1.0 alpha:1.0]
                                            action:@selector(showFakeLagChanged:)];
    
    _showTeleKillSwitch = [self addSwitchRowToCard:visCard frame:CGRectMake(16, vStartY + 42, rowW, 36)
                                              title:@"⚡ Hiện Nút TeleKill"
                                              color:[UIColor colorWithRed:1.0 green:0.45 blue:0.1 alpha:1.0]
                                             action:@selector(showTeleKillChanged:)];
    
    _showGhostSwitch = [self addSwitchRowToCard:visCard frame:CGRectMake(16, vStartY + 84, rowW, 36)
                                           title:@"👻 Hiện Nút Ghost Lag"
                                           color:[UIColor colorWithRed:0.75 green:0.45 blue:1.0 alpha:1.0]
                                          action:@selector(showGhostChanged:)];
    
    [_contentView addSubview:visCard];
    currentY += 187.0;
    
    // 4. Card: Bộ Điều Khiển 3 Tính Năng (Đồng bộ 2 chiều)
    UIView *ctrlCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 222) title:@"3. BỘ ĐIỀU KHIỂN 3 TÍNH NĂNG (TRONG APP)"];
    
    CGFloat cStartY = 42;
    _fakeLagSwitch = [self addSwitchRowToCard:ctrlCard frame:CGRectMake(16, cStartY, rowW, 36)
                                        title:@"🧊 Freeze Địch (FakeLag)"
                                        color:[UIColor colorWithRed:0.0 green:0.80 blue:1.0 alpha:1.0]
                                       action:@selector(fakeLagSwitchChanged:)];
    
    _teleKillSwitch = [self addSwitchRowToCard:ctrlCard frame:CGRectMake(16, cStartY + 42, rowW, 36)
                                         title:@"⚡ TeleKill (Dịch Chuyển)"
                                         color:[UIColor colorWithRed:1.0 green:0.45 blue:0.1 alpha:1.0]
                                        action:@selector(teleKillSwitchChanged:)];
    
    _ghostSwitch = [self addSwitchRowToCard:ctrlCard frame:CGRectMake(16, cStartY + 84, rowW, 36)
                                      title:@"👻 Ghost Lag (Tàng Hình)"
                                      color:[UIColor colorWithRed:0.75 green:0.45 blue:1.0 alpha:1.0]
                                     action:@selector(ghostSwitchChanged:)];
    
    UIButton *offAllBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    offAllBtn.frame = CGRectMake(16, cStartY + 130, rowW, 36);
    offAllBtn.backgroundColor = [UIColor colorWithRed:0.95 green:0.15 blue:0.25 alpha:0.25];
    offAllBtn.layer.cornerRadius = 10.0;
    offAllBtn.layer.borderWidth = 1.0;
    offAllBtn.layer.borderColor = [UIColor colorWithRed:0.95 green:0.2 blue:0.3 alpha:0.6].CGColor;
    [offAllBtn setTitle:@"🔴 TẮT TOÀN BỘ (GỬI LỆNH OFF)" forState:UIControlStateNormal];
    [offAllBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0] forState:UIControlStateNormal];
    offAllBtn.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightHeavy];
    [offAllBtn addTarget:self action:@selector(offAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [ctrlCard addSubview:offAllBtn];
    
    [_contentView addSubview:ctrlCard];
    currentY += 234.0;
    
    // 5. Card: Cài Đặt Link Nhanh
    UIView *linkCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 320) title:@"4. CẤU HÌNH LINK URL (LƯU LOCAL)"];
    
    CGFloat lY = 40;
    
    _serverUrlField = [self addUrlInputFieldToCard:linkCard frame:CGRectMake(16, lY, rowW - 90, 36) placeholder:@"https://xxx.trycloudflare.com"];
    _serverUrlField.text = [RemoteLinkManager sharedManager].serverBaseUrl;
    
    UIButton *autoGenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    autoGenBtn.frame = CGRectMake(16 + rowW - 84, lY, 84, 36);
    autoGenBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.55 blue:0.95 alpha:1.0];
    autoGenBtn.layer.cornerRadius = 8.0;
    [autoGenBtn setTitle:@"⚡ Tự Sinh" forState:UIControlStateNormal];
    [autoGenBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    autoGenBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [autoGenBtn addTarget:self action:@selector(applyServerUrlTapped) forControlEvents:UIControlEventTouchUpInside];
    [linkCard addSubview:autoGenBtn];
    lY += 44;
    
    _fakeLagUrlField = [self addUrlInputFieldWithTestToCard:linkCard frame:CGRectMake(16, lY, rowW, 36)
                                                placeholder:@"Link BẬT FakeLag (/freeze)"
                                                     action:@selector(testFakeLagTapped)];
    _fakeLagUrlField.text = [RemoteLinkManager sharedManager].fakeLagConfig.urlOn;
    lY += 44;
    
    _teleKillUrlField = [self addUrlInputFieldWithTestToCard:linkCard frame:CGRectMake(16, lY, rowW, 36)
                                                 placeholder:@"Link BẬT TeleKill (/tele)"
                                                      action:@selector(testTeleKillTapped)];
    _teleKillUrlField.text = [RemoteLinkManager sharedManager].teleKillConfig.urlOn;
    lY += 44;
    
    _ghostUrlField = [self addUrlInputFieldWithTestToCard:linkCard frame:CGRectMake(16, lY, rowW, 36)
                                              placeholder:@"Link BẬT Ghost (/ghost)"
                                                   action:@selector(testGhostTapped)];
    _ghostUrlField.text = [RemoteLinkManager sharedManager].ghostConfig.urlOn;
    lY += 48;
    
    UIButton *saveLinksBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    saveLinksBtn.frame = CGRectMake(16, lY, rowW, 40);
    saveLinksBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.80 blue:0.45 alpha:1.0];
    saveLinksBtn.layer.cornerRadius = 10.0;
    [saveLinksBtn setTitle:@"💾 LƯU TOÀN BỘ LINK URL" forState:UIControlStateNormal];
    [saveLinksBtn setTitleColor:[UIColor colorWithRed:0.02 green:0.12 blue:0.06 alpha:1.0] forState:UIControlStateNormal];
    saveLinksBtn.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightHeavy];
    [saveLinksBtn addTarget:self action:@selector(saveAllLinksTapped) forControlEvents:UIControlEventTouchUpInside];
    [linkCard addSubview:saveLinksBtn];
    
    [_contentView addSubview:linkCard];
    currentY += 332.0;
    
    // 6. Card: Nhật Ký Gửi URL (Live Console Log)
    UIView *logCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 170) title:@"5. NHẬT KÝ GỬI URL (LIVE CONSOLE)"];
    
    _logTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, 38, width - 32, 118)];
    _logTextView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
    _logTextView.layer.cornerRadius = 8.0;
    _logTextView.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.55 alpha:1.0];
    _logTextView.font = [UIFont fontWithName:@"Menlo" size:10.5] ?: [UIFont systemFontOfSize:10.5];
    _logTextView.editable = NO;
    _logTextView.text = @"[SYSTEM] Ready to send GET commands...\n";
    [logCard addSubview:_logTextView];
    
    [_contentView addSubview:logCard];
    currentY += 190.0;
    
    // Cập nhật contentSize để lướt mượt mà 100% không bị snap lại đầu
    _contentView.frame = CGRectMake(0, 0, self.view.bounds.size.width, currentY + 40);
    _scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, currentY + 40);
}

- (UIView *)createCardWithFrame:(CGRect)frame title:(NSString *)title {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [UIColor colorWithRed:0.06 green:0.08 blue:0.12 alpha:0.95];
    card.layer.cornerRadius = 16.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, frame.size.width - 32, 20)];
    lbl.text = title;
    lbl.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    [card addSubview:lbl];
    
    return card;
}

- (UISwitch *)addSwitchRowToCard:(UIView *)card frame:(CGRect)frame title:(NSString *)title color:(UIColor *)color action:(SEL)action {
    UIView *row = [[UIView alloc] initWithFrame:frame];
    row.backgroundColor = [UIColor colorWithRed:0.08 green:0.11 blue:0.16 alpha:0.8];
    row.layer.cornerRadius = 8.0;
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, frame.size.width - 70, frame.size.height)];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [row addSubview:lbl];
    
    UISwitch *sw = [[UISwitch alloc] init];
    sw.center = CGPointMake(frame.size.width - 30, frame.size.height / 2.0);
    sw.onTintColor = color;
    sw.transform = CGAffineTransformMakeScale(0.75, 0.75);
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    
    [card addSubview:row];
    return sw;
}

- (UITextField *)addUrlInputFieldToCard:(UIView *)card frame:(CGRect)frame placeholder:(NSString *)placeholder {
    UITextField *tf = [[UITextField alloc] initWithFrame:frame];
    tf.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
    tf.layer.cornerRadius = 8.0;
    tf.layer.borderWidth = 1.0;
    tf.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    tf.textColor = [UIColor whiteColor];
    tf.font = [UIFont systemFontOfSize:12];
    tf.placeholder = placeholder;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.keyboardType = UIKeyboardTypeURL;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.delegate = self;
    
    UIView *pad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, frame.size.height)];
    tf.leftView = pad;
    tf.leftViewMode = UITextFieldViewModeAlways;
    
    [card addSubview:tf];
    return tf;
}

- (UITextField *)addUrlInputFieldWithTestToCard:(UIView *)card frame:(CGRect)frame placeholder:(NSString *)placeholder action:(SEL)action {
    CGFloat btnW = 60;
    UITextField *tf = [self addUrlInputFieldToCard:card frame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width - btnW - 6, frame.size.height) placeholder:placeholder];
    
    UIButton *testBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    testBtn.frame = CGRectMake(frame.origin.x + frame.size.width - btnW, frame.origin.y, btnW, frame.size.height);
    testBtn.backgroundColor = [UIColor colorWithRed:0.14 green:0.18 blue:0.24 alpha:1.0];
    testBtn.layer.cornerRadius = 8.0;
    testBtn.layer.borderWidth = 1.0;
    testBtn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:0.4].CGColor;
    [testBtn setTitle:@"▶ Test" forState:UIControlStateNormal];
    [testBtn setTitleColor:[UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0] forState:UIControlStateNormal];
    testBtn.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    [testBtn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:testBtn];
    
    return tf;
}

- (void)sizeSegmentChanged:(UISegmentedControl *)sender {
    CGFloat scales[] = {0.85, 1.0, 1.18};
    CGFloat chosen = scales[sender.selectedSegmentIndex];
    [RemoteLinkManager sharedManager].hudScale = chosen;
    [[RemoteLinkManager sharedManager] saveAllConfigs];
    [self addLog:[NSString stringWithFormat:@"[OK] Đã đổi kích thước nút nổi: %.2fx", chosen]];
}

- (void)setupLogHandler {
    __weak typeof(self) weakSelf = self;
    [RemoteLinkManager sharedManager].logHandler = ^(NSString *log) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf addLog:log];
        });
    };
}

- (void)addLog:(NSString *)log {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"HH:mm:ss";
    NSString *timeStr = [df stringFromDate:[NSDate date]];
    NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", timeStr, log];
    
    [_logs insertObject:entry atIndex:0];
    if (_logs.count > 30) [_logs removeLastObject];
    
    NSMutableString *fullText = [NSMutableString string];
    for (NSString *l in _logs) {
        [fullText appendString:l];
    }
    _logTextView.text = fullText;
}

- (void)setupNotifications {
    __weak typeof(self) weakSelf = self;
    notify_register_dispatch("com.fakelag.remotestatechanged", &_remoteNotifyToken, dispatch_get_main_queue(), ^(int token) {
        __strong MainViewController *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf refreshState];
        }
    });
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshState)
                                                 name:RemoteLinkStateChangedNotification
                                               object:nil];
}

- (void)refreshState {
    RemoteLinkManager *mgr = [RemoteLinkManager sharedManager];
    [mgr loadAllConfigs];
    
    [_fakeLagSwitch setOn:mgr.fakeLagConfig.isActive animated:YES];
    [_teleKillSwitch setOn:mgr.teleKillConfig.isActive animated:YES];
    [_ghostSwitch setOn:mgr.ghostConfig.isActive animated:YES];
    
    [_showFakeLagSwitch setOn:mgr.showFakeLagInHUD animated:YES];
    [_showTeleKillSwitch setOn:mgr.showTeleKillInHUD animated:YES];
    [_showGhostSwitch setOn:mgr.showGhostInHUD animated:YES];
    
    if (mgr.hudScale < 0.9) {
        _sizeSegmentControl.selectedSegmentIndex = 0;
    } else if (mgr.hudScale > 1.1) {
        _sizeSegmentControl.selectedSegmentIndex = 2;
    } else {
        _sizeSegmentControl.selectedSegmentIndex = 1;
    }
    
    _serverUrlField.text = mgr.serverBaseUrl;
    _fakeLagUrlField.text = mgr.fakeLagConfig.urlOn;
    _teleKillUrlField.text = mgr.teleKillConfig.urlOn;
    _ghostUrlField.text = mgr.ghostConfig.urlOn;
    
    BOOL hudRunning = [HUDLauncher sharedLauncher].isHUDRunning;
    if (hudRunning) {
        _overlayStatusLabel.text = @"Trạng Thái: Đang hiển thị trên màn hình";
        _overlayStatusLabel.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.55 alpha:1.0];
        [_overlayToggleButton setTitle:@"⏹ TẮT CÁC NÚT NỔI TRONG SUỐT" forState:UIControlStateNormal];
        _overlayToggleButton.backgroundColor = [UIColor colorWithRed:0.90 green:0.20 blue:0.25 alpha:1.0];
        [_overlayToggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        _overlayStatusLabel.text = @"Trạng Thái: Đang tắt";
        _overlayStatusLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
        [_overlayToggleButton setTitle:@"▶ BẬT CÁC NÚT NỔI TRONG SUỐT" forState:UIControlStateNormal];
        _overlayToggleButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.48 alpha:1.0];
        [_overlayToggleButton setTitleColor:[UIColor colorWithRed:0.02 green:0.12 blue:0.06 alpha:1.0] forState:UIControlStateNormal];
    }
}

- (void)toggleOverlayTapped {
    [[HUDLauncher sharedLauncher] toggleHUD];
    [self refreshState];
}

- (void)resetHUDPositionsTapped {
    [[HUDLauncher sharedLauncher] resetHUDPositions];
    [self addLog:@"[OK] Đã đặt lại vị trí 3 nút nổi về mặc định!"];
}

- (void)showFakeLagChanged:(UISwitch *)sender {
    [RemoteLinkManager sharedManager].showFakeLagInHUD = sender.isOn;
    [[RemoteLinkManager sharedManager] saveAllConfigs];
}

- (void)showTeleKillChanged:(UISwitch *)sender {
    [RemoteLinkManager sharedManager].showTeleKillInHUD = sender.isOn;
    [[RemoteLinkManager sharedManager] saveAllConfigs];
}

- (void)showGhostChanged:(UISwitch *)sender {
    [RemoteLinkManager sharedManager].showGhostInHUD = sender.isOn;
    [[RemoteLinkManager sharedManager] saveAllConfigs];
}

- (void)fakeLagSwitchChanged:(UISwitch *)sender {
    [[RemoteLinkManager sharedManager] setFeature:RemoteFeatureFakeLag active:sender.isOn completion:nil];
}

- (void)teleKillSwitchChanged:(UISwitch *)sender {
    [[RemoteLinkManager sharedManager] setFeature:RemoteFeatureTeleKill active:sender.isOn completion:nil];
}

- (void)ghostSwitchChanged:(UISwitch *)sender {
    [[RemoteLinkManager sharedManager] setFeature:RemoteFeatureGhost active:sender.isOn completion:nil];
}

- (void)offAllTapped {
    [[RemoteLinkManager sharedManager] turnOffAllFeaturesWithCompletion:nil];
}

- (void)applyServerUrlTapped {
    NSString *url = _serverUrlField.text ?: @"";
    if (url.length == 0) {
        [self addLog:@"[ERR] Vui lòng nhập Server Base URL"];
        return;
    }
    [[RemoteLinkManager sharedManager] applyBaseUrlToAllFeatures:url];
    [self.view endEditing:YES];
    [self refreshState];
    [self addLog:[NSString stringWithFormat:@"[OK] Đã tự động tạo 3 link cho Server: %@", url]];
}

- (void)saveAllLinksTapped {
    RemoteLinkManager *mgr = [RemoteLinkManager sharedManager];
    mgr.serverBaseUrl = _serverUrlField.text ?: @"";
    mgr.fakeLagConfig.urlOn = _fakeLagUrlField.text ?: @"";
    mgr.teleKillConfig.urlOn = _teleKillUrlField.text ?: @"";
    mgr.ghostConfig.urlOn = _ghostUrlField.text ?: @"";
    [mgr saveAllConfigs];
    [self.view endEditing:YES];
    [self addLog:@"[OK] Đã lưu toàn bộ cấu hình link URL vào bộ nhớ!"];
}

- (void)testFakeLagTapped {
    [self testUrl:_fakeLagUrlField.text name:@"Freeze (FakeLag)"];
}

- (void)testTeleKillTapped {
    [self testUrl:_teleKillUrlField.text name:@"TeleKill"];
}

- (void)testGhostTapped {
    [self testUrl:_ghostUrlField.text name:@"Ghost Lag"];
}

- (void)testUrl:(NSString *)url name:(NSString *)name {
    if (!url || url.length == 0) {
        [self addLog:[NSString stringWithFormat:@"[ERR] Link %@ đang rỗng", name]];
        return;
    }
    [self addLog:[NSString stringWithFormat:@"[TEST] Đang gửi GET %@...", name]];
    [[RemoteLinkManager sharedManager] executeGetUrl:url completion:^(BOOL success, NSString * _Nullable responseText, NSInteger statusCode) {
        NSString *msg = [NSString stringWithFormat:@"Status: %ld | Phản hồi: %@", (long)statusCode, responseText ?: @"None"];
        UIAlertController *resAlert = [UIAlertController alertControllerWithTitle:success ? @"✅ GET Thành Công" : @"❌ GET Thất Bại"
                                                                         message:msg
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [resAlert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:resAlert animated:YES completion:nil];
    }];
}

- (void)openSettingsTapped {
    SettingsViewController *vc = [[SettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)dealloc {
    if (_remoteNotifyToken > 0) {
        notify_cancel(_remoteNotifyToken);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
