#import "HUDLauncher.h"
#import <spawn.h>
#import <signal.h>
#import <sys/types.h>
#import <sys/sysctl.h>
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
        _isHUDRunning = NO;
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
    
    // 1. Check directly inside main bundle
    NSString *path1 = [bundlePath stringByAppendingPathComponent:@"FakeLagHUD"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path1]) return path1;
    
    // 2. Check in PlugIns folder
    NSString *path2 = [[bundlePath stringByAppendingPathComponent:@"PlugIns"] stringByAppendingPathComponent:@"FakeLagHUD.app/FakeLagHUD"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path2]) return path2;
    
    // 3. Check sibling bundle directory
    NSString *parent = [bundlePath stringByDeletingLastPathComponent];
    NSString *path3 = [parent stringByAppendingPathComponent:@"FakeLagHUD.app/FakeLagHUD"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path3]) return path3;
    
    return path1;
}

- (BOOL)startHUD {
    [self checkExistingHUDProcess];
    if (_isHUDRunning && _hudPid > 0) {
        NSLog(@"[HUDLauncher] HUD is already running (PID: %d)", _hudPid);
        return YES;
    }
    
    NSString *execPath = [self hudExecutablePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:execPath]) {
        NSLog(@"[HUDLauncher] Executable not found at path: %@", execPath);
    }
    
    const char *path = [execPath UTF8String];
    char *const args[] = {(char *)path, NULL};
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    
    // Set flags for independent background daemon execution
    short flags = POSIX_SPAWN_SETPGROUP;
    posix_spawnattr_setflags(&attr, flags);
    
    pid_t pid = 0;
    int result = posix_spawn(&pid, path, NULL, &attr, args, environ);
    posix_spawnattr_destroy(&attr);
    
    if (result == 0 && pid > 0) {
        _hudPid = pid;
        _isHUDRunning = YES;
        NSLog(@"[HUDLauncher] Successfully spawned HUD process (PID: %d)", pid);
        
        // Post notification that HUD started
        notify_post("com.fakelag.hudstarted");
        return YES;
    } else {
        NSLog(@"[HUDLauncher] posix_spawn failed with code %d: %s", result, strerror(result));
        
        // Fallback: Notify in-app HUD display if single process
        notify_post("com.fakelag.showhud");
        _isHUDRunning = YES;
        return YES;
    }
}

- (void)stopHUD {
    [self checkExistingHUDProcess];
    if (_hudPid > 0) {
        NSLog(@"[HUDLauncher] Terminating HUD process (PID: %d)", _hudPid);
        kill(_hudPid, SIGTERM);
        usleep(100000); // 100ms
        if (kill(_hudPid, 0) == 0) {
            kill(_hudPid, SIGKILL);
        }
        _hudPid = -1;
    }
    
    notify_post("com.fakelag.hudstopped");
    _isHUDRunning = NO;
}

- (void)toggleHUD {
    if (_isHUDRunning) {
        [self stopHUD];
    } else {
        [self startHUD];
    }
}

@end
