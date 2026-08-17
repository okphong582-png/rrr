#import "HUDLauncher.h"
#import <spawn.h>
#import <signal.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <notify.h>

extern char **environ;

@interface HUDLauncher () {
    pid_t _hudPid;
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
        _hudPid = -1;
        _isHUDRunning = NO;
        [self checkExistingHUDProcess];
    }
    return self;
}

- (pid_t)hudPid {
    return _hudPid;
}

- (void)checkExistingHUDProcess {
    int pid = [self findProcessPidByName:@"FakeLagHUD"];
    if (pid > 0) {
        _hudPid = pid;
        _isHUDRunning = YES;
    } else {
        _hudPid = -1;
        _isHUDRunning = (_inAppHUDWindow && !_inAppHUDWindow.isHidden);
    }
}

- (int)findProcessPidByName:(NSString *)targetName {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) < 0) return -1;
    
    struct kinfo_proc *procs = malloc(size);
    if (!procs) return -1;
    
    if (sysctl(mib, 4, procs, &size, NULL, 0) < 0) {
        free(procs);
        return -1;
    }
    
    int count = (int)(size / sizeof(struct kinfo_proc));
    int foundPid = -1;
    
    for (int i = 0; i < count; i++) {
        NSString *name = [NSString stringWithUTF8String:procs[i].kp_proc.p_comm];
        if ([name isEqualToString:targetName]) {
            foundPid = procs[i].kp_proc.p_pid;
            break;
        }
    }
    
    free(procs);
    return foundPid;
}

- (NSString *)hudExecutablePath {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    
    NSString *path1 = [bundlePath stringByAppendingPathComponent:@"FakeLagHUD"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path1]) return path1;
    
    NSString *path2 = [[bundlePath stringByAppendingPathComponent:@"PlugIns"] stringByAppendingPathComponent:@"FakeLagHUD.app/FakeLagHUD"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path2]) return path2;
    
    NSString *parent = [bundlePath stringByDeletingLastPathComponent];
    NSString *path3 = [parent stringByAppendingPathComponent:@"FakeLagHUD.app/FakeLagHUD"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path3]) return path3;
    
    return path1;
}

- (BOOL)startHUD {
    // 1. Hiển thị ngay lập tức cửa sổ nút nổi trực tiếp trên màn hình UIWindowScene
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showInAppFloatingButton];
    });
    
    // 2. Cấp quyền thực thi và khởi chạy daemon nền
    NSString *execPath = [self hudExecutablePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:execPath]) {
        chmod([execPath UTF8String], 0755);
        
        [self checkExistingHUDProcess];
        if (_hudPid <= 0) {
            const char *path = [execPath UTF8String];
            char *const args[] = {(char *)path, NULL};
            
            posix_spawnattr_t attr;
            posix_spawnattr_init(&attr);
            short flags = POSIX_SPAWN_SETPGROUP;
            posix_spawnattr_setflags(&attr, flags);
            
            pid_t pid = 0;
            int result = posix_spawn(&pid, path, NULL, &attr, args, environ);
            posix_spawnattr_destroy(&attr);
            
            if (result == 0 && pid > 0) {
                _hudPid = pid;
                NSLog(@"[HUDLauncher] Spawned FakeLagHUD daemon (PID: %d)", pid);
            }
        }
    }
    
    _isHUDRunning = YES;
    notify_post("com.fakelag.hudstarted");
    return YES;
}

- (void)showInAppFloatingButton {
    if (!_inAppHUDWindow) {
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
    }
    
    _inAppHUDWindow.hidden = NO;
    _inAppHUDWindow.alpha = 1.0;
    _inAppHUDWindow.windowLevel = UIWindowLevelAlert + 100000.0;
    [_inAppHUDWindow makeKeyAndVisible];
    
    // Đảm bảo nút nằm trong màn hình
    if (_inAppHUDVC && _inAppHUDVC.floatingContainer) {
        _inAppHUDVC.floatingContainer.hidden = NO;
        _inAppHUDVC.floatingContainer.alpha = 1.0;
        _inAppHUDVC.floatingContainer.center = CGPointMake(50, 180);
    }
}

- (void)stopHUD {
    [self checkExistingHUDProcess];
    if (_hudPid > 0) {
        kill(_hudPid, SIGTERM);
        usleep(50000);
        if (kill(_hudPid, 0) == 0) {
            kill(_hudPid, SIGKILL);
        }
        _hudPid = -1;
    }
    
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
    if (_isHUDRunning) {
        [self stopHUD];
    } else {
        [self startHUD];
    }
}

@end
