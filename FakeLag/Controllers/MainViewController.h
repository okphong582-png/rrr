#import <UIKit/UIKit.h>
#import "VPNManager.h"
#import "PacketEngine.h"
#import "HUDLauncher.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController : UIViewController <VPNManagerDelegate, PacketEngineDelegate>

@end

NS_ASSUME_NONNULL_END
