#import "MainViewController.h"
#import "SettingsViewController.h"

@interface MainViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

// Overlay Card
@property (nonatomic, strong) UIView *overlayCard;
@property (nonatomic, strong) UIButton *startOverlayButton;
@property (nonatomic, strong) UILabel *overlayStatusLabel;

// VPN Card
@property (nonatomic, strong) UIView *vpnCard;
@property (nonatomic, strong) UIButton *vpnToggleButton;
@property (nonatomic, strong) UILabel *vpnStatusLabel;

// Live Stats Card
@property (nonatomic, strong) UIView *statsCard;
@property (nonatomic, strong) UILabel *packetsValueLabel;
@property (nonatomic, strong) UILabel *bytesValueLabel;
@property (nonatomic, strong) UILabel *ppsValueLabel;
@property (nonatomic, strong) UILabel *speedValueLabel;

// Controls Card
@property (nonatomic, strong) UIView *controlsCard;
@property (nonatomic, strong) UISlider *rateSlider;
@property (nonatomic, strong) UILabel *rateValueLabel;
@property (nonatomic, strong) UISlider *sizeSlider;
@property (nonatomic, strong) UILabel *sizeValueLabel;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"FakeLag";
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.09 alpha:1.0];
    
    [VPNManager sharedManager].delegate = self;
    [PacketEngine sharedEngine].delegate = self;
    
    [self setupNavigation];
    [self setupUI];
    [self refreshState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshState];
}

- (void)setupNavigation {
    [self.navigationController.navigationBar setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [UIFont systemFontOfSize:18 weight:UIFontWeightBold]
    }];
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.12 alpha:1.0];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
    
    UIBarButtonItem *settingsBtn = [[UIBarButtonItem alloc] initWithTitle:@"Cài Đặt"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(openSettings)];
    self.navigationItem.rightBarButtonItem = settingsBtn;
}

