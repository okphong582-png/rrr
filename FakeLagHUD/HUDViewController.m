#import "HUDViewController.h"
#import "VPNManager.h"
#import "PacketEngine.h"
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>

static NSString * const kSavedPosXKey = @"FakeLag_Button_X";
static NSString * const kSavedPosYKey = @"FakeLag_Button_Y";

@interface HUDViewController () {
    CGPoint _initialTouchOffset;
    int _notifyToken;
    CALayer *_pulseLayer;
    UIImpactFeedbackGenerator *_feedbackGenerator;
}

@property (nonatomic, strong, readwrite) UIView *floatingContainer;
@property (nonatomic, strong, readwrite) UIButton *fakelagButton;
@property (nonatomic, strong) UILabel *statusLabel;

@end

@implementation HUDViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        (void)self.view; // Force view to load immediately
    }
    return self;
}

- (void)loadView {
    CGRect bounds = [UIScreen mainScreen].bounds;
    self.view = [[UIView alloc] initWithFrame:bounds];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
    self.view.clipsToBounds = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [_feedbackGenerator prepare];
    
    [self setupFloatingButton];
    [self setupPanGesture];
    [self setupDarwinNotifications];
    [self restoreLastSavedPosition];
    [self refreshInitialState];
}

- (void)setupFloatingButton {
    CGFloat buttonSize = 68.0;
    
    _floatingContainer = [[UIView alloc] initWithFrame:CGRectMake(30, 160, buttonSize, buttonSize)];
    _floatingContainer.backgroundColor = [UIColor clearColor];
    _floatingContainer.clipsToBounds = NO;
    _floatingContainer.userInteractionEnabled = YES;
    
    // Pulse animation ring
    _pulseLayer = [CALayer layer];
    _pulseLayer.frame = CGRectMake(-8, -8, buttonSize + 16, buttonSize + 16);
    _pulseLayer.cornerRadius = (buttonSize + 16) / 2.0;
    _pulseLayer.backgroundColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.25 alpha:0.4].CGColor;
    _pulseLayer.opacity = 0.0;
    [_floatingContainer.layer addSublayer:_pulseLayer];
    
    // Nút tròn xanh có chữ "fakelag"
    _fakelagButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _fakelagButton.frame = CGRectMake(0, 0, buttonSize, buttonSize);
    _fakelagButton.layer.cornerRadius = buttonSize / 2.0;
    _fakelagButton.clipsToBounds = YES;
    _fakelagButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0]; // Neon Green
    _fakelagButton.layer.borderWidth = 2.5;
    _fakelagButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.9].CGColor;
    
    [_fakelagButton setTitle:@"fakelag" forState:UIControlStateNormal];
    [_fakelagButton setTitleColor:[UIColor colorWithRed:0.02 green:0.12 blue:0.06 alpha:1.0] forState:UIControlStateNormal];
    _fakelagButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    _fakelagButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    
    _floatingContainer.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.4 alpha:0.6].CGColor;
    _floatingContainer.layer.shadowOffset = CGSizeMake(0, 4);
    _floatingContainer.layer.shadowRadius = 8.0;
    _floatingContainer.layer.shadowOpacity = 0.8;
    
    [_fakelagButton addTarget:self action:@selector(handleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.6;
    [_fakelagButton addGestureRecognizer:longPress];
    
    [_floatingContainer addSubview:_fakelagButton];
    [self.view addSubview:_floatingContainer];
}

- (void)setupPanGesture {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_floatingContainer addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.view];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        [UIView animateWithDuration:0.15 animations:^{
            self.floatingContainer.transform = CGAffineTransformMakeScale(1.1, 1.1);
            self.floatingContainer.alpha = 0.9;
        }];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint center = self.floatingContainer.center;
        center.x += translation.x;
        center.y += translation.y;
        
        CGFloat radius = self.floatingContainer.bounds.size.width / 2.0;
        CGFloat minX = radius + 8;
        CGFloat maxX = self.view.bounds.size.width - radius - 8;
        CGFloat minY = radius + 40;
        CGFloat maxY = self.view.bounds.size.height - radius - 30;
        
        center.x = MAX(minX, MIN(maxX, center.x));
        center.y = MAX(minY, MIN(maxY, center.y));
        
        self.floatingContainer.center = center;
        [pan setTranslation:CGPointZero inView:self.view];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.35
                              delay:0
             usingSpringWithDamping:0.75
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.floatingContainer.transform = CGAffineTransformIdentity;
            self.floatingContainer.alpha = 1.0;
            
            CGPoint center = self.floatingContainer.center;
            CGFloat screenWidth = self.view.bounds.size.width;
            CGFloat radius = self.floatingContainer.bounds.size.width / 2.0;
            
            if (center.x < screenWidth / 2.0) {
                center.x = radius + 12.0;
            } else {
                center.x = screenWidth - radius - 12.0;
            }
            self.floatingContainer.center = center;
        } completion:^(BOOL finished) {
            [self saveCurrentPosition];
        }];
    }
}

