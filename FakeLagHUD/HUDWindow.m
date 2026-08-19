#import "HUDWindow.h"
#import "HUDViewController.h"
#import <objc/runtime.h>

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
    
    UIView *targetView = self.floatingButtonView;
    if (!targetView && [self.rootViewController isKindOfClass:[HUDViewController class]]) {
        targetView = [(HUDViewController *)self.rootViewController floatingContainer];
        self.floatingButtonView = targetView;
    }
    
    if (targetView && !targetView.isHidden && targetView.userInteractionEnabled) {
        CGPoint p = [targetView convertPoint:point fromView:self];
        if ([targetView pointInside:p withEvent:event]) {
            UIView *hit = [targetView hitTest:p withEvent:event];
            return hit ? hit : targetView;
        }
    }
    
    return nil;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *targetView = self.floatingButtonView;
    if (!targetView && [self.rootViewController isKindOfClass:[HUDViewController class]]) {
        targetView = [(HUDViewController *)self.rootViewController floatingContainer];
        self.floatingButtonView = targetView;
    }
    
    if (targetView && !targetView.isHidden && targetView.userInteractionEnabled) {
        CGPoint p = [targetView convertPoint:point fromView:self];
        return [targetView pointInside:p withEvent:event];
    }
    return NO;
}

@end
