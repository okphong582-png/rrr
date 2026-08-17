#import "HUDViewController.h"
#import "VPNManager.h"
#import "PacketEngine.h"
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>

static NSString * const kSavedPosXKey = @"FakeLag_Button_X";
static NSString * const kSavedPosYKey = @"FakeLag_Button_Y";

@interface DraggableFloatingButton : UIView

@property (nonatomic, copy) void (^tapHandler)(void);
@property (nonatomic, copy) void (^longPressHandler)(void);
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) CALayer *pulseLayer;
@property (nonatomic, strong) UIView *innerCircle;
@property (nonatomic, assign) BOOL isLagActive;
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) BOOL longPressTriggered;

- (void)setLagActive:(BOOL)active animated:(BOOL)animated;

@end

@implementation DraggableFloatingButton {
    CGPoint _startTouchPoint;
    CGPoint _startCenter;
    NSTimeInterval _touchStartTime;
    NSTimer *_longPressTimer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = NO;
        
        CGFloat size = frame.size.width;
        
        // 1. Lớp sóng Radar Pulse
        _pulseLayer = [CALayer layer];
        _pulseLayer.frame = CGRectMake(-10, -10, size + 20, size + 20);
        _pulseLayer.cornerRadius = (size + 20) / 2.0;
        _pulseLayer.backgroundColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.25 alpha:0.45].CGColor;
        _pulseLayer.opacity = 0.0;
        [self.layer addSublayer:_pulseLayer];
        
        // 2. Nút tròn chính
        _innerCircle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
        _innerCircle.layer.cornerRadius = size / 2.0;
        _innerCircle.clipsToBounds = YES;
        _innerCircle.backgroundColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0]; // Xanh Neon
        _innerCircle.layer.borderWidth = 2.5;
        _innerCircle.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.95].CGColor;
        _innerCircle.userInteractionEnabled = NO;
        
        // Đổ bóng phát sáng
        self.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.45 alpha:0.7].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 4);
        self.layer.shadowRadius = 8.0;
        self.layer.shadowOpacity = 0.8;
        
        // 3. Nhãn chữ hiển thị "fakelag" / "LAG ON"
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, size, size)];
        _titleLabel.text = @"fakelag";
        _titleLabel.textColor = [UIColor colorWithRed:0.02 green:0.12 blue:0.06 alpha:1.0];
        _titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.userInteractionEnabled = NO;
        [_innerCircle addSubview:_titleLabel];
        
        [self addSubview:_innerCircle];
    }
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    _startTouchPoint = [touch locationInView:self.window];
    _startCenter = self.center;
    self.isDragging = NO;
    self.longPressTriggered = NO;
    _touchStartTime = [NSDate timeIntervalSinceReferenceDate];
    
    // Haptic feedback nhẹ khi chạm vào nút
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator impactOccurred];
    
    // Bắt đầu timer cho Long Press (nhấn giữ 0.7s)
    [_longPressTimer invalidate];
    __weak typeof(self) weakSelf = self;
    _longPressTimer = [NSTimer scheduledTimerWithTimeInterval:0.7 repeats:NO block:^(NSTimer * _Nonnull timer) {
        __strong DraggableFloatingButton *strongSelf = weakSelf;
        if (strongSelf && !strongSelf.isDragging) {
            strongSelf.longPressTriggered = YES;
            AudioServicesPlaySystemSound(1520);
            if (strongSelf.longPressHandler) {
                strongSelf.longPressHandler();
            }
        }
    }];
    
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = CGAffineTransformMakeScale(0.92, 0.92);
        self.alpha = 0.92;
    }];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.window];
    
    CGFloat dx = currentPoint.x - _startTouchPoint.x;
    CGFloat dy = currentPoint.y - _startTouchPoint.y;
    
    if (hypot(dx, dy) > 8.0) {
        self.isDragging = YES;
        [_longPressTimer invalidate];
        _longPressTimer = nil;
    }
    
    if (self.isDragging) {
        CGPoint newCenter = CGPointMake(_startCenter.x + dx, _startCenter.y + dy);
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat radius = self.bounds.size.width / 2.0;
        CGFloat minX = radius + 6;
        CGFloat maxX = screenBounds.size.width - radius - 6;
        CGFloat minY = radius + 40;
        CGFloat maxY = screenBounds.size.height - radius - 30;
        
        newCenter.x = MAX(minX, MIN(maxX, newCenter.x));
        newCenter.y = MAX(minY, MIN(maxY, newCenter.y));
        
        self.center = newCenter;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_longPressTimer invalidate];
    _longPressTimer = nil;
    
    [UIView animateWithDuration:0.15 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    }];
    
    if (self.longPressTriggered) return;
    
    if (!self.isDragging) {
        // === SỰ KIỆN CHẠM (TAP): BẬT/TẮT FAKELAG NGAY LẬP TỨC ===
        if (self.tapHandler) {
            self.tapHandler();
        }
    } else {
        // === SỰ KIỆN KÉO (DRAG): TỰ ĐỘNG BÁM DÍNH VIỀN MÀN HÌNH ===
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat radius = self.bounds.size.width / 2.0;
        CGFloat screenWidth = screenBounds.size.width;
        
        CGPoint finalCenter = self.center;
        if (finalCenter.x < screenWidth / 2.0) {
            finalCenter.x = radius + 10.0;
        } else {
            finalCenter.x = screenWidth - radius - 10.0;
        }
        
        [UIView animateWithDuration:0.35
                              delay:0
             usingSpringWithDamping:0.75
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.center = finalCenter;
        } completion:^(BOOL finished) {
            [[NSUserDefaults standardUserDefaults] setDouble:finalCenter.x forKey:kSavedPosXKey];
            [[NSUserDefaults standardUserDefaults] setDouble:finalCenter.y forKey:kSavedPosYKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_longPressTimer invalidate];
    _longPressTimer = nil;
    
    [UIView animateWithDuration:0.15 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    }];
}

