#import <UIKit/UIKit.h>
#import "HUDWindow.h"
#import "HUDViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HUDAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) HUDWindow *window;
@property (nonatomic, strong) HUDViewController *hudViewController;

@end

NS_ASSUME_NONNULL_END
