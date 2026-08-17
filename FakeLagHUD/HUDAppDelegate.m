#import "HUDAppDelegate.h"

@implementation HUDAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    self.window = [[HUDWindow alloc] initWithFrame:screenBounds];
    self.hudViewController = [[HUDViewController alloc] init];
    
    self.window.rootViewController = self.hudViewController;
    self.window.floatingButtonView = self.hudViewController.floatingContainer;
    
    self.window.hidden = NO;
    self.window.windowLevel = UIWindowLevelAlert + 1000000.0;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