- (void)setLagActive:(BOOL)active animated:(BOOL)animated {
    _isLagActive = active;
    
    void (^updateBlock)(void) = ^{
        if (active) {
            self.innerCircle.backgroundColor = [UIColor colorWithRed:0.95 green:0.15 blue:0.25 alpha:1.0]; // Đỏ rực
            self.innerCircle.layer.borderColor = [UIColor colorWithRed:1.0 green:0.80 blue:0.80 alpha:1.0].CGColor;
            self.titleLabel.text = @"LAG ON";
            self.titleLabel.textColor = [UIColor whiteColor];
            self.layer.shadowColor = [UIColor colorWithRed:1.0 green:0.10 blue:0.20 alpha:0.9].CGColor;
            
            [self startPulseAnimation];
        } else {
            self.innerCircle.backgroundColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0]; // Xanh Neon
            self.innerCircle.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.95].CGColor;
            self.titleLabel.text = @"fakelag";
            self.titleLabel.textColor = [UIColor colorWithRed:0.02 green:0.12 blue:0.06 alpha:1.0];
            self.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.45 alpha:0.7].CGColor;
            
            [self stopPulseAnimation];
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:0.2 animations:updateBlock];
    } else {
        updateBlock();
    }
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
    opacityAnim.fromValue = @(0.75);
    opacityAnim.toValue = @(0.10);
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

@end

@interface HUDViewController () {
    int _notifyToken;
    DraggableFloatingButton *_draggableButton;
}

@end

@implementation HUDViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        (void)self.view;
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

- (UIView *)floatingContainer {
    return _draggableButton;
}

- (UIButton *)fakelagButton {
    return nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGFloat buttonSize = 68.0;
    _draggableButton = [[DraggableFloatingButton alloc] initWithFrame:CGRectMake(30, 160, buttonSize, buttonSize)];
    
    __weak typeof(self) weakSelf = self;
    _draggableButton.tapHandler = ^{
        [weakSelf handleButtonTap];
    };
    
    _draggableButton.longPressHandler = ^{
        [weakSelf showHUDMenu];
    };
    
    [self.view addSubview:_draggableButton];
    
    [self restoreLastSavedPosition];
    [self setupDarwinNotifications];
    [self refreshInitialState];
}

- (void)handleButtonTap {
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [generator impactOccurred];
    
    BOOL isLagNow = ![VPNManager sharedManager].isLagActive;
    
    if (isLagNow) {
        [[VPNManager sharedManager] startVPNWithCompletion:^(BOOL success, NSError * _Nullable error) {
            if (error) {
                NSLog(@"[HUD] Lỗi bật VPN: %@", error.localizedDescription);
            }
        }];
    } else {
        [[VPNManager sharedManager] stopVPNWithCompletion:^(BOOL success, NSError * _Nullable error) {
            if (error) {
                NSLog(@"[HUD] Lỗi tắt VPN: %@", error.localizedDescription);
            }
        }];
    }
    
    [_draggableButton setLagActive:isLagNow animated:YES];
}

- (void)showHUDMenu {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚡ FAKELAG OVERLAY"
                                                                   message:@"Tùy chọn nhanh:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"🔄 Reset Vị Trí Về Mặc Định"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [UIView animateWithDuration:0.3 animations:^{
            weakSelf.floatingContainer.center = CGPointMake(50, 180);
            [[NSUserDefaults standardUserDefaults] setDouble:50 forKey:kSavedPosXKey];
            [[NSUserDefaults standardUserDefaults] setDouble:180 forKey:kSavedPosYKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"❌ Ẩn Nút Nổi"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        weakSelf.view.window.hidden = YES;
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateLagState:(BOOL)isActive animated:(BOOL)animated {
    [_draggableButton setLagActive:isActive animated:animated];
}

- (void)setupDarwinNotifications {
    __weak typeof(self) weakSelf = self;
    notify_register_dispatch("com.fakelag.vpnstatechanged", &_notifyToken, dispatch_get_main_queue(), ^(int token) {
        BOOL isLag = [VPNManager sharedManager].isLagActive;
        [weakSelf.floatingContainer setNeedsDisplay];
        [weakSelf updateLagState:isLag animated:YES];
    });
}

- (void)refreshInitialState {
    BOOL isLag = [VPNManager sharedManager].isLagActive;
    [_draggableButton setLagActive:isLag animated:NO];
}

- (void)restoreLastSavedPosition {
    double savedX = [[NSUserDefaults standardUserDefaults] doubleForKey:kSavedPosXKey];
    double savedY = [[NSUserDefaults standardUserDefaults] doubleForKey:kSavedPosYKey];
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if (savedX >= 35 && savedX <= screenBounds.size.width - 35 &&
        savedY >= 60 && savedY <= screenBounds.size.height - 60) {
        _draggableButton.center = CGPointMake(savedX, savedY);
    } else {
        _draggableButton.center = CGPointMake(50, 180);
    }
}

- (void)dealloc {
    if (_notifyToken > 0) {
        notify_cancel(_notifyToken);
    }
}

@end
