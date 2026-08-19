#import "HUDViewController.h"
#import "RemoteLinkManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>

// ============================================================
// VIÊN NÚT GẠT ĐỘC LẬP TỰ DO DI CHUYỂN, XOAY & ĐÓNG
// ============================================================
@interface DraggableTogglePillView : UIView

@property (nonatomic, assign) RemoteFeatureType featureType;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) UIButton *rotateBtn;
@property (nonatomic, strong) UIView *statusGlow;
@property (nonatomic, strong) UIColor *themeColor;
@property (nonatomic, assign) BOOL isRotated;

@property (nonatomic, copy) void (^switchChangedHandler)(BOOL isOn);
@property (nonatomic, copy) void (^closeHandler)(void);

@property (nonatomic, assign) BOOL isTrackingGlobalTouch;
@property (nonatomic, assign) BOOL isGlobalDragging;
@property (nonatomic, assign) CGPoint globalStartPoint;
@property (nonatomic, assign) CGPoint globalStartCenter;

- (instancetype)initWithFrame:(CGRect)frame icon:(NSString *)icon name:(NSString *)name color:(UIColor *)color featureType:(RemoteFeatureType)type;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
- (void)updateGlowState:(BOOL)isOn;
- (void)applyScale:(CGFloat)scale;

- (BOOL)handleGlobalTouchDownAtPoint:(CGPoint)pt;
- (void)handleGlobalTouchMoveAtPoint:(CGPoint)pt;
- (void)handleGlobalTouchUpAtPoint:(CGPoint)pt;

- (void)restorePositionWithDefaultCenter:(CGPoint)defaultCenter;
- (void)saveCurrentPosition;

@end

@implementation DraggableTogglePillView {
    CGPoint _startTouchPoint;
    CGPoint _startCenter;
    BOOL _isDragging;
    CGFloat _currentScale;
}

- (instancetype)initWithFrame:(CGRect)frame icon:(NSString *)icon name:(NSString *)name color:(UIColor *)color featureType:(RemoteFeatureType)type {
    self = [super initWithFrame:frame];
    if (self) {
        self.featureType = type;
        self.themeColor = color;
        _currentScale = 1.0;
        _isRotated = NO;
        
        self.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.10 alpha:0.72];
        self.layer.cornerRadius = frame.size.height / 2.0;
        self.layer.borderWidth = 1.3;
        self.layer.borderColor = [color colorWithAlphaComponent:0.55].CGColor;
        
        self.layer.shadowColor = color.CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 3);
        self.layer.shadowRadius = 8.0;
        self.layer.shadowOpacity = 0.65;
        
        self.userInteractionEnabled = YES;
        self.clipsToBounds = NO;
        
        // 1. Nút Đóng Nhỏ [✕]
        _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _closeBtn.frame = CGRectMake(5, (frame.size.height - 20) / 2.0, 20, 20);
        [_closeBtn setTitle:@"✕" forState:UIControlStateNormal];
        [_closeBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:0.9] forState:UIControlStateNormal];
        _closeBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        [_closeBtn addTarget:self action:@selector(closeBtnTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_closeBtn];
        
        // 2. Nút Xoay Nhỏ [🔄]
        _rotateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _rotateBtn.frame = CGRectMake(25, (frame.size.height - 20) / 2.0, 20, 20);
        [_rotateBtn setTitle:@"🔄" forState:UIControlStateNormal];
        _rotateBtn.titleLabel.font = [UIFont systemFontOfSize:10.5];
        [_rotateBtn addTarget:self action:@selector(rotateBtnTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_rotateBtn];
        
        // 3. Tên Tính Năng
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(46, 0, frame.size.width - 100, frame.size.height)];
        _titleLabel.text = [NSString stringWithFormat:@"%@ %@", icon, name];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightHeavy];
        _titleLabel.userInteractionEnabled = NO;
        [self addSubview:_titleLabel];
        
        // 4. iOS Toggle Switch (Kích thước to, nhạy, dễ bấm)
        _toggleSwitch = [[UISwitch alloc] init];
        _toggleSwitch.center = CGPointMake(frame.size.width - 30, frame.size.height / 2.0);
        _toggleSwitch.onTintColor = color;
        _toggleSwitch.transform = CGAffineTransformMakeScale(0.80, 0.80);
        [_toggleSwitch addTarget:self action:@selector(switchTapped:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_toggleSwitch];
    }
    return self;
}

- (void)closeBtnTapped {
    if (self.closeHandler) {
        self.closeHandler();
    }
}

