#import "MainViewController.h"
#import "SettingsViewController.h"
#import "RemoteLinkManager.h"
#import "HUDLauncher.h"

@interface MainViewController () {
    UISwitch *_fakeLagSwitch;
    UISwitch *_teleKillSwitch;
    UISwitch *_ghostSwitch;
    
    UIButton *_overlayToggleButton;
    UIButton *_rotateHUDButton;
    UILabel *_overlayStatusLabel;
    
    UITextField *_serverUrlField;
    UITextView *_logTextView;
    NSMutableArray<NSString *> *_logs;
}

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"VIP Remote Control";
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.10 alpha:1.0];
    
    _logs = [NSMutableArray array];
    
    // Nút Cài Đặt trên Navigation Bar
    UIBarButtonItem *settingsBtn = [[UIBarButtonItem alloc] initWithTitle:@"⚙️ Cài Đặt"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(openSettingsTapped)];
    settingsBtn.tintColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:1.0];
    self.navigationItem.rightBarButtonItem = settingsBtn;
    
    [self setupUI];
    [self setupLogHandler];
    [self setupNotifications];
    [self refreshState];
}

- (void)setupUI {
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];
    
    _contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 980)];
    [_scrollView addSubview:_contentView];
    
    CGFloat width = self.view.bounds.size.width - 32;
    CGFloat currentY = 16.0;
    
    // 1. Header Banner
    UIView *bannerView = [[UIView alloc] initWithFrame:CGRectMake(16, currentY, width, 84)];
    bannerView.backgroundColor = [UIColor colorWithRed:0.09 green:0.12 blue:0.16 alpha:1.0];
    bannerView.layer.cornerRadius = 16.0;
    bannerView.layer.borderWidth = 1.2;
    bannerView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:0.35].CGColor;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, width - 32, 26)];
    titleLabel.text = @"⚡ HOANGHA VIP REMOTE";
    titleLabel.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy];
    [bannerView addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 44, width - 32, 24)];
    subtitleLabel.text = @"Bảng Nổi 3 Toggle • Hỗ Trợ Xoay Ngang / Dọc Toàn Cầu";
    subtitleLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    subtitleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    [bannerView addSubview:subtitleLabel];
    
    [_contentView addSubview:bannerView];
    currentY += 96.0;
    
    // 2. Card: Nút Nổi Overlay (HUD Launcher)
    UIView *hudCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 186) title:@"1. BẢNG NÚT NỔI OVERLAY (3 TOGGLE)"];
    
    _overlayStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 40, width - 32, 22)];
    _overlayStatusLabel.text = @"Trạng Thái: Chưa kích hoạt";
    _overlayStatusLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    _overlayStatusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [hudCard addSubview:_overlayStatusLabel];
    
    _overlayToggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _overlayToggleButton.frame = CGRectMake(16, 70, width - 32, 46);
    _overlayToggleButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.80 blue:0.42 alpha:1.0];
    _overlayToggleButton.layer.cornerRadius = 12.0;
    [_overlayToggleButton setTitle:@"▶ BẬT BẢNG NÚT NỔI TRÊN MÀN HÌNH" forState:UIControlStateNormal];
    [_overlayToggleButton setTitleColor:[UIColor colorWithRed:0.05 green:0.15 blue:0.08 alpha:1.0] forState:UIControlStateNormal];
    _overlayToggleButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [_overlayToggleButton addTarget:self action:@selector(toggleOverlayTapped) forControlEvents:UIControlEventTouchUpInside];
    [hudCard addSubview:_overlayToggleButton];
    
    _rotateHUDButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _rotateHUDButton.frame = CGRectMake(16, 126, width - 32, 44);
    _rotateHUDButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.19 blue:0.26 alpha:1.0];
    _rotateHUDButton.layer.cornerRadius = 10.0;
    _rotateHUDButton.layer.borderWidth = 1.0;
    _rotateHUDButton.layer.borderColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:0.4].CGColor;
    [_rotateHUDButton setTitle:@"🔄 XOAY HƯỚNG NÚT NỔI (NGANG / DỌC)" forState:UIControlStateNormal];
    [_rotateHUDButton setTitleColor:[UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0] forState:UIControlStateNormal];
    _rotateHUDButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [_rotateHUDButton addTarget:self action:@selector(rotateHUDTapped) forControlEvents:UIControlEventTouchUpInside];
    [hudCard addSubview:_rotateHUDButton];
    
    [_contentView addSubview:hudCard];
    currentY += 198.0;
    
    // 3. Card: 3 Tính Năng Điều Khiển Trong App
    UIView *featureCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 225) title:@"2. BỘ ĐIỀU KHIỂN 3 TÍNH NĂNG"];
    
    CGFloat rowW = width - 32;
    CGFloat fStartY = 42;
    
    // Row 1: FakeLag
    _fakeLagSwitch = [self addFeatureRowToCard:featureCard frame:CGRectMake(16, fStartY, rowW, 38)
                                          icon:@"🧊" name:@"FakeLag (Freeze)"
                                         color:[UIColor colorWithRed:0.0 green:0.75 blue:1.0 alpha:1.0]
                                        action:@selector(fakeLagSwitchChanged:)];
    
    // Row 2: TeleKill
    _teleKillSwitch = [self addFeatureRowToCard:featureCard frame:CGRectMake(16, fStartY + 44, rowW, 38)
                                           icon:@"⚡" name:@"TeleKill"
                                          color:[UIColor colorWithRed:1.0 green:0.35 blue:0.1 alpha:1.0]
                                         action:@selector(teleKillSwitchChanged:)];
    
    // Row 3: Ghost
    _ghostSwitch = [self addFeatureRowToCard:featureCard frame:CGRectMake(16, fStartY + 88, rowW, 38)
                                        icon:@"👻" name:@"Ghost Lag"
                                       color:[UIColor colorWithRed:0.75 green:0.45 blue:1.0 alpha:1.0]
                                      action:@selector(ghostSwitchChanged:)];
    
    // Nút "🔴 TẮT TOÀN BỘ"
    UIButton *offAllBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    offAllBtn.frame = CGRectMake(16, fStartY + 134, rowW, 38);
    offAllBtn.backgroundColor = [UIColor colorWithRed:0.9 green:0.15 blue:0.25 alpha:0.2];
    offAllBtn.layer.cornerRadius = 10.0;
    offAllBtn.layer.borderWidth = 1.0;
    offAllBtn.layer.borderColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.3 alpha:0.5].CGColor;
    [offAllBtn setTitle:@"🔴 TẮT TOÀN BỘ (GỬI LỆNH OFF)" forState:UIControlStateNormal];
    [offAllBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
    offAllBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [offAllBtn addTarget:self action:@selector(offAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [featureCard addSubview:offAllBtn];
    
    [_contentView addSubview:featureCard];
    currentY += 237.0;
    
    // 4. Card: Cấu Hình Nhanh Server URL
    UIView *serverCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 145) title:@"3. CẤU HÌNH NHANH SERVER URL"];
    
    _serverUrlField = [[UITextField alloc] initWithFrame:CGRectMake(16, 42, width - 32, 40)];
    _serverUrlField.backgroundColor = [UIColor colorWithRed:0.07 green:0.09 blue:0.12 alpha:1.0];
    _serverUrlField.layer.cornerRadius = 8.0;
    _serverUrlField.layer.borderWidth = 1.0;
    _serverUrlField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    _serverUrlField.textColor = [UIColor whiteColor];
    _serverUrlField.font = [UIFont systemFontOfSize:13];
    _serverUrlField.placeholder = @"https://abc.trycloudflare.com";
    _serverUrlField.text = [RemoteLinkManager sharedManager].serverBaseUrl;
    _serverUrlField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _serverUrlField.autocorrectionType = UITextAutocorrectionTypeNo;
    _serverUrlField.keyboardType = UIKeyboardTypeURL;
    _serverUrlField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [serverCard addSubview:_serverUrlField];
    
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    applyBtn.frame = CGRectMake(16, 90, width - 32, 42);
    applyBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.55 blue:0.95 alpha:1.0];
    applyBtn.layer.cornerRadius = 10.0;
    [applyBtn setTitle:@"⚡ TỰ ĐỘNG TẠO & LƯU 3 LINK" forState:UIControlStateNormal];
    [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    applyBtn.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    [applyBtn addTarget:self action:@selector(applyServerUrlTapped) forControlEvents:UIControlEventTouchUpInside];
    [serverCard addSubview:applyBtn];
    
    [_contentView addSubview:serverCard];
    currentY += 157.0;
    
    // 5. Card: Nhật Ký Gửi URL (Log View)
    UIView *logCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 180) title:@"4. NHẬT KÝ GỬI URL (LIVE LOG)"];
    
    _logTextView = [[UITextView alloc] initWithFrame:CGRectMake(16, 42, width - 32, 124)];
    _logTextView.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.07 alpha:1.0];
    _logTextView.layer.cornerRadius = 8.0;
    _logTextView.textColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.55 alpha:1.0];
    _logTextView.font = [UIFont fontWithName:@"Courier" size:11.0] ?: [UIFont systemFontOfSize:11.0];
    _logTextView.editable = NO;
    _logTextView.text = @"[INFO] Sẵn sàng gửi GET request...\n";
    [logCard addSubview:_logTextView];
    
    [_contentView addSubview:logCard];
}

