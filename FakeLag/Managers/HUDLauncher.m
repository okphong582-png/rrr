#import "HUDLauncher.h"
#import "HUDWindow.h"
#import "HUDViewController.h"
#import <notify.h>

@interface HUDLauncher () {
    HUDWindow *_inAppHUDWindow;
    HUDViewController *_inAppHUDVC;
}

@property (nonatomic, readwrite) BOOL isHUDRunning;

@end

@implementation HUDLauncher

+ (instancetype)sharedLauncher {
    static HUDLauncher *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[HUDLauncher alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isHUDRunning = NO;
    }
    return self;
}

- (pid_t)hudPid {
    return _isHUDRunning ? getpid() : -1;
}

- (BOOL)startHUD {
    if (_inAppHUDWindow && !_inAppHUDWindow.isHidden) {
        _isHUDRunning = YES;
        return YES;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showSingleFloatingToggle];
    });
    
    _isHUDRunning = YES;
    notify_post("com.fakelag.hudstarted");
    return YES;
}

- (void)showSingleFloatingToggle {
    if (_inAppHUDWindow) {
        _inAppHUDWindow.hidden = NO;
        _inAppHUDWindow.alpha = 1.0;
        [_inAppHUDWindow makeKeyAndVisible];
        return;
    }
    
    UIWindowScene *activeScene = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                activeScene = (UIWindowScene *)s;
                break;
            }
        }
        if (!activeScene) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    activeScene = (UIWindowScene *)s;
                    break;
                }
            }
        }
    }
    
    if (activeScene) {
        _inAppHUDWindow = [[HUDWindow alloc] initWithWindowScene:activeScene];
    } else {
        _inAppHUDWindow = [[HUDWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    _inAppHUDVC = [[HUDViewController alloc] init];
    _inAppHUDWindow.rootViewController = _inAppHUDVC;
    _inAppHUDWindow.floatingButtonView = _inAppHUDVC.floatingContainer;
    
    _inAppHUDWindow.hidden = NO;
    _inAppHUDWindow.alpha = 1.0;
    _inAppHUDWindow.windowLevel = 10000010.0;
    [_inAppHUDWindow makeKeyAndVisible];
}

- (void)stopHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_inAppHUDWindow) {
            self->_inAppHUDWindow.hidden = YES;
            self->_inAppHUDWindow = nil;
            self->_inAppHUDVC = nil;
        }
    });
    
    _isHUDRunning = NO;
    notify_post("com.fakelag.hudstopped");
}

- (void)toggleHUD {
    if (_isHUDRunning && _inAppHUDWindow && !_inAppHUDWindow.isHidden) {
        [self stopHUD];
    } else {
        [self startHUD];
    }
}

@end