- (void)rotateBtnTapped {
    _isRotated = !_isRotated;
    [[NSUserDefaults standardUserDefaults] setBool:_isRotated forKey:[NSString stringWithFormat:@"HUD_Pill_Rot_%ld", (long)self.featureType]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateTransform];
}

- (void)applyScale:(CGFloat)scale {
    if (scale < 0.6 || scale > 2.0) scale = 1.0;
    _currentScale = scale;
    [self updateTransform];
}

- (void)updateTransform {
    CGAffineTransform t = CGAffineTransformMakeScale(_currentScale, _currentScale);
    if (_isRotated) {
        t = CGAffineTransformConcat(t, CGAffineTransformMakeRotation(M_PI_2));
    }
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.transform = t;
    } completion:nil];
}

- (void)switchTapped:(UISwitch *)sender {
    [self updateGlowState:sender.isOn];
    if (self.switchChangedHandler) {
        self.switchChangedHandler(sender.isOn);
    }
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    [_toggleSwitch setOn:on animated:animated];
    [self updateGlowState:on];
}

- (void)updateGlowState:(BOOL)isOn {
    if (isOn) {
        self.backgroundColor = [_themeColor colorWithAlphaComponent:0.32];
        self.layer.borderColor = [_themeColor colorWithAlphaComponent:0.85].CGColor;
        self.layer.shadowOpacity = 0.9;
        _titleLabel.textColor = [UIColor whiteColor];
    } else {
        self.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.10 alpha:0.72];
        self.layer.borderColor = [_themeColor colorWithAlphaComponent:0.40].CGColor;
        self.layer.shadowOpacity = 0.4;
        _titleLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    }
}

- (NSString *)keyX {
    return [NSString stringWithFormat:@"HUD_Pill_X_%ld", (long)self.featureType];
}

- (NSString *)keyY {
    return [NSString stringWithFormat:@"HUD_Pill_Y_%ld", (long)self.featureType];
}

- (void)saveCurrentPosition {
    [[NSUserDefaults standardUserDefaults] setDouble:self.center.x forKey:[self keyX]];
    [[NSUserDefaults standardUserDefaults] setDouble:self.center.y forKey:[self keyY]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)restorePositionWithDefaultCenter:(CGPoint)defaultCenter {
    double x = [[NSUserDefaults standardUserDefaults] doubleForKey:[self keyX]];
    double y = [[NSUserDefaults standardUserDefaults] doubleForKey:[self keyY]];
    _isRotated = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"HUD_Pill_Rot_%ld", (long)self.featureType]];
    
    CGRect scr = [UIScreen mainScreen].bounds;
    if (x >= 40 && x <= scr.size.width - 40 && y >= 50 && y <= scr.size.height - 50) {
        self.center = CGPointMake(x, y);
    } else {
        self.center = defaultCenter;
    }
    [self updateTransform];
}

// === CỬ CHỈ KÉO THẢ TRONG ỨNG DỤNG ===
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    _startTouchPoint = [t locationInView:self.window];
    _startCenter = self.center;
    _isDragging = NO;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    CGPoint cur = [t locationInView:self.window];
    CGFloat dx = cur.x - _startTouchPoint.x;
    CGFloat dy = cur.y - _startTouchPoint.y;
    
    if (hypot(dx, dy) > 8.0) {
        _isDragging = YES;
    }
    
    if (_isDragging) {
        CGPoint newCenter = CGPointMake(_startCenter.x + dx, _startCenter.y + dy);
        CGRect scr = [UIScreen mainScreen].bounds;
        CGFloat hw = self.bounds.size.width / 2.0;
        CGFloat hh = self.bounds.size.height / 2.0;
        
        newCenter.x = MAX(hw + 4, MIN(scr.size.width - hw - 4, newCenter.x));
        newCenter.y = MAX(hh + 35, MIN(scr.size.height - hh - 25, newCenter.y));
        
        self.center = newCenter;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_isDragging) {
        CGRect scr = [UIScreen mainScreen].bounds;
        CGFloat hw = self.bounds.size.width / 2.0;
        CGPoint finalCenter = self.center;
        
        if (finalCenter.x < scr.size.width / 2.0) {
            finalCenter.x = hw + 8.0;
        } else {
            finalCenter.x = scr.size.width - hw - 8.0;
        }
        
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.center = finalCenter;
        } completion:^(BOOL finished) {
            [self saveCurrentPosition];
        }];
    }
}

