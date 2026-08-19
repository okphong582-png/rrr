#import "HUDViewController.h"
#import "RemoteLinkManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>

static NSString * const kSavedHUDPosX = @"HUD_Panel_PosX";
static NSString * const kSavedHUDPosY = @"HUD_Panel_PosY";
static NSString * const kSavedHUDMini = @"HUD_Panel_IsMini";
static NSString * const kSavedHUDOrientation = @"HUD_Panel_IsLandscape";

// ============================================================
// HÀNG CÔNG TẮC GẠT IOS TOGGLE (SWITCH ROW)
// ============================================================
@interface HUDToggleRowView : UIView

@property (nonatomic, assign) RemoteFeatureType featureType;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;
@property (nonatomic, strong) UIView *statusGlow;
@property (nonatomic, copy) void (^switchChangedHandler)(BOOL isOn);

@end

@implementation HUDToggleRowView

- (instancetype)initWithFrame:(CGRect)frame icon:(NSString *)icon name:(NSString *)name subtitle:(NSString *)sub color:(UIColor *)color featureType:(RemoteFeatureType)type {
    self = [super initWithFrame:frame];
    if (self) {
        self.featureType = type;
        self.backgroundColor = [UIColor colorWithRed:0.11 green:0.14 blue:0.20 alpha:0.85];
        self.layer.cornerRadius = 11.0;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
        self.userInteractionEnabled = YES;
        
        // Status Glow Dot
        _statusGlow = [[UIView alloc] initWithFrame:CGRectMake(10, 16, 8, 8)];
        _statusGlow.layer.cornerRadius = 4.0;
        _statusGlow.backgroundColor = [UIColor colorWithWhite:0.4 alpha:1.0];
        [self addSubview:_statusGlow];
        
        // Title Label
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 4, frame.size.width - 85, 18)];
        _titleLabel.text = [NSString stringWithFormat:@"%@ %@", icon, name];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
        _titleLabel.userInteractionEnabled = NO;
        [self addSubview:_titleLabel];
        
        // Subtitle Label
        _subLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 21, frame.size.width - 85, 14)];
        _subLabel.text = sub;
        _subLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        _subLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium];
        _subLabel.userInteractionEnabled = NO;
        [self addSubview:_subLabel];
        
        // iOS Toggle Switch
        _toggleSwitch = [[UISwitch alloc] init];
        _toggleSwitch.center = CGPointMake(frame.size.width - 32, frame.size.height / 2.0);
        _toggleSwitch.onTintColor = color;
        _toggleSwitch.transform = CGAffineTransformMakeScale(0.75, 0.75);
        [_toggleSwitch addTarget:self action:@selector(switchTapped:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_toggleSwitch];
    }
    return self;
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
        _statusGlow.backgroundColor = _toggleSwitch.onTintColor;
        _statusGlow.layer.shadowColor = _toggleSwitch.onTintColor.CGColor;
        _statusGlow.layer.shadowRadius = 4.0;
        _statusGlow.layer.shadowOpacity = 0.9;
        self.layer.borderColor = [_toggleSwitch.onTintColor colorWithAlphaComponent:0.5].CGColor;
        _titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    } else {
        _statusGlow.backgroundColor = [UIColor colorWithWhite:0.4 alpha:1.0];
        _statusGlow.layer.shadowOpacity = 0.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
        _titleLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    }
}

@end

// ============================================================
// BẢNG ĐIỀU KHIỂN NỔI 3 TÍNH NĂNG (VIP FLOATING PANEL)
// ============================================================
@interface HUDFloatingPanelView : UIView

@property (nonatomic, strong) UIView *expandedContainer;
@property (nonatomic, strong) UIView *miniContainer;
@property (nonatomic, strong) UILabel *miniBadgeLabel;
@property (nonatomic, assign) BOOL isMini;
@property (nonatomic, assign) BOOL isLandscape;

@property (nonatomic, copy) void (^closeHandler)(void);
@property (nonatomic, copy) void (^toggleHandler)(RemoteFeatureType type, BOOL isOn);
@property (nonatomic, copy) void (^offAllHandler)(void);

@property (nonatomic, strong) HUDToggleRowView *fakeLagRow;
@property (nonatomic, strong) HUDToggleRowView *teleKillRow;
@property (nonatomic, strong) HUDToggleRowView *ghostRow;
@property (nonatomic, strong) UIButton *rotateBtn;
@property (nonatomic, strong) UIButton *minBtn;
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) UIButton *offAllBtn;

