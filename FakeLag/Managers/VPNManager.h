#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const FakeLagVPNStateChangedDarwinNotification;

typedef NS_ENUM(NSInteger, FakeLagVPNState) {
    FakeLagVPNStateNotConfigured,
    FakeLagVPNStateDisconnected,
    FakeLagVPNStateConnecting,
    FakeLagVPNStateConnected,
    FakeLagVPNStateDisconnecting,
    FakeLagVPNStateError
};

@protocol VPNManagerDelegate <NSObject>
@optional
- (void)vpnManagerDidChangeState:(FakeLagVPNState)state statusString:(NSString *)statusString;
- (void)vpnManagerDidFailWithError:(NSError *)error;
@end

@interface VPNManager : NSObject

@property (nonatomic, weak) id<VPNManagerDelegate> delegate;
@property (nonatomic, readonly) FakeLagVPNState currentState;
@property (nonatomic, readonly) BOOL isVPNConnected;
@property (nonatomic, readonly) BOOL isLagActive;
@property (nonatomic, readonly) BOOL isConfigured;

+ (instancetype)sharedManager;

- (void)checkVPNStatus:(void(^ _Nullable)(FakeLagVPNState state, BOOL isConfigured))completion;
- (void)requestVPNPermissionWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion;
- (void)startVPNWithCompletion:(void(^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)stopVPN;
- (void)stopVPNWithCompletion:(void(^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)toggleVPNWithCompletion:(void(^ _Nullable)(BOOL success, NSError * _Nullable error))completion;

// Bật / Tắt gửi túi tin & freeze qua luồng VPN đang chạy
- (void)setLagEnabled:(BOOL)enabled;
- (void)toggleLagMode;

@end

NS_ASSUME_NONNULL_END
