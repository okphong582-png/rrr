#import "HUDWindow.h"

@implementation HUDWindow

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
    self.windowLevel = UIWindowLevelAlert + 1000000.0;
    self.userInteractionEnabled = YES;
    self.clipsToBounds = NO;
    self.hidden = NO;
    self.alpha = 1.0;
    
    if (@available(iOS 13.0, *)) {
        if (!self.windowScene) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                    self.windowScene = (UIWindowScene *)s;
                    break;
                }
            }
            if (!self.windowScene) {
                for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                    if ([s isKindOfClass:[UIWindowScene class]]) {
                        self.windowScene = (UIWindowScene *)s;
                        break;
                    }
                }
            }
        }
    }
    
    if ([self respondsToSelector:@selector(_setSecure:)]) {
        [self performSelector:@selector(_setSecure:) withObject:@(YES)];
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.isUserInteractionEnabled || self.isHidden || self.alpha < 0.01) {
        return nil;
    }
    
    // Check if the touch is within the floating button or its subviews
    if (self.floatingButtonView && !self.floatingButtonView.isHidden && self.floatingButtonView.userInteractionEnabled) {
        CGPoint buttonPoint = [self.floatingButtonView convertPoint:point fromView:self];
        if ([self.floatingButtonView pointInside:buttonPoint withEvent:event]) {
            UIView *hit = [self.floatingButtonView hitTest:buttonPoint withEvent:event];
            if (hit) return hit;
            return self.floatingButtonView;
        }
    }
    
    // Pass through touch to SpringBoard / foreground apps
    return nil;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.floatingButtonView && !self.floatingButtonView.isHidden) {
        CGPoint buttonPoint = [self.floatingButtonView convertPoint:point fromView:self];
        return [self.floatingButtonView pointInside:buttonPoint withEvent:event];
    }
    return NO;
}

@end