@property (nonatomic, assign) BOOL isTrackingGlobalTouch;
@property (nonatomic, assign) BOOL isGlobalDragging;
@property (nonatomic, assign) CGPoint globalStartPoint;
@property (nonatomic, assign) CGPoint globalStartCenter;

- (void)setMini:(BOOL)mini animated:(BOOL)animated;
- (void)setLandscape:(BOOL)landscape animated:(BOOL)animated;
- (void)refreshStates;

// Xử lý cảm ứng toàn cầu ngoài app (TrollSpeed BackBoard Engine)
- (BOOL)handleGlobalTouchDownAtPoint:(CGPoint)pt;
- (void)handleGlobalTouchMoveAtPoint:(CGPoint)pt;
- (void)handleGlobalTouchUpAtPoint:(CGPoint)pt;

@end

@implementation HUDFloatingPanelView {
    CGPoint _startTouchPoint;
    CGPoint _startCenter;
    BOOL _isDragging;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.userInteractionEnabled = YES;
        
        [self setupExpandedUI];
        [self setupMiniUI];
        
        self.isMini = NO;
        self.miniContainer.hidden = YES;
        self.isLandscape = NO;
    }
    return self;
}

- (void)setupExpandedUI {
    _expandedContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 215, 220)];
    _expandedContainer.backgroundColor = [UIColor colorWithRed:0.07 green:0.09 blue:0.13 alpha:0.95];
    _expandedContainer.layer.cornerRadius = 18.0;
    _expandedContainer.layer.borderWidth = 1.3;
    _expandedContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:0.45].CGColor;
    
    _expandedContainer.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:0.35].CGColor;
    _expandedContainer.layer.shadowOffset = CGSizeMake(0, 6);
    _expandedContainer.layer.shadowRadius = 14.0;
    _expandedContainer.layer.shadowOpacity = 0.85;
    
    // 1. Header Bar
    UIView *headerBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 215, 36)];
    headerBar.backgroundColor = [UIColor colorWithRed:0.11 green:0.14 blue:0.20 alpha:0.95];
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:headerBar.bounds
                                                   byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                                         cornerRadii:CGSizeMake(18.0, 18.0)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = headerBar.bounds;
    maskLayer.path = maskPath.CGPath;
    headerBar.layer.mask = maskLayer;
    
    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 115, 36)];
    headerTitle.text = @"⚡ HOANGHA VIP";
    headerTitle.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightHeavy];
    headerTitle.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    [headerBar addSubview:headerTitle];
    
    // Nút Xoay Hướng Ngang/Dọc (🔄)
    _rotateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _rotateBtn.frame = CGRectMake(128, 4, 26, 28);
    [_rotateBtn setTitle:@"🔄" forState:UIControlStateNormal];
    _rotateBtn.titleLabel.font = [UIFont systemFontOfSize:11];
    [_rotateBtn addTarget:self action:@selector(rotateBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [headerBar addSubview:_rotateBtn];
    
    // Nút Thu Gọn (➖)
    _minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _minBtn.frame = CGRectMake(156, 4, 26, 28);
    [_minBtn setTitle:@"➖" forState:UIControlStateNormal];
    _minBtn.titleLabel.font = [UIFont systemFontOfSize:11];
    [_minBtn addTarget:self action:@selector(minBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [headerBar addSubview:_minBtn];
    
    // Nút Đóng (✕)
    _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeBtn.frame = CGRectMake(184, 4, 26, 28);
    [_closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [_closeBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0] forState:UIControlStateNormal];
    _closeBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [_closeBtn addTarget:self action:@selector(closeBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [headerBar addSubview:_closeBtn];
    
    [_expandedContainer addSubview:headerBar];
    
    CGFloat rowW = 199;
    CGFloat rowH = 39;
    CGFloat startY = 42;
    
    // Row 1: FakeLag (Freeze 🧊)
    _fakeLagRow = [[HUDToggleRowView alloc] initWithFrame:CGRectMake(8, startY, rowW, rowH)
                                                    icon:@"🧊"
                                                    name:@"FakeLag"
                                                subtitle:@"Đóng băng đối phương"
                                                   color:[UIColor colorWithRed:0.0 green:0.75 blue:1.0 alpha:1.0]
                                             featureType:RemoteFeatureFakeLag];
    __weak typeof(self) weakSelf = self;
    _fakeLagRow.switchChangedHandler = ^(BOOL isOn) {
        if (weakSelf.toggleHandler) weakSelf.toggleHandler(RemoteFeatureFakeLag, isOn);
    };
    [_expandedContainer addSubview:_fakeLagRow];
    
    // Row 2: TeleKill (⚡)
    _teleKillRow = [[HUDToggleRowView alloc] initWithFrame:CGRectMake(8, startY + 44, rowW, rowH)
                                                     icon:@"⚡"
                                                     name:@"TeleKill"
                                                 subtitle:@"Dịch chuyển tức thời"
                                                    color:[UIColor colorWithRed:1.0 green:0.42 blue:0.1 alpha:1.0]
                                              featureType:RemoteFeatureTeleKill];
    _teleKillRow.switchChangedHandler = ^(BOOL isOn) {
        if (weakSelf.toggleHandler) weakSelf.toggleHandler(RemoteFeatureTeleKill, isOn);
    };
    [_expandedContainer addSubview:_teleKillRow];
    
    // Row 3: Ghost (👻)
    _ghostRow = [[HUDToggleRowView alloc] initWithFrame:CGRectMake(8, startY + 88, rowW, rowH)
                                                  icon:@"👻"
                                                  name:@"Ghost Lag"
                                              subtitle:@"Tàng hình, lệch hitbox"
                                                 color:[UIColor colorWithRed:0.75 green:0.45 blue:1.0 alpha:1.0]
                                           featureType:RemoteFeatureGhost];
    _ghostRow.switchChangedHandler = ^(BOOL isOn) {
        if (weakSelf.toggleHandler) weakSelf.toggleHandler(RemoteFeatureGhost, isOn);
    };
    [_expandedContainer addSubview:_ghostRow];
    
    // Nút "🔴 TẮT TẤT CẢ (OFF ALL)"
    _offAllBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _offAllBtn.frame = CGRectMake(8, startY + 134, rowW, 32);
    _offAllBtn.backgroundColor = [UIColor colorWithRed:0.95 green:0.15 blue:0.25 alpha:0.25];
    _offAllBtn.layer.cornerRadius = 9.0;
    _offAllBtn.layer.borderWidth = 1.0;
    _offAllBtn.layer.borderColor = [UIColor colorWithRed:0.95 green:0.2 blue:0.3 alpha:0.6].CGColor;
    [_offAllBtn setTitle:@"🔴 TẮT TOÀN BỘ (OFF ALL)" forState:UIControlStateNormal];
    [_offAllBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0] forState:UIControlStateNormal];
    _offAllBtn.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightHeavy];
    [_offAllBtn addTarget:self action:@selector(offAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [_expandedContainer addSubview:_offAllBtn];
    
    [self addSubview:_expandedContainer];
}

- (void)setupMiniUI {
    _miniContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 88, 38)];
    _miniContainer.backgroundColor = [UIColor colorWithRed:0.07 green:0.09 blue:0.13 alpha:0.96];
    _miniContainer.layer.cornerRadius = 19.0;
    _miniContainer.layer.borderWidth = 1.5;
    _miniContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:0.6].CGColor;
    
    _miniContainer.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:0.45].CGColor;
    _miniContainer.layer.shadowOffset = CGSizeMake(0, 4);
    _miniContainer.layer.shadowRadius = 9.0;
    _miniContainer.layer.shadowOpacity = 0.85;
    
    _miniBadgeLabel = [[UILabel alloc] initWithFrame:_miniContainer.bounds];
    _miniBadgeLabel.text = @"⚡ VIP";
    _miniBadgeLabel.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    _miniBadgeLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightHeavy];
    _miniBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [_miniContainer addSubview:_miniBadgeLabel];
    
    [self addSubview:_miniContainer];
}

