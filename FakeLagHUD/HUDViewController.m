#import "HUDViewController.h"
#import "VPNManager.h"
#import "PacketEngine.h"
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>

static NSString * const kSavedPosXKey = @"FakeLag_Toggle_X";
static NSString * const kSavedPosYKey = @"FakeLag_Toggle_Y";

// ============================================================
// WIDGET CÔNG TẮC GẠT IOS TOGGLE (APPLE SWITCH STYLE)
// ============================================================
@interface DraggableIOSToggleWidget : UIView

@property (nonatomic, copy) void (^toggleHandler)(BOOL isOn);
@property (nonatomic, strong) UIView *capsuleTrack;
@property (nonatomic, strong) UIView *knobView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) BOOL isOn;
@property (nonatomic, assign) BOOL isDragging;

- (void)setOn:(BOOL)on animated:(BOOL)animated;

@end

@implementation DraggableIOSToggleWidget {
    CGPoint _startTouchPoint;
    CGPoint _startCenter;
    NSTimeInterval _touchStartTime;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = NO;
        
        // 1. Thân công tắc hình viên thuốc (Capsule Track: 60x32 pt)
        _capsuleTrack = [[UIView alloc] initWithFrame:CGRectMake(2, 0, 60, 32)];
        _capsuleTrack.layer.cornerRadius = 16.0;
        _capsuleTrack.clipsToBounds = NO;
        _capsuleTrack.backgroundColor = [UIColor colorWithRed:0.18 green:0.20 blue:0.24 alpha:0.95]; // Xám tối Apple khi TẮT
        _capsuleTrack.layer.borderWidth = 1.5;
        _capsuleTrack.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.20].CGColor;
        _capsuleTrack.userInteractionEnabled = NO;
        
        // Đổ bóng phát sáng cho thân công tắc
        _capsuleTrack.layer.shadowOffset = CGSizeMake(0, 3);
        _capsuleTrack.layer.shadowOpacity = 0.5;
        _capsuleTrack.layer.shadowRadius = 6.0;
        _capsuleTrack.layer.shadowColor = [UIColor blackColor].CGColor;
        [self addSubview:_capsuleTrack];
        
        // 2. Chấm tròn trượt (Knob: 26x26 pt)
        _knobView = [[UIView alloc] initWithFrame:CGRectMake(3, 3, 26, 26)];
        _knobView.layer.cornerRadius = 13.0;
        _knobView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
        _knobView.layer.shadowColor = [UIColor blackColor].CGColor;
        _knobView.layer.shadowOffset = CGSizeMake(0, 2);
        _knobView.layer.shadowRadius = 3.0;
        _knobView.layer.shadowOpacity = 0.35;
        _knobView.userInteractionEnabled = NO;
        [_capsuleTrack addSubview:_knobView];
        
        // 3. Nhãn chữ "fakelag" sắc nét, phông chữ đẹp ngay dưới nút
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 35, 64, 16)];
        _titleLabel.text = @"fakelag";
        _titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
        _titleLabel.textColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.layer.shadowColor = [UIColor blackColor].CGColor;
        _titleLabel.layer.shadowOffset = CGSizeMake(0, 1);
        _titleLabel.layer.shadowRadius = 2.0;
        _titleLabel.layer.shadowOpacity = 0.8;
        _titleLabel.userInteractionEnabled = NO;
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    _startTouchPoint = [touch locationInView:self.window];
    _startCenter = self.center;
    self.isDragging = NO;
    _touchStartTime = [NSDate timeIntervalSinceReferenceDate];
    
    // Nhấn xuống thu nhỏ nhẹ tạo cảm giác bấm đàn hồi
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = CGAffineTransformMakeScale(0.93, 0.93);
        self.alpha = 0.92;
    }];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.window];
    
    CGFloat dx = currentPoint.x - _startTouchPoint.x;
    CGFloat dy = currentPoint.y - _startTouchPoint.y;
    
    if (hypot(dx, dy) > 6.0) {
        self.isDragging = YES;
    }
    
    if (self.isDragging) {
        CGPoint newCenter = CGPointMake(_startCenter.x + dx, _startCenter.y + dy);
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat halfW = self.bounds.size.width / 2.0;
        CGFloat halfH = self.bounds.size.height / 2.0;
        
        CGFloat minX = halfW + 6;
        CGFloat maxX = screenBounds.size.width - halfW - 6;
        CGFloat minY = halfH + 40;
        CGFloat maxY = screenBounds.size.height - halfH - 30;
        
        newCenter.x = MAX(minX, MIN(maxX, newCenter.x));
        newCenter.y = MAX(minY, MIN(maxY, newCenter.y));
        
        self.center = newCenter;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [UIView animateWithDuration:0.15 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    }];
    
    if (!self.isDragging) {
        // === CHẠM VÀO TOGGLE: GẠT BẬT / TẮT ===
        BOOL newState = !self.isOn;
        [self setOn:newState animated:YES];
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
        
        if (self.toggleHandler) {
            self.toggleHandler(newState);
        }
    } else {
        // === THẢ TAY SAU KHI KÉO: TỰ ĐỘNG BÁM MẶT VIỀN TRÁI / PHẢI ===
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat halfW = self.bounds.size.width / 2.0;
        CGFloat screenW = screenBounds.size.width;
        
        CGPoint finalCenter = self.center;
        if (finalCenter.x < screenW / 2.0) {
            finalCenter.x = halfW + 10.0;
        } else {
            finalCenter.x = screenW - halfW - 10.0;
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
    [UIView animateWithDuration:0.15 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    }];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _isOn = on;
    
    void (^animations)(void) = ^{
        if (on) {
            // === TRẠNG THÁI BẬT: XANH LÁ NEON / NÚT GẠT SANG PHẢI ===
            self.capsuleTrack.backgroundColor = [UIColor colorWithRed:0.13 green:0.80 blue:0.42 alpha:1.0]; // #22c55e Apple Green
            self.capsuleTrack.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.80].CGColor;
            self.capsuleTrack.layer.shadowColor = [UIColor colorWithRed:0.13 green:0.80 blue:0.42 alpha:0.85].CGColor;
            self.capsuleTrack.layer.shadowRadius = 9.0;
            
            // Trượt sang phải
            self.knobView.frame = CGRectMake(31, 3, 26, 26);
            self.knobView.backgroundColor = [UIColor whiteColor];
            
            // Nhãn chữ bên dưới đổi màu phát sáng
            self.titleLabel.text = @"fakelag";
            self.titleLabel.textColor = [UIColor colorWithRed:0.25 green:0.95 blue:0.55 alpha:1.0];
            self.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightHeavy];
        } else {
            // === TRẠNG THÁI TẮT: XÁM TỐI / NÚT GẠT SANG TRÁI ===
            self.capsuleTrack.backgroundColor = [UIColor colorWithRed:0.18 green:0.20 blue:0.24 alpha:0.95];
            self.capsuleTrack.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.20].CGColor;
            self.capsuleTrack.layer.shadowColor = [UIColor blackColor].CGColor;
            self.capsuleTrack.layer.shadowRadius = 6.0;
            
            // Trượt về bên trái
            self.knobView.frame = CGRectMake(3, 3, 26, 26);
            self.knobView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
            
            // Nhãn chữ mặc định
            self.titleLabel.text = @"fakelag";
            self.titleLabel.textColor = [UIColor colorWithWhite:0.90 alpha:1.0];
            self.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.80
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:animations
                         completion:nil];
    } else {
        animations();
    }
}

