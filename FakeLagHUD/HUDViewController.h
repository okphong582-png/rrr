#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HUDViewController : UIViewController

@property (nonatomic, strong, readonly) UIView *floatingContainer;
@property (nonatomic, assign, readonly) BOOL isMiniMode;
@property (nonatomic, assign, readonly) BOOL isLandscapeMode;

- (void)refreshAllToggleStates;
- (void)setMiniMode:(BOOL)isMini animated:(BOOL)animated;
- (void)toggleOrientationModeAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