// Bấm nút tròn để BẬT gửi túi tin random qua VPN / TẮT dừng gửi
- (void)handleButtonTap:(UIButton *)sender {
    [_feedbackGenerator impactOccurred];
    
    BOOL isLagNow = ![VPNManager sharedManager].isLagActive;
    
    if (isLagNow) {
        // Yêu cầu cấp quyền VPN thật và kích hoạt gửi túi tin
        [[VPNManager sharedManager] startVPNWithCompletion:^(BOOL success, NSError * _Nullable error) {
            if (error) {
                NSLog(@"[HUD] Lỗi khởi động VPN: %@", error.localizedDescription);
            }
        }];
    } else {
        // Dừng gửi túi tin
        [[VPNManager sharedManager] stopVPNWithCompletion:^(BOOL success, NSError * _Nullable error) {
            if (error) {
                NSLog(@"[HUD] Lỗi dừng VPN: %@", error.localizedDescription);
            }
        }];
    }
    
    [self updateButtonUIForLagState:isLagNow];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        AudioServicesPlaySystemSound(1520);
        [self showHUDMenu];
    }
}

- (void)showHUDMenu {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚡ FAKELAG OVERLAY"
                                                                   message:@"Tùy chọn nhanh:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"🔄 Reset Vị Trí Về Mặc Định"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [UIView animateWithDuration:0.3 animations:^{
            self.floatingContainer.center = CGPointMake(50, 180);
            [self saveCurrentPosition];
        }];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"❌ Ẩn Nút Nổi"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        self.view.window.hidden = YES;
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateButtonUIForLagState:(BOOL)isLagActive {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isLagActive) {
            // === ĐANG BẬT FREEZE: CHUYỂN NÚT SANG ĐỎ PHÁT SÁNG "LAG ON" ===
            self.fakelagButton.backgroundColor = [UIColor colorWithRed:0.95 green:0.15 blue:0.25 alpha:1.0];
            self.fakelagButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.80 blue:0.80 alpha:1.0].CGColor;
            [self.fakelagButton setTitle:@"LAG ON" forState:UIControlStateNormal];
            [self.fakelagButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self.floatingContainer.layer.shadowColor = [UIColor colorWithRed:1.0 green:0.10 blue:0.20 alpha:0.9].CGColor;
            
            [self startPulseAnimation];
        } else {
            // === ĐANG TẮT: NÚT TRÒN XANH "fakelag" BÌNH THƯỜNG ===
            self.fakelagButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
            self.fakelagButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.9].CGColor;
            [self.fakelagButton setTitle:@"fakelag" forState:UIControlStateNormal];
            [self.fakelagButton setTitleColor:[UIColor colorWithRed:0.02 green:0.12 blue:0.06 alpha:1.0] forState:UIControlStateNormal];
            self.floatingContainer.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.4 alpha:0.6].CGColor;
            
            [self stopPulseAnimation];
        }
    });
}

- (void)startPulseAnimation {
    [_pulseLayer removeAllAnimations];
    _pulseLayer.opacity = 1.0;
    
    CABasicAnimation *scaleAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnim.fromValue = @(1.0);
    scaleAnim.toValue = @(1.35);
    scaleAnim.duration = 0.8;
    scaleAnim.repeatCount = HUGE_VALF;
    scaleAnim.autoreverses = YES;
    scaleAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    CABasicAnimation *opacityAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnim.fromValue = @(0.7);
    opacityAnim.toValue = @(0.1);
    opacityAnim.duration = 0.8;
    opacityAnim.repeatCount = HUGE_VALF;
    opacityAnim.autoreverses = YES;
    opacityAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [_pulseLayer addAnimation:scaleAnim forKey:@"scale"];
    [_pulseLayer addAnimation:opacityAnim forKey:@"opacity"];
}

- (void)stopPulseAnimation {
    [_pulseLayer removeAllAnimations];
    _pulseLayer.opacity = 0.0;
}

- (void)setupDarwinNotifications {
    __weak typeof(self) weakSelf = self;
    notify_register_dispatch("com.fakelag.vpnstatechanged", &_notifyToken, dispatch_get_main_queue(), ^(int token) {
        BOOL isLag = [VPNManager sharedManager].isLagActive;
        [weakSelf updateButtonUIForLagState:isLag];
    });
}

- (void)refreshInitialState {
    BOOL isLag = [VPNManager sharedManager].isLagActive;
    [self updateButtonUIForLagState:isLag];
}

- (void)saveCurrentPosition {
    CGPoint center = self.floatingContainer.center;
    [[NSUserDefaults standardUserDefaults] setDouble:center.x forKey:kSavedPosXKey];
    [[NSUserDefaults standardUserDefaults] setDouble:center.y forKey:kSavedPosYKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)restoreLastSavedPosition {
    double savedX = [[NSUserDefaults standardUserDefaults] doubleForKey:kSavedPosXKey];
    double savedY = [[NSUserDefaults standardUserDefaults] doubleForKey:kSavedPosYKey];
    
    if (savedX >= 35 && savedX <= self.view.bounds.size.width - 35 &&
        savedY >= 60 && savedY <= self.view.bounds.size.height - 60) {
        self.floatingContainer.center = CGPointMake(savedX, savedY);
    } else {
        self.floatingContainer.center = CGPointMake(50, 180);
    }
}

- (void)dealloc {
    if (_notifyToken > 0) {
        notify_cancel(_notifyToken);
    }
}

@end
