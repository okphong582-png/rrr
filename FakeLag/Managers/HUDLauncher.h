#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HUDWindow.h"
#import "HUDViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HUDLauncher : NSObject

@property (nonatomic, readonly) BOOL isHUDRunning;
@property (nonatomic, readonly) pid_t hudPid;
@property (nonatomic, strong, nullable) HUDWindow *inAppHUDWindow;
@property (nonatomic, strong, nullable) HUDViewController *inAppHUDVC;

+ (instancetype)sharedLauncher;

- (BOOL)startHUD;
- (void)stopHUD;
- (void)toggleHUD;
- (void)toggleOrientation;

@end

NS_ASSUME_NONNULL_END
