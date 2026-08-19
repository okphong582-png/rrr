#import "AppDelegate.h"
#import "MainViewController.h"
#import "HUDLauncher.h"
#import <AVFoundation/AVFoundation.h>

@interface AppDelegate ()

@property (nonatomic, strong) AVAudioPlayer *silentPlayer;

@end

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
    
    [self setupBackgroundKeepAlive];
    
    return YES;
}

- (void)setupBackgroundKeepAlive {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    [session setActive:YES error:&error];
    
    // Tạo 1 luồng âm thanh im lặng (silent audio buffer) để duy trì app luôn hoạt động 100% khi chạy nền
    uint8_t silentData[44] = {
        'R', 'I', 'F', 'F', 36, 0, 0, 0, 'W', 'A', 'V', 'E',
        'f', 'm', 't', ' ', 16, 0, 0, 0, 1, 0, 1, 0, 68, -84, 0, 0,
        136, 88, 1, 0, 2, 0, 16, 0, 'd', 'a', 't', 'a', 0, 0, 0, 0
    };
    NSData *wavData = [NSData dataWithBytes:silentData length:sizeof(silentData)];
    _silentPlayer = [[AVAudioPlayer alloc] initWithData:wavData error:nil];
    _silentPlayer.numberOfLoops = -1; // Lặp vô tận
    _silentPlayer.volume = 0.0;
    [_silentPlayer prepareToPlay];
    [_silentPlayer play];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if (!_silentPlayer.isPlaying) {
        [_silentPlayer play];
    }
}

@end