// === CỬ CHỈ CẢM ỨNG NGOÀI APP (TROLLSPEED ENGINE) ===
- (BOOL)handleGlobalTouchDownAtPoint:(CGPoint)pt {
    CGPoint localPt = [self convertPoint:pt fromView:self.window];
    if (!CGRectContainsPoint(self.bounds, localPt)) {
        return NO;
    }
    _isTrackingGlobalTouch = YES;
    _isGlobalDragging = NO;
    _globalStartPoint = pt;
    _globalStartCenter = self.center;
    return YES;
}

- (void)handleGlobalTouchMoveAtPoint:(CGPoint)pt {
    if (!_isTrackingGlobalTouch) return;
    
    CGFloat dx = pt.x - _globalStartPoint.x;
    CGFloat dy = pt.y - _globalStartPoint.y;
    
    if (hypot(dx, dy) > 8.0) {
        _isGlobalDragging = YES;
    }
    
    if (_isGlobalDragging) {
        CGPoint newCenter = CGPointMake(_globalStartCenter.x + dx, _globalStartCenter.y + dy);
        CGRect scr = [UIScreen mainScreen].bounds;
        CGFloat hw = self.bounds.size.width / 2.0;
        CGFloat hh = self.bounds.size.height / 2.0;
        
        newCenter.x = MAX(hw + 4, MIN(scr.size.width - hw - 4, newCenter.x));
        newCenter.y = MAX(hh + 35, MIN(scr.size.height - hh - 25, newCenter.y));
        
        self.center = newCenter;
    }
}

- (void)handleGlobalTouchUpAtPoint:(CGPoint)pt {
    if (!_isTrackingGlobalTouch) return;
    _isTrackingGlobalTouch = NO;
    
    if (_isGlobalDragging) {
        CGRect scr = [UIScreen mainScreen].bounds;
        CGFloat hw = self.bounds.size.width / 2.0;
        CGPoint finalCenter = self.center;
        
        if (finalCenter.x < scr.size.width / 2.0) {
            finalCenter.x = hw + 8.0;
        } else {
            finalCenter.x = scr.size.width - hw - 8.0;
        }
        
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.center = finalCenter;
        } completion:^(BOOL finished) {
            [self saveCurrentPosition];
        }];
    } else {
        CGPoint localPt = [self convertPoint:pt fromView:self.window];
        
        // 1. Chạm vào nút Đóng [✕]
        if (CGRectContainsPoint(_closeBtn.frame, localPt)) {
            [self closeBtnTapped];
            return;
        }
        
        // 2. Chạm vào nút Xoay [🔄]
        if (CGRectContainsPoint(_rotateBtn.frame, localPt)) {
            [self rotateBtnTapped];
            return;
        }
        
        // 3. Chạm vào Toggle gạt
        BOOL next = !_toggleSwitch.isOn;
        [self setOn:next animated:YES];
        if (self.switchChangedHandler) {
            self.switchChangedHandler(next);
        }
    }
}

@end

// ============================================================
// HUD VIEW CONTROLLER (QUẢN LÝ 3 VIÊN NÚT NỔI ĐỘC LẬP)
// ============================================================
@interface HUDViewController () {
    int _notifyToken;
    DraggableTogglePillView *_fakeLagPill;
    DraggableTogglePillView *_teleKillPill;
    DraggableTogglePillView *_ghostPill;
    DraggableTogglePillView *_activeTouchedPill;
}

@property (nonatomic, strong, readwrite) NSArray<DraggableTogglePillView *> *allPillViews;

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
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
    self.view.clipsToBounds = NO;
}

