#import "HUDWindow.h"
#import "HUDViewController.h"
#import <objc/runtime.h>
#import <dlfcn.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDService *IOHIDServiceRef;

static void (*_p_BKSHIDEventRegisterEventCallback)(void (*)(void *, void *, IOHIDServiceRef, IOHIDEventRef)) = NULL;
static HUDWindow *g_sharedHUDWindow = nil;

static void _GlobalHUDEventCallback(void *target, void *refcon, IOHIDServiceRef service, IOHIDEventRef event) {
    if (!g_sharedHUDWindow || g_sharedHUDWindow.isHidden || g_sharedHUDWindow.alpha < 0.01) {
        return;
    }
    
    static Class AXEventRepresentationCls = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dlopen("/System/Library/PrivateFrameworks/AccessibilityUtilities.framework/AccessibilityUtilities", RTLD_NOW);
        AXEventRepresentationCls = objc_getClass("AXEventRepresentation");
    });
    
    if (!AXEventRepresentationCls) return;
    
    id rep = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL repSel = NSSelectorFromString(@"representationWithHIDEvent:hidStreamIdentifier:");
    if ([AXEventRepresentationCls respondsToSelector:repSel]) {
        rep = [AXEventRepresentationCls performSelector:repSel
                                             withObject:(__bridge id)event
                                             withObject:@"UIApplicationEvents"];
    }
#pragma clang diagnostic pop
    if (!rep) return;
    
    SEL locSel = NSSelectorFromString(@"location");
    if (![rep respondsToSelector:locSel]) return;
    
    CGPoint loc = CGPointZero;
    NSMethodSignature *sig = [rep methodSignatureForSelector:locSel];
    if (sig) {
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setSelector:locSel];
        [inv setTarget:rep];
        [inv invoke];
        [inv getReturnValue:&loc];
    }
    
    BOOL isDown = NO;
    BOOL isMove = NO;
    BOOL isLift = NO;
    BOOL isCancel = NO;
    
    if ([rep respondsToSelector:NSSelectorFromString(@"isTouchDown")]) {
        isDown = [[rep valueForKey:@"isTouchDown"] boolValue];
    }
    if ([rep respondsToSelector:NSSelectorFromString(@"isMove")]) {
        isMove = [[rep valueForKey:@"isMove"] boolValue];
    }
    if ([rep respondsToSelector:NSSelectorFromString(@"isLift")]) {
        isLift = [[rep valueForKey:@"isLift"] boolValue];
    }
    if ([rep respondsToSelector:NSSelectorFromString(@"isCancel")]) {
        isCancel = [[rep valueForKey:@"isCancel"] boolValue];
    }
    if ([rep respondsToSelector:NSSelectorFromString(@"isInRangeLift")]) {
        if ([[rep valueForKey:@"isInRangeLift"] boolValue]) isLift = YES;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_sharedHUDWindow || g_sharedHUDWindow.isHidden) return;
        
        if ([g_sharedHUDWindow.rootViewController isKindOfClass:[HUDViewController class]]) {
            HUDViewController *hudVC = (HUDViewController *)g_sharedHUDWindow.rootViewController;
            if (isDown) {
                [hudVC handleGlobalTouchDownAtPoint:loc];
            } else if (isMove) {
                [hudVC handleGlobalTouchMoveAtPoint:loc];
            } else if (isLift || isCancel) {
                [hudVC handleGlobalTouchUpAtPoint:loc];
            }
        }
    });
}

@implementation HUDWindow

+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)_isSecure { return YES; }
- (BOOL)_shouldCreateContextAsSecure { return YES; }

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene {
    self = [super initWithWindowScene:windowScene];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    g_sharedHUDWindow = self;
    
    self.backgroundColor = [UIColor clearColor];
    self.windowLevel = 10000010.0;
    self.userInteractionEnabled = YES;
    self.clipsToBounds = NO;
    self.hidden = NO;
    self.alpha = 1.0;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    if (@available(iOS 13.0, *)) {
        if (!self.windowScene) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    self.windowScene = (UIWindowScene *)s;
                    break;
                }
            }
        }
    }
    
    [self registerWithSpringBoardAccessibility];
    [self setupGlobalBackBoardTouchHook];
}

- (void)setupGlobalBackBoardTouchHook {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/BackboardServices.framework/BackboardServices", RTLD_NOW);
        if (handle) {
            _p_BKSHIDEventRegisterEventCallback = dlsym(handle, "BKSHIDEventRegisterEventCallback");
            if (_p_BKSHIDEventRegisterEventCallback) {
                _p_BKSHIDEventRegisterEventCallback(_GlobalHUDEventCallback);
                NSLog(@"[HUDWindow] TrollSpeed BackBoard Touch Hook Đã Kích Hoạt Thành Công!");
            }
        }
    });
}

- (void)registerWithSpringBoardAccessibility {
    Class hostingClass = objc_getClass("SBSAccessibilityWindowHostingController");
    if (!hostingClass) return;
    
    id windowHostingController = [[hostingClass alloc] init];
    if (!windowHostingController) return;
    
    SEL contextIdSel = NSSelectorFromString(@"_contextId");
    if (![self respondsToSelector:contextIdSel]) return;
    
    unsigned int contextId = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSMethodSignature *sigContext = [self methodSignatureForSelector:contextIdSel];
    if (sigContext) {
        NSInvocation *invContext = [NSInvocation invocationWithMethodSignature:sigContext];
        [invContext setSelector:contextIdSel];
        [invContext setTarget:self];
        [invContext invoke];
        [invContext getReturnValue:&contextId];
    }
    
    SEL regSel = NSSelectorFromString(@"registerWindowWithContextID:atLevel:");
    if ([windowHostingController respondsToSelector:regSel]) {
        double wLevel = [self windowLevel];
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:windowHostingController];
        [invocation setSelector:regSel];
        [invocation setArgument:&contextId atIndex:2];
        [invocation setArgument:&wLevel atIndex:3];
        [invocation invoke];
    }
#pragma clang diagnostic pop
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.isUserInteractionEnabled || self.isHidden || self.alpha < 0.01) {
        return nil;
    }
    
    if ([self.rootViewController isKindOfClass:[HUDViewController class]]) {
        HUDViewController *hudVC = (HUDViewController *)self.rootViewController;
        for (UIView *pill in hudVC.allPillViews) {
            if (!pill.isHidden && pill.userInteractionEnabled && pill.alpha > 0.01) {
                CGPoint p = [pill convertPoint:point fromView:self];
                if ([pill pointInside:p withEvent:event]) {
                    UIView *hit = [pill hitTest:p withEvent:event];
                    return hit ? hit : pill;
                }
            }
        }
    }
    
    return nil;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if ([self.rootViewController isKindOfClass:[HUDViewController class]]) {
        HUDViewController *hudVC = (HUDViewController *)self.rootViewController;
        for (UIView *pill in hudVC.allPillViews) {
            if (!pill.isHidden && pill.userInteractionEnabled && pill.alpha > 0.01) {
                CGPoint p = [pill convertPoint:point fromView:self];
                if ([pill pointInside:p withEvent:event]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

@end
