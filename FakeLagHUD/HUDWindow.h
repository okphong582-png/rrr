#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HUDWindow : UIWindow

@property (nonatomic, weak) UIView *floatingButtonView;

- (instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END