- (UIView *)floatingContainer {
    return self.view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGFloat pillW = 156;
    CGFloat pillH = 40;
    
    // 1. Nút FakeLag (Freeze 🧊)
    _fakeLagPill = [[DraggableTogglePillView alloc] initWithFrame:CGRectMake(0, 0, pillW, pillH)
                                                           icon:@"🧊"
                                                           name:@"Freeze"
                                                          color:[UIColor colorWithRed:0.0 green:0.80 blue:1.0 alpha:1.0]
                                                    featureType:RemoteFeatureFakeLag];
    _fakeLagPill.switchChangedHandler = ^(BOOL isOn) {
        [[RemoteLinkManager sharedManager] setFeature:RemoteFeatureFakeLag active:isOn completion:nil];
    };
    _fakeLagPill.closeHandler = ^{
        [RemoteLinkManager sharedManager].showFakeLagInHUD = NO;
        [[RemoteLinkManager sharedManager] saveAllConfigs];
    };
    [self.view addSubview:_fakeLagPill];
    
    // 2. Nút TeleKill (⚡)
    _teleKillPill = [[DraggableTogglePillView alloc] initWithFrame:CGRectMake(0, 0, pillW, pillH)
                                                            icon:@"⚡"
                                                            name:@"TeleKill"
                                                           color:[UIColor colorWithRed:1.0 green:0.45 blue:0.1 alpha:1.0]
                                                     featureType:RemoteFeatureTeleKill];
    _teleKillPill.switchChangedHandler = ^(BOOL isOn) {
        [[RemoteLinkManager sharedManager] setFeature:RemoteFeatureTeleKill active:isOn completion:nil];
    };
    _teleKillPill.closeHandler = ^{
        [RemoteLinkManager sharedManager].showTeleKillInHUD = NO;
        [[RemoteLinkManager sharedManager] saveAllConfigs];
    };
    [self.view addSubview:_teleKillPill];
    
    // 3. Nút Ghost (👻)
    _ghostPill = [[DraggableTogglePillView alloc] initWithFrame:CGRectMake(0, 0, pillW, pillH)
                                                         icon:@"👻"
                                                         name:@"Ghost"
                                                        color:[UIColor colorWithRed:0.75 green:0.45 blue:1.0 alpha:1.0]
                                                  featureType:RemoteFeatureGhost];
    _ghostPill.switchChangedHandler = ^(BOOL isOn) {
        [[RemoteLinkManager sharedManager] setFeature:RemoteFeatureGhost active:isOn completion:nil];
    };
    _ghostPill.closeHandler = ^{
        [RemoteLinkManager sharedManager].showGhostInHUD = NO;
        [[RemoteLinkManager sharedManager] saveAllConfigs];
    };
    [self.view addSubview:_ghostPill];
    
    self.allPillViews = @[_fakeLagPill, _teleKillPill, _ghostPill];
    
    // Phục hồi vị trí đã lưu cho từng nút gạt riêng biệt
    [_fakeLagPill restorePositionWithDefaultCenter:CGPointMake(88, 180)];
    [_teleKillPill restorePositionWithDefaultCenter:CGPointMake(88, 232)];
    [_ghostPill restorePositionWithDefaultCenter:CGPointMake(88, 284)];
    
    [self setupDarwinNotifications];
    [self refreshAllToggleStates];
}

- (void)refreshAllToggleStates {
    RemoteLinkManager *mgr = [RemoteLinkManager sharedManager];
    [mgr loadAllConfigs];
    
    // Cập nhật kích thước scale
    CGFloat scale = mgr.hudScale;
    [_fakeLagPill applyScale:scale];
    [_teleKillPill applyScale:scale];
    [_ghostPill applyScale:scale];
    
    // Cập nhật trạng thái ON/OFF
    [_fakeLagPill setOn:mgr.fakeLagConfig.isActive animated:NO];
    [_teleKillPill setOn:mgr.teleKillConfig.isActive animated:NO];
    [_ghostPill setOn:mgr.ghostConfig.isActive animated:NO];
    
    // Cập nhật ẩn/hiện từng nút riêng biệt
    _fakeLagPill.hidden = !mgr.showFakeLagInHUD;
    _teleKillPill.hidden = !mgr.showTeleKillInHUD;
    _ghostPill.hidden = !mgr.showGhostInHUD;
}

- (BOOL)handleGlobalTouchDownAtPoint:(CGPoint)pt {
    for (DraggableTogglePillView *pill in self.allPillViews) {
        if (!pill.isHidden && [pill handleGlobalTouchDownAtPoint:pt]) {
            _activeTouchedPill = pill;
            return YES;
        }
    }
    _activeTouchedPill = nil;
    return NO;
}

- (void)handleGlobalTouchMoveAtPoint:(CGPoint)pt {
    if (_activeTouchedPill) {
        [_activeTouchedPill handleGlobalTouchMoveAtPoint:pt];
    }
}

- (void)handleGlobalTouchUpAtPoint:(CGPoint)pt {
    if (_activeTouchedPill) {
        [_activeTouchedPill handleGlobalTouchUpAtPoint:pt];
        _activeTouchedPill = nil;
    }
}

- (void)setupDarwinNotifications {
    __weak typeof(self) weakSelf = self;
    notify_register_dispatch("com.fakelag.remotestatechanged", &_notifyToken, dispatch_get_main_queue(), ^(int token) {
        __strong HUDViewController *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf refreshAllToggleStates];
        }
    });
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshAllToggleStates)
                                                 name:RemoteLinkStateChangedNotification
                                               object:nil];
}

- (void)dealloc {
    if (_notifyToken > 0) {
        notify_cancel(_notifyToken);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
