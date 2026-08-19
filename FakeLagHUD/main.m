#import <UIKit/UIKit.h>
#import <unistd.h>
#import <notify.h>
#import <signal.h>
#import "HUDAppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        setuid(0);
        setgid(0);
        
        pid_t myPid = getpid();
        
        // 1. Kiểm tra và diệt sạch mọi tiến trình FakeLagHUD cũ trước khi khởi chạy
        NSString *oldPidStr = [NSString stringWithContentsOfFile:@"/tmp/fakelag_hud.pid" encoding:NSUTF8StringEncoding error:nil];
        if (oldPidStr) {
            pid_t oldPid = (pid_t)[oldPidStr intValue];
            if (oldPid > 0 && oldPid != myPid && kill(oldPid, 0) == 0) {
                NSLog(@"[FakeLagHUD] Đang tắt daemon cũ PID: %d", oldPid);
                kill(oldPid, SIGKILL);
                usleep(100000); // 100ms
            }
        }
        
        // 2. Ghi PID mới
        NSString *pidStr = [NSString stringWithFormat:@"%d", myPid];
        [pidStr writeToFile:@"/tmp/fakelag_hud.pid" atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        // 3. Đăng ký nhận thông báo dừng từ app chính
        static int destroyToken = 0;
        notify_register_dispatch("com.fakelag.destroyhud", &destroyToken, dispatch_get_main_queue(), ^(int token) {
            notify_cancel(token);
            unlink("/tmp/fakelag_hud.pid");
            exit(0);
        });
        
        static int stopToken = 0;
        notify_register_dispatch("com.fakelag.stophud", &stopToken, dispatch_get_main_queue(), ^(int token) {
            notify_cancel(token);
            unlink("/tmp/fakelag_hud.pid");
            exit(0);
        });
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([HUDAppDelegate class]));
    }
}