- (void)setupUI {
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];
    
    _contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 950)];
    [_scrollView addSubview:_contentView];
    
    CGFloat width = self.view.bounds.size.width - 32;
    CGFloat currentY = 16.0;
    
    // Header Banner
    UIView *bannerView = [[UIView alloc] initWithFrame:CGRectMake(16, currentY, width, 80)];
    bannerView.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:1.0];
    bannerView.layer.cornerRadius = 16.0;
    bannerView.layer.borderWidth = 1.0;
    bannerView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, width - 32, 26)];
    titleLabel.text = @"⚡ FAKELAG TROLLSTORE";
    titleLabel.textColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.48 alpha:1.0];
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy];
    [bannerView addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 42, width - 32, 24)];
    subtitleLabel.text = @"Nổi Nút Tròn Xanh • Gửi Túi Tin Random Qua VPN";
    subtitleLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    subtitleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    [bannerView addSubview:subtitleLabel];
    
    [_contentView addSubview:bannerView];
    currentY += 92.0;
    
    // 1. Overlay Control Card
    _overlayCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 145) title:@"1. NÚT NỔI OVERLAY (TROLLSPEED)"];
    
    _overlayStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 44, width - 32, 22)];
    _overlayStatusLabel.text = @"Trạng Thái: Chưa kích hoạt";
    _overlayStatusLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    _overlayStatusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [_overlayCard addSubview:_overlayStatusLabel];
    
    _startOverlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _startOverlayButton.frame = CGRectMake(16, 78, width - 32, 50);
    _startOverlayButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.80 blue:0.42 alpha:1.0];
    _startOverlayButton.layer.cornerRadius = 12.0;
    [_startOverlayButton setTitle:@"▶ BẬT NÚT NỔI OVERLAY" forState:UIControlStateNormal];
    [_startOverlayButton setTitleColor:[UIColor colorWithRed:0.05 green:0.15 blue:0.08 alpha:1.0] forState:UIControlStateNormal];
    _startOverlayButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [_startOverlayButton addTarget:self action:@selector(toggleOverlayTapped) forControlEvents:UIControlEventTouchUpInside];
    [_overlayCard addSubview:_startOverlayButton];
    
    [_contentView addSubview:_overlayCard];
    currentY += 157.0;
    
    // 2. VPN Card
    _vpnCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 145) title:@"2. VPN & CẤP QUYỀN HỆ THỐNG"];
    
    _vpnStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 44, width - 32, 22)];
    _vpnStatusLabel.text = @"VPN: Đã sẵn sàng";
    _vpnStatusLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    _vpnStatusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [_vpnCard addSubview:_vpnStatusLabel];
    
    _vpnToggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _vpnToggleButton.frame = CGRectMake(16, 78, width - 32, 50);
    _vpnToggleButton.backgroundColor = [UIColor colorWithRed:0.18 green:0.20 blue:0.26 alpha:1.0];
    _vpnToggleButton.layer.cornerRadius = 12.0;
    [_vpnToggleButton setTitle:@"🚀 BẬT GỬI TÚI TIN RANDOM" forState:UIControlStateNormal];
    [_vpnToggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _vpnToggleButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [_vpnToggleButton addTarget:self action:@selector(toggleVPNTapped) forControlEvents:UIControlEventTouchUpInside];
    [_vpnCard addSubview:_vpnToggleButton];
    
    [_contentView addSubview:_vpnCard];
    currentY += 157.0;
    
    // 3. Live Metrics Card
    _statsCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 160) title:@"3. THÔNG SỐ TÚI TIN RANDOM ĐÃ GỬI"];
    
    CGFloat colW = (width - 48) / 2.0;
    
    _packetsValueLabel = [self createStatItemInView:_statsCard frame:CGRectMake(16, 46, colW, 45) title:@"Tổng Túi Tin Đã Gửi" defaultVal:@"0 pkts"];
    _bytesValueLabel = [self createStatItemInView:_statsCard frame:CGRectMake(24 + colW, 46, colW, 45) title:@"Dung Lượng Gửi" defaultVal:@"0.0 KB"];
    _ppsValueLabel = [self createStatItemInView:_statsCard frame:CGRectMake(16, 100, colW, 45) title:@"Tốc Độ (PPS)" defaultVal:@"0 pps"];
    _speedValueLabel = [self createStatItemInView:_statsCard frame:CGRectMake(24 + colW, 100, colW, 45) title:@"Lưu Lượng" defaultVal:@"0.0 KB/s"];
    
    [_contentView addSubview:_statsCard];
    currentY += 172.0;
    
    // 4. Rate & Packet Size Sliders
    _controlsCard = [self createCardWithFrame:CGRectMake(16, currentY, width, 180) title:@"4. TÙY CHỈNH TỐC ĐỘ GỬI TÚI TIN"];
    
    UILabel *rateTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 42, 180, 20)];
    rateTitle.text = @"Tốc độ gửi (PPS):";
    rateTitle.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    rateTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [_controlsCard addSubview:rateTitle];
    
    _rateValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - 120, 42, 104, 20)];
    _rateValueLabel.text = @"1500 pps";
    _rateValueLabel.textColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
    _rateValueLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    _rateValueLabel.textAlignment = NSTextAlignmentRight;
    [_controlsCard addSubview:_rateValueLabel];
    
    _rateSlider = [[UISlider alloc] initWithFrame:CGRectMake(16, 66, width - 32, 30)];
    _rateSlider.minimumValue = 100;
    _rateSlider.maximumValue = 5000;
    _rateSlider.value = 1500;
    _rateSlider.tintColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
    [_rateSlider addTarget:self action:@selector(rateSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_controlsCard addSubview:_rateSlider];
    
    UILabel *sizeTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 106, 180, 20)];
    sizeTitle.text = @"Kích thước túi tin (Bytes):";
    sizeTitle.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    sizeTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [_controlsCard addSubview:sizeTitle];
    
    _sizeValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - 120, 106, 104, 20)];
    _sizeValueLabel.text = @"1024 B";
    _sizeValueLabel.textColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
    _sizeValueLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    _sizeValueLabel.textAlignment = NSTextAlignmentRight;
    [_controlsCard addSubview:_sizeValueLabel];
    
    _sizeSlider = [[UISlider alloc] initWithFrame:CGRectMake(16, 130, width - 32, 30)];
    _sizeSlider.minimumValue = 128;
    _sizeSlider.maximumValue = 1400;
    _sizeSlider.value = 1024;
    _sizeSlider.tintColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
    [_sizeSlider addTarget:self action:@selector(sizeSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_controlsCard addSubview:_sizeSlider];
    
    [_contentView addSubview:_controlsCard];
    currentY += 192.0;
    
    // Instructions note
    UILabel *instructions = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, width - 8, 80)];
    instructions.numberOfLines = 0;
    instructions.text = @"💡 Hướng dẫn:\n• Bấm 'Bật Nút Nổi' để hiển thị nút tròn xanh 'fakelag'.\n• Ra màn hình chính hoặc vào game, kéo nút tròn đến vị trí bạn muốn.\n• Chạm nút tròn để BẬT gửi túi tin random qua VPN (tạo fake lag / đơ đối phương). Chạm lại để TẮT.";
    instructions.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    instructions.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    [_contentView addSubview:instructions];
    currentY += 90;
    
    _contentView.frame = CGRectMake(0, 0, self.view.bounds.size.width, currentY + 40);
    _scrollView.contentSize = _contentView.frame.size;
}

- (UIView *)createCardWithFrame:(CGRect)frame title:(NSString *)title {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.15 alpha:1.0];
    card.layer.cornerRadius = 14.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.07].CGColor;
    
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, frame.size.width - 32, 22)];
    titleLbl.text = title;
    titleLbl.textColor = [UIColor colorWithWhite:0.90 alpha:1.0];
    titleLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    [card addSubview:titleLbl];
    
    return card;
}

- (UILabel *)createStatItemInView:(UIView *)parent frame:(CGRect)frame title:(NSString *)title defaultVal:(NSString *)defaultVal {
    UIView *item = [[UIView alloc] initWithFrame:frame];
    item.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.11 alpha:1.0];
    item.layer.cornerRadius = 8.0;
    
    UILabel *tLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, frame.size.width - 16, 16)];
    tLbl.text = title;
    tLbl.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    tLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    [item addSubview:tLbl];
    
    UILabel *vLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 20, frame.size.width - 16, 20)];
    vLbl.text = defaultVal;
    vLbl.textColor = [UIColor whiteColor];
    vLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [item addSubview:vLbl];
    
    [parent addSubview:item];
    return vLbl;
}

