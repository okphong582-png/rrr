#import "HUDAppDelegate.h"

@implementation HUDAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    self.window = [[HUDWindow alloc] initWithFrame:screenBounds];
    self.hudViewController = [[HUDViewController alloc] init];
    
    self.window.rootViewController = self.hudViewController;
    self.window.floatingButtonView = self.hudViewController.floatingContainer;
    
    [self.window makeKeyAndVisible];
    return YES;
}

@end