- (void)rotateBtnTapped {
    [self setLandscape:!self.isLandscape animated:YES];
}

- (void)minBtnTapped {
    [self setMini:YES animated:YES];
}

- (void)closeBtnTapped {
    if (self.closeHandler) {
        self.closeHandler();
    }
}

- (void)offAllTapped {
    [_fakeLagRow setOn:NO animated:YES];
    [_teleKillRow setOn:NO animated:YES];
    [_ghostRow setOn:NO animated:YES];
    if (self.offAllHandler) {
        self.offAllHandler();
    }
}

- (void)setLandscape:(BOOL)landscape animated:(BOOL)animated {
    _isLandscape = landscape;
    [[NSUserDefaults standardUserDefaults] setBool:landscape forKey:kSavedHUDOrientation];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    void (^rotationChanges)(void) = ^{
        if (landscape) {
            self.transform = CGAffineTransformMakeRotation(M_PI_2);
        } else {
            self.transform = CGAffineTransformIdentity;
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:rotationChanges completion:nil];
    } else {
        rotationChanges();
    }
}

- (void)setMini:(BOOL)mini animated:(BOOL)animated {
    _isMini = mini;
    [[NSUserDefaults standardUserDefaults] setBool:mini forKey:kSavedHUDMini];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    void (^changes)(void) = ^{
        if (mini) {
            self.expandedContainer.hidden = YES;
            self.miniContainer.hidden = NO;
            self.bounds = self.miniContainer.bounds;
        } else {
            self.miniContainer.hidden = YES;
            self.expandedContainer.hidden = NO;
            self.bounds = self.expandedContainer.bounds;
        }
        [self refreshStates];
    };
    
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:changes completion:nil];
    } else {
        changes();
    }
}

