#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HUDLauncher : NSObject

@property (nonatomic, readonly) BOOL isHUDRunning;
@property (nonatomic, readonly) pid_t hudPid;

+ (instancetype)sharedLauncher;

- (BOOL)startHUD;
- (void)stopHUD;
- (void)toggleHUD;

@end

NS_ASSUME_NONNULL_END
