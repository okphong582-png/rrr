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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
    
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
    
    _floatingContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 120, buttonSize, buttonSize)];
    _floatingContainer.backgroundColor = [UIColor clearColor];
    _floatingContainer.clipsToBounds = NO;
    
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
    
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 animations:^{
            sender.transform = CGAffineTransformIdentity;
        }];
    }];
    
    __weak typeof(self) weakSelf = self;
    [[VPNManager sharedManager] toggleVPNWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL isLag = [VPNManager sharedManager].isLagActive;
            [weakSelf updateLagState:isLag animated:YES];
        });
    }];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        AudioServicesPlaySystemSound(1519);
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚡ FakeLag Overlay"
                                                                       message:@"Tùy chọn nhanh"
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại Vị Trí Nút Nổi" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIView animateWithDuration:0.3 animations:^{
                self.floatingContainer.center = CGPointMake(45, 150);
                [self saveCurrentPosition];
            }];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Mở Ứng Dụng Chính" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:@"fakelag://"];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            }
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)updateLagState:(BOOL)isActive animated:(BOOL)animated {
    _isLagActive = isActive;
    
    void (^updateBlock)(void) = ^{
        if (isActive) {
            // ĐANG GỬI TÚI TIN: Nút đỏ rực rỡ phát sáng "LAG ON"
            self.fakelagButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.12 blue:0.25 alpha:1.0];
            [self.fakelagButton setTitle:@"LAG ON" forState:UIControlStateNormal];
            [self.fakelagButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self.fakelagButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.8 alpha:0.9].CGColor;
            
            self.floatingContainer.layer.shadowColor = [UIColor colorWithRed:1.0 green:0.1 blue:0.2 alpha:0.9].CGColor;
            self.floatingContainer.layer.shadowRadius = 14.0;
            
            [self startPulseAnimationWithColor:[UIColor colorWithRed:1.0 green:0.1 blue:0.2 alpha:0.6]];
        } else {
            // TẮT / BÌNH THƯỜNG: Nút xanh neon "fakelag"
            self.fakelagButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
            [self.fakelagButton setTitle:@"fakelag" forState:UIControlStateNormal];
            [self.fakelagButton setTitleColor:[UIColor colorWithRed:0.02 green:0.12 blue:0.06 alpha:1.0] forState:UIControlStateNormal];
            self.fakelagButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.9].CGColor;
            
            self.floatingContainer.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.4 alpha:0.6].CGColor;
            self.floatingContainer.layer.shadowRadius = 8.0;
            
            [self stopPulseAnimation];
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:0.25 animations:updateBlock];
    } else {
        updateBlock();
    }
}

- (void)startPulseAnimationWithColor:(UIColor *)color {
    [_pulseLayer removeAllAnimations];
    _pulseLayer.backgroundColor = color.CGColor;
    _pulseLayer.opacity = 1.0;
    
    CABasicAnimation *scaleAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnim.fromValue = @(0.9);
    scaleAnim.toValue = @(1.38);
    
    CABasicAnimation *opacityAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnim.fromValue = @(0.75);
    opacityAnim.toValue = @(0.0);
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[scaleAnim, opacityAnim];
    group.duration = 1.1;
    group.repeatCount = HUGE_VALF;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    
    [_pulseLayer addAnimation:group forKey:@"pulseAnimation"];
}

- (void)stopPulseAnimation {
    [_pulseLayer removeAllAnimations];
    _pulseLayer.opacity = 0.0;
}

- (void)setupDarwinNotifications {
    int status = notify_register_dispatch([FakeLagVPNStateChangedDarwinNotification UTF8String],
                                          &_notifyToken,
                                          dispatch_get_main_queue(),
                                          ^(int token) {
        BOOL isLag = [VPNManager sharedManager].isLagActive;
        [self updateLagState:isLag animated:YES];
    });
    
    if (status != NOTIFY_STATUS_OK) {
        NSLog(@"[HUDViewController] notify failed: %d", status);
    }
}

- (void)refreshInitialState {
    BOOL isLag = [VPNManager sharedManager].isLagActive;
    [self updateLagState:isLag animated:NO];
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
    
    if (savedX > 10 && savedY > 10) {
        self.floatingContainer.center = CGPointMake(savedX, savedY);
    }
}

- (void)dealloc {
    if (_notifyToken != 0) {
        notify_cancel(_notifyToken);
    }
}

@end