- (void)refreshStates {
    RemoteLinkManager *mgr = [RemoteLinkManager sharedManager];
    [_fakeLagRow setOn:mgr.fakeLagConfig.isActive animated:NO];
    [_teleKillRow setOn:mgr.teleKillConfig.isActive animated:NO];
    [_ghostRow setOn:mgr.ghostConfig.isActive animated:NO];
    
    int activeCount = (mgr.fakeLagConfig.isActive ? 1 : 0) + (mgr.teleKillConfig.isActive ? 1 : 0) + (mgr.ghostConfig.isActive ? 1 : 0);
    if (activeCount > 0) {
        _miniBadgeLabel.text = [NSString stringWithFormat:@"⚡ %d ON", activeCount];
        _miniBadgeLabel.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.55 alpha:1.0];
        _miniContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.55 alpha:0.9].CGColor;
    } else {
        _miniBadgeLabel.text = @"⚡ VIP";
        _miniBadgeLabel.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
        _miniContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:0.6].CGColor;
    }
}

// === CỬ CHỈ KÉO THẢ DI CHUYỂN TRONG ỨNG DỤNG ===
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
    if (!_isDragging && _isMini) {
        [self setMini:NO animated:YES];
        return;
    }
    
    if (_isDragging) {
        CGRect scr = [UIScreen mainScreen].bounds;
        CGFloat hw = self.bounds.size.width / 2.0;
        CGPoint finalCenter = self.center;
        
        if (finalCenter.x < scr.size.width / 2.0) {
            finalCenter.x = hw + 8.0;
        } else {
            finalCenter.x = scr.size.width - hw - 8.0;
        }
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.center = finalCenter;
        } completion:^(BOOL finished) {
            [[NSUserDefaults standardUserDefaults] setDouble:finalCenter.x forKey:kSavedHUDPosX];
            [[NSUserDefaults standardUserDefaults] setDouble:finalCenter.y forKey:kSavedHUDPosY];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
    }
}

