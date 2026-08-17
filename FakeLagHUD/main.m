#import <UIKit/UIKit.h>
#import <unistd.h>
#import "HUDAppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        setuid(0);
        setgid(0);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([HUDAppDelegate class]));
    }
}
