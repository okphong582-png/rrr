#import <UIKit/UIKit.h>

@interface UITouch (KIFAdditions)

- (id)initAtPoint:(CGPoint)point inWindow:(UIWindow *)window;
- (id)initAtPoint:(CGPoint)point inWindow:(UIWindow *)window onView:(UIView *)view;
- (id)initTouch;

- (void)reset;
- (void)setPhaseAndUpdateTimestamp:(UITouchPhase)phase;
- (void)setLocationInWindow:(CGPoint)location;

@end
