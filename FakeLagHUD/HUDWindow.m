#import "HUDWindow.h"

@implementation HUDWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.windowLevel = 9999999.0;
        self.userInteractionEnabled = YES;
        self.clipsToBounds = NO;
        self.hidden = NO;
        
        // Private API compatibility for global system overlay
        if ([self respondsToSelector:@selector(_setSecure:)]) {
            [self performSelector:@selector(_setSecure:) withObject:@(YES)];
        }
    }
    return self;
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
