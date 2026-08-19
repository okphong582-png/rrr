#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DraggableTogglePillView;

@interface HUDViewController : UIViewController

@property (nonatomic, strong, readonly) NSArray<DraggableTogglePillView *> *allPillViews;
@property (nonatomic, strong, readonly) UIView *floatingContainer;

- (void)refreshAllToggleStates;
- (BOOL)handleGlobalTouchDownAtPoint:(CGPoint)pt;
- (void)handleGlobalTouchMoveAtPoint:(CGPoint)pt;
- (void)handleGlobalTouchUpAtPoint:(CGPoint)pt;

@end

NS_ASSUME_NONNULL_END