- (void)refreshState {
    BOOL hudRunning = [HUDLauncher sharedLauncher].isHUDRunning;
    if (hudRunning) {
        _overlayStatusLabel.text = [NSString stringWithFormat:@"Trạng Thái: Đang chạy (PID: %d)", [HUDLauncher sharedLauncher].hudPid];
        _overlayStatusLabel.textColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
        [_startOverlayButton setTitle:@"⏹ TẮT NÚT NỔI OVERLAY" forState:UIControlStateNormal];
        _startOverlayButton.backgroundColor = [UIColor colorWithRed:0.90 green:0.20 blue:0.25 alpha:1.0];
        [_startOverlayButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        _overlayStatusLabel.text = @"Trạng Thái: Đang tắt";
        _overlayStatusLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
        [_startOverlayButton setTitle:@"▶ BẬT NÚT NỔI OVERLAY" forState:UIControlStateNormal];
        _startOverlayButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.80 blue:0.42 alpha:1.0];
        [_startOverlayButton setTitleColor:[UIColor colorWithRed:0.05 green:0.15 blue:0.08 alpha:1.0] forState:UIControlStateNormal];
    }
    
    BOOL isLag = [VPNManager sharedManager].isLagActive;
    if (isLag) {
        _vpnStatusLabel.text = @"VPN: ĐANG GỬI TÚI TIN RANDOM LIÊN TỤC";
        _vpnStatusLabel.textColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.35 alpha:1.0];
        [_vpnToggleButton setTitle:@"⏹ DỪNG GỬI TÚI TIN" forState:UIControlStateNormal];
        _vpnToggleButton.backgroundColor = [UIColor colorWithRed:0.85 green:0.15 blue:0.22 alpha:1.0];
    } else {
        _vpnStatusLabel.text = @"VPN: Đã dừng (Bình thường)";
        _vpnStatusLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
        [_vpnToggleButton setTitle:@"🚀 BẬT GỬI TÚI TIN RANDOM" forState:UIControlStateNormal];
        _vpnToggleButton.backgroundColor = [UIColor colorWithRed:0.18 green:0.20 blue:0.26 alpha:1.0];
    }
}

- (void)toggleOverlayTapped {
    [[HUDLauncher sharedLauncher] toggleHUD];
    [self refreshState];
}

- (void)toggleVPNTapped {
    __weak typeof(self) weakSelf = self;
    [[VPNManager sharedManager] toggleVPNWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lỗi Cấp Quyền VPN"
                                                                               message:error.localizedDescription
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [weakSelf presentViewController:alert animated:YES completion:nil];
            }
            [weakSelf refreshState];
        });
    }];
}

- (void)rateSliderChanged:(UISlider *)sender {
    NSUInteger pps = (NSUInteger)sender.value;
    _rateValueLabel.text = [NSString stringWithFormat:@"%lu pps", (unsigned long)pps];
    [PacketEngine sharedEngine].packetsPerSecond = pps;
}

- (void)sizeSliderChanged:(UISlider *)sender {
    NSUInteger size = (NSUInteger)sender.value;
    _sizeValueLabel.text = [NSString stringWithFormat:@"%lu B", (unsigned long)size];
    [PacketEngine sharedEngine].packetSize = size;
}

- (void)openSettings {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - VPNManagerDelegate

- (void)vpnManagerDidChangeState:(FakeLagVPNState)state statusString:(NSString *)statusString {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshState];
    });
}

#pragma mark - PacketEngineDelegate

- (void)packetEngineDidUpdateStatsWithPackets:(NSUInteger)totalPackets bytes:(NSUInteger)totalBytes packetsSec:(NSUInteger)pps bytesSec:(NSUInteger)bps bufferedPkts:(NSUInteger)buffered {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.packetsValueLabel.text = [NSString stringWithFormat:@"%lu pkts", (unsigned long)totalPackets];
        
        if (totalBytes > 1024 * 1024) {
            self.bytesValueLabel.text = [NSString stringWithFormat:@"%.2f MB", totalBytes / (1024.0 * 1024.0)];
        } else {
            self.bytesValueLabel.text = [NSString stringWithFormat:@"%.1f KB", totalBytes / 1024.0];
        }
        
        self.ppsValueLabel.text = [NSString stringWithFormat:@"%lu pps", (unsigned long)pps];
        
        if (bps > 1024 * 1024) {
            self.speedValueLabel.text = [NSString stringWithFormat:@"%.2f MB/s", bps / (1024.0 * 1024.0)];
        } else {
            self.speedValueLabel.text = [NSString stringWithFormat:@"%.1f KB/s", bps / 1024.0];
        }
    });
}

- (void)packetEngineStateChanged:(BOOL)isRunning {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshState];
    });
}

- (void)packetEngineModeChanged:(FakeLagMode)mode {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshState];
    });
}

@end