@end

// ============================================================
// HUD VIEW CONTROLLER
// ============================================================
@interface HUDViewController () {
    int _notifyToken;
    DraggableIOSToggleWidget *_toggleWidget;
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
    return _toggleWidget;
}

- (BOOL)isLagActive {
    return _toggleWidget.isOn;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Khởi tạo Toggle Widget kích thước chuẩn 64x54 pt
    _toggleWidget = [[DraggableIOSToggleWidget alloc] initWithFrame:CGRectMake(30, 160, 64, 54)];
    
    __weak typeof(self) weakSelf = self;
    _toggleWidget.toggleHandler = ^(BOOL isOn) {
        [weakSelf handleToggleStateChanged:isOn];
    };
    
    [self.view addSubview:_toggleWidget];
    
    [self restoreLastSavedPosition];
    [self setupDarwinNotifications];
    [self refreshInitialState];
}

- (void)handleToggleStateChanged:(BOOL)isOn {
    if (isOn) {
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
}

- (void)updateLagState:(BOOL)isActive animated:(BOOL)animated {
    [_toggleWidget setOn:isActive animated:animated];
}

- (void)setupDarwinNotifications {
    __weak typeof(self) weakSelf = self;
    notify_register_dispatch("com.fakelag.vpnstatechanged", &_notifyToken, dispatch_get_main_queue(), ^(int token) {
        __strong HUDViewController *strongSelf = weakSelf;
        if (strongSelf) {
            BOOL isLag = [VPNManager sharedManager].isLagActive;
            [strongSelf updateLagState:isLag animated:YES];
        }
    });
}

- (void)refreshInitialState {
    BOOL isLag = [VPNManager sharedManager].isLagActive;
    [_toggleWidget setOn:isLag animated:NO];
}

- (void)restoreLastSavedPosition {
    double savedX = [[NSUserDefaults standardUserDefaults] doubleForKey:kSavedPosXKey];
    double savedY = [[NSUserDefaults standardUserDefaults] doubleForKey:kSavedPosYKey];
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if (savedX >= 35 && savedX <= screenBounds.size.width - 35 &&
        savedY >= 60 && savedY <= screenBounds.size.height - 60) {
        _toggleWidget.center = CGPointMake(savedX, savedY);
    } else {
        _toggleWidget.center = CGPointMake(50, 180);
    }
}

- (void)dealloc {
    if (_notifyToken > 0) {
        notify_cancel(_notifyToken);
    }
}

@end
