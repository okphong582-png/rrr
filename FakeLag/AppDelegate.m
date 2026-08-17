#import "AppDelegate.h"
#import "MainViewController.h"
#import "VPNManager.h"
#import "HUDLauncher.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (@available(iOS 13.0, *)) {
        // Handled by SceneDelegate
    } else {
        self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        MainViewController *mainVC = [[MainViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mainVC];
        self.window.rootViewController = nav;
        [self.window makeKeyAndVisible];
    }
    
    // Check initial VPN configuration status
    [[VPNManager sharedManager] checkVPNStatus:nil];
    
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    // Handle fakelag:// scheme
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Ensure HUD daemon is independent or running
}

@end
