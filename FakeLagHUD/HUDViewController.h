#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HUDViewController : UIViewController

@property (nonatomic, strong, readonly) UIView *floatingContainer;
@property (nonatomic, strong, readonly) UIButton *fakelagButton;
@property (nonatomic, assign) BOOL isLagActive;

- (void)updateLagState:(BOOL)isActive animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
