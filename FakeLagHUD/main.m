#import <UIKit/UIKit.h>
#import <unistd.h>
#import <notify.h>
#import "HUDAppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        setuid(0);
        setgid(0);
        
        pid_t pid = getpid();
        NSString *pidStr = [NSString stringWithFormat:@"%d", pid];
        [pidStr writeToFile:@"/tmp/fakelag_hud.pid" atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        static int destroyToken = 0;
        notify_register_dispatch("com.fakelag.destroyhud", &destroyToken, dispatch_get_main_queue(), ^(int token) {
            notify_cancel(token);
            unlink("/tmp/fakelag_hud.pid");
            exit(0);
        });
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([HUDAppDelegate class]));
    }
}