- (UIView *)createCardWithFrame:(CGRect)frame title:(NSString *)title {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:0.95];
    card.layer.cornerRadius = 14.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, frame.size.width - 32, 20)];
    lbl.text = title;
    lbl.textColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:1.0];
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    [card addSubview:lbl];
    
    return card;
}

- (UISwitch *)addFeatureRowToCard:(UIView *)card frame:(CGRect)frame icon:(NSString *)icon name:(NSString *)name color:(UIColor *)color action:(SEL)action {
    UIView *row = [[UIView alloc] initWithFrame:frame];
    row.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.11 alpha:0.8];
    row.layer.cornerRadius = 8.0;
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, frame.size.width - 80, frame.size.height)];
    title.text = [NSString stringWithFormat:@"%@ %@", icon, name];
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    [row addSubview:title];
    
    UISwitch *sw = [[UISwitch alloc] init];
    sw.center = CGPointMake(frame.size.width - 32, frame.size.height / 2.0);
    sw.onTintColor = color;
    sw.transform = CGAffineTransformMakeScale(0.78, 0.78);
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    
    [card addSubview:row];
    return sw;
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshState)
                                                 name:RemoteLinkStateChangedNotification
                                               object:nil];
}

- (void)refreshState {
    RemoteLinkManager *mgr = [RemoteLinkManager sharedManager];
    [_fakeLagSwitch setOn:mgr.fakeLagConfig.isActive animated:YES];
    [_teleKillSwitch setOn:mgr.teleKillConfig.isActive animated:YES];
    [_ghostSwitch setOn:mgr.ghostConfig.isActive animated:YES];
    
    BOOL hudRunning = [HUDLauncher sharedLauncher].isHUDRunning;
    if (hudRunning) {
        _overlayStatusLabel.text = @"Trạng Thái: Đang hiển thị trên màn hình";
        _overlayStatusLabel.textColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
        [_overlayToggleButton setTitle:@"⏹ TẮT BẢNG NÚT NỔI OVERLAY" forState:UIControlStateNormal];
        _overlayToggleButton.backgroundColor = [UIColor colorWithRed:0.90 green:0.20 blue:0.25 alpha:1.0];
        [_overlayToggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        _overlayStatusLabel.text = @"Trạng Thái: Đang tắt";
        _overlayStatusLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
        [_overlayToggleButton setTitle:@"▶ BẬT BẢNG NÚT NỔI TRÊN MÀN HÌNH" forState:UIControlStateNormal];
        _overlayToggleButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.80 blue:0.42 alpha:1.0];
        [_overlayToggleButton setTitleColor:[UIColor colorWithRed:0.05 green:0.15 blue:0.08 alpha:1.0] forState:UIControlStateNormal];
    }
}

- (void)toggleOverlayTapped {
    [[HUDLauncher sharedLauncher] toggleHUD];
    [self refreshState];
}

- (void)rotateHUDTapped {
    [[HUDLauncher sharedLauncher] toggleOrientation];
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
    [self addLog:[NSString stringWithFormat:@"[OK] Đã tự động tạo và lưu 3 Link cho server: %@", url]];
}

- (void)openSettingsTapped {
    SettingsViewController *vc = [[SettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