// === XỬ LÝ CẢM ỨNG TOÀN CẦU NGOÀI APP (TROLLSPEED BACKBOARD ENGINE) ===
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
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.center = finalCenter;
        } completion:^(BOOL finished) {
            [[NSUserDefaults standardUserDefaults] setDouble:finalCenter.x forKey:kSavedHUDPosX];
            [[NSUserDefaults standardUserDefaults] setDouble:finalCenter.y forKey:kSavedHUDPosY];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
    } else {
        // === SỰ KIỆN CHẠM (TAP) NGOÀI APP ===
        if (_isMini) {
            // Chạm vào viên thuốc thu gọn -> Bung mở lại bảng
            [self setMini:NO animated:YES];
        } else {
            CGPoint localPt = [self convertPoint:pt fromView:self.window];
            
            // 1. Nút Xoay Hướng Ngang / Dọc (🔄)
            if (CGRectContainsPoint(_rotateBtn.frame, localPt)) {
                [self rotateBtnTapped];
                return;
            }
            
            // 2. Nút Thu Gọn (➖)
            if (CGRectContainsPoint(_minBtn.frame, localPt)) {
                [self minBtnTapped];
                return;
            }
            
            // 3. Nút Đóng (✕)
            if (CGRectContainsPoint(_closeBtn.frame, localPt)) {
                [self closeBtnTapped];
                return;
            }
            
            // 4. Nút Tắt Tất Cả
            if (CGRectContainsPoint(_offAllBtn.frame, localPt)) {
                [self offAllTapped];
                return;
            }
            
            // 5. Toggle FakeLag
            if (CGRectContainsPoint(_fakeLagRow.frame, localPt)) {
                BOOL next = !_fakeLagRow.toggleSwitch.isOn;
                [_fakeLagRow setOn:next animated:YES];
                if (self.toggleHandler) self.toggleHandler(RemoteFeatureFakeLag, next);
                return;
            }
            
            // 6. Toggle TeleKill
            if (CGRectContainsPoint(_teleKillRow.frame, localPt)) {
                BOOL next = !_teleKillRow.toggleSwitch.isOn;
                [_teleKillRow setOn:next animated:YES];
                if (self.toggleHandler) self.toggleHandler(RemoteFeatureTeleKill, next);
                return;
            }
            
            // 7. Toggle Ghost
            if (CGRectContainsPoint(_ghostRow.frame, localPt)) {
                BOOL next = !_ghostRow.toggleSwitch.isOn;
                [_ghostRow setOn:next animated:YES];
                if (self.toggleHandler) self.toggleHandler(RemoteFeatureGhost, next);
                return;
            }
        }
    }
}

@end

// ============================================================
// HUD VIEW CONTROLLER
// ============================================================
@interface HUDViewController () {
    int _notifyToken;
    HUDFloatingPanelView *_hudPanel;
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
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
    self.view.clipsToBounds = NO;
}

- (UIView *)floatingContainer {
    return _hudPanel;
}

- (BOOL)isMiniMode {
    return _hudPanel.isMini;
}

- (BOOL)isLandscapeMode {
    return _hudPanel.isLandscape;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _hudPanel = [[HUDFloatingPanelView alloc] initWithFrame:CGRectMake(20, 150, 215, 220)];
    
    __weak typeof(self) weakSelf = self;
    _hudPanel.toggleHandler = ^(RemoteFeatureType type, BOOL isOn) {
        [[RemoteLinkManager sharedManager] setFeature:type active:isOn completion:nil];
    };
    
    _hudPanel.offAllHandler = ^{
        [[RemoteLinkManager sharedManager] turnOffAllFeaturesWithCompletion:nil];
    };
    
    _hudPanel.closeHandler = ^{
        weakSelf.view.window.hidden = YES;
    };
    
    [self.view addSubview:_hudPanel];
    
    [self restoreLastSavedPosition];
    [self setupDarwinNotifications];
    [self refreshAllToggleStates];
}

- (void)refreshAllToggleStates {
    [_hudPanel refreshStates];
}

- (void)setMiniMode:(BOOL)isMini animated:(BOOL)animated {
    [_hudPanel setMini:isMini animated:animated];
}

- (void)toggleOrientationModeAnimated:(BOOL)animated {
    [_hudPanel setLandscape:!_hudPanel.isLandscape animated:animated];
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

- (void)restoreLastSavedPosition {
    double savedX = [[NSUserDefaults standardUserDefaults] doubleForKey:kSavedHUDPosX];
    double savedY = [[NSUserDefaults standardUserDefaults] doubleForKey:kSavedHUDPosY];
    BOOL isMini = [[NSUserDefaults standardUserDefaults] boolForKey:kSavedHUDMini];
    BOOL isLandscape = [[NSUserDefaults standardUserDefaults] boolForKey:kSavedHUDOrientation];
    
    CGRect scr = [UIScreen mainScreen].bounds;
    if (savedX >= 30 && savedX <= scr.size.width - 30 &&
        savedY >= 50 && savedY <= scr.size.height - 50) {
        _hudPanel.center = CGPointMake(savedX, savedY);
    } else {
        _hudPanel.center = CGPointMake(115, 220);
    }
    
    if (isMini) {
        [_hudPanel setMini:YES animated:NO];
    }
    if (isLandscape) {
        [_hudPanel setLandscape:YES animated:NO];
    }
}

- (void)dealloc {
    if (_notifyToken > 0) {
        notify_cancel(_notifyToken);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
