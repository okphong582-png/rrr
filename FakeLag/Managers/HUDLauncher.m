#import "HUDLauncher.h"
#import "HUDWindow.h"
#import "HUDViewController.h"
#import <notify.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>

extern char **environ;

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

static NSString * const kPIDFilePath = @"/tmp/fakelag_hud.pid";

@interface HUDLauncher () {
    HUDWindow *_inAppHUDWindow;
    HUDViewController *_inAppHUDVC;
    pid_t _daemonPid;
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
        _isHUDRunning = [self checkDaemonRunning];
    }
    return self;
}

- (pid_t)hudPid {
    return _daemonPid > 0 ? _daemonPid : (_isHUDRunning ? getpid() : -1);
}

- (BOOL)checkDaemonRunning {
    NSString *pidString = [NSString stringWithContentsOfFile:kPIDFilePath encoding:NSUTF8StringEncoding error:nil];
    if (pidString) {
        pid_t pid = (pid_t)[pidString intValue];
        if (pid > 0 && kill(pid, 0) == 0) {
            _daemonPid = pid;
            return YES;
        }
    }
    return NO;
}

- (BOOL)startHUD {
    // 1. Tắt instance cũ nếu có
    [self stopHUD];
    
    // 2. Thử chạy Daemon độc lập với Persona 99 (cho phép cảm ứng ngoài app/trong game 100%)
    BOOL spawned = [self spawnDaemonProcess];
    if (spawned) {
        _isHUDRunning = YES;
        notify_post("com.fakelag.hudstarted");
        return YES;
    }
    
    // 3. Fallback hiển thị cửa sổ trong app
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showInAppWindow];
    });
    
    _isHUDRunning = YES;
    notify_post("com.fakelag.hudstarted");
    return YES;
}

- (BOOL)spawnDaemonProcess {
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    
    if (&posix_spawnattr_set_persona_np) {
        posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
        posix_spawnattr_set_persona_uid_np(&attr, 0);
        posix_spawnattr_set_persona_gid_np(&attr, 0);
    }
    
    posix_spawnattr_setpgroup(&attr, 0);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);
    
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *hudPath = [bundlePath stringByAppendingPathComponent:@"FakeLagHUD"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:hudPath]) {
        uint32_t size = 0;
        _NSGetExecutablePath(NULL, &size);
        char *execPath = (char *)malloc(size);
        if (execPath && _NSGetExecutablePath(execPath, &size) == 0) {
            hudPath = [NSString stringWithUTF8String:execPath];
        }
        if (execPath) free(execPath);
    }
    
    pid_t pid = 0;
    const char *args[] = { [hudPath UTF8String], "-hud", NULL };
    int status = posix_spawn(&pid, [hudPath UTF8String], NULL, &attr, (char **)args, environ);
    posix_spawnattr_destroy(&attr);
    
    if (status == 0 && pid > 0) {
        _daemonPid = pid;
        NSString *pidStr = [NSString stringWithFormat:@"%d", pid];
        [pidStr writeToFile:kPIDFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSLog(@"[HUDLauncher] Khởi tạo FakeLagHUD Daemon thành công với PID: %d", pid);
        return YES;
    }
    
    NSLog(@"[HUDLauncher] Không thể spawn daemon (mã lỗi: %d), chuyển sang chế độ in-app", status);
    return NO;
}

- (void)showInAppWindow {
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
    // 1. Dừng daemon nếu đang chạy
    NSString *pidString = [NSString stringWithContentsOfFile:kPIDFilePath encoding:NSUTF8StringEncoding error:nil];
    if (pidString) {
        pid_t pid = (pid_t)[pidString intValue];
        if (pid > 0) {
            kill(pid, SIGKILL);
        }
        unlink([kPIDFilePath UTF8String]);
    }
    if (_daemonPid > 0) {
        kill(_daemonPid, SIGKILL);
        _daemonPid = 0;
    }
    
    // 2. Dừng in-app window
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
    if (_isHUDRunning || [self checkDaemonRunning]) {
        [self stopHUD];
    } else {
        [self startHUD];
    }
}

- (void)toggleOrientation {
    if (_inAppHUDVC) {
        [_inAppHUDVC toggleOrientationModeAnimated:YES];
    }
}

@end
