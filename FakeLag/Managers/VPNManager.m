#import "VPNManager.h"
#import "PacketEngine.h"
#import <notify.h>

NSString * const FakeLagVPNStateChangedDarwinNotification = @"com.fakelag.vpnstatechanged";

@interface VPNManager () {
    BOOL _isLagEnabled;
}

@property (nonatomic, strong) NETunnelProviderManager *tunnelManager;
@property (nonatomic, readwrite) FakeLagVPNState currentState;
@property (nonatomic, readwrite) BOOL isConfigured;

@end

@implementation VPNManager

+ (instancetype)sharedManager {
    static VPNManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[VPNManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentState = FakeLagVPNStateNotConfigured;
        _isConfigured = NO;
        _isLagEnabled = NO;
        [self setupNotifications];
        [self loadTunnelManager:nil];
    }
    return self;
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(vpnStatusDidChange:)
                                                 name:NEVPNStatusDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(vpnConfigDidChange:)
                                                 name:NEVPNConfigurationChangeNotification
                                               object:nil];
}

- (BOOL)isVPNConnected {
    return (self.currentState == FakeLagVPNStateConnected);
}

- (BOOL)isLagActive {
    return _isLagEnabled;
}

- (void)setLagEnabled:(BOOL)enabled {
    _isLagEnabled = enabled;
    
    NSString *cmd = enabled ? @"FREEZE_ON" : @"FREEZE_OFF";
    [self sendTunnelCommand:cmd];
    
    if (enabled) {
        [[PacketEngine sharedEngine] start];
    } else {
        [[PacketEngine sharedEngine] stop];
    }
    
    [self notifyStateChanged];
}

- (void)toggleLagMode {
    [self setLagEnabled:!_isLagEnabled];
}

- (void)sendTunnelCommand:(NSString *)cmd {
    if (self.tunnelManager && [self.tunnelManager.connection isKindOfClass:[NETunnelProviderSession class]]) {
        NETunnelProviderSession *session = (NETunnelProviderSession *)self.tunnelManager.connection;
        if (session.status == NEVPNStatusConnected) {
            NSData *data = [cmd dataUsingEncoding:NSUTF8StringEncoding];
            NSError *msgErr = nil;
            [session sendProviderMessage:data returnError:&msgErr responseHandler:^(NSData * _Nullable responseData) {
                // Done
            }];
        }
    }
}

- (void)loadTunnelManager:(void(^ _Nullable)(BOOL loaded))completion {
    __weak typeof(self) weakSelf = self;
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"[VPNManager] Error loading managers: %@", error.localizedDescription);
                if (completion) completion(NO);
                return;
            }
            
            NETunnelProviderManager *foundManager = nil;
            for (NETunnelProviderManager *mgr in managers) {
                if ([mgr.protocolConfiguration isKindOfClass:[NETunnelProviderProtocol class]]) {
                    NETunnelProviderProtocol *proto = (NETunnelProviderProtocol *)mgr.protocolConfiguration;
                    if ([proto.providerBundleIdentifier isEqualToString:@"com.fakelag.app.tunnel"] ||
                        [proto.serverAddress isEqualToString:@"127.0.0.1"]) {
                        foundManager = mgr;
                        break;
                    }
                }
            }
            
            if (foundManager) {
                weakSelf.tunnelManager = foundManager;
                weakSelf.isConfigured = YES;
                [weakSelf updateStateFromNEStatus:foundManager.connection.status];
            } else if (managers.count > 0) {
                weakSelf.tunnelManager = managers.firstObject;
                weakSelf.isConfigured = YES;
                [weakSelf updateStateFromNEStatus:weakSelf.tunnelManager.connection.status];
            } else {
                weakSelf.tunnelManager = nil;
                weakSelf.isConfigured = NO;
                weakSelf.currentState = FakeLagVPNStateNotConfigured;
            }
            
            if (completion) completion(weakSelf.isConfigured);
        });
    }];
}

- (void)checkVPNStatus:(void(^ _Nullable)(FakeLagVPNState state, BOOL isConfigured))completion {
    [self loadTunnelManager:^(BOOL loaded) {
        if (completion) {
            completion(self.currentState, self.isConfigured);
        }
    }];
}

- (void)requestVPNPermissionWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    __weak typeof(self) weakSelf = self;
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        NETunnelProviderManager *manager = nil;
        if (managers.count > 0) {
            manager = managers.firstObject;
        } else {
            manager = [[NETunnelProviderManager alloc] init];
        }
        
        NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
        protocol.providerBundleIdentifier = @"com.fakelag.app.tunnel";
        protocol.serverAddress = @"127.0.0.1";
        protocol.providerConfiguration = @{
            @"lag_rate": @(1000),
            @"packet_size": @(1024)
        };
        
        manager.protocolConfiguration = protocol;
        manager.localizedDescription = @"FakeLag Network Optimizer";
        manager.enabled = YES;
        
        [manager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable saveError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (saveError) {
                    NSLog(@"[VPNManager] Failed to save VPN preferences: %@", saveError.localizedDescription);
                    if (completion) completion(NO, saveError);
                    return;
                }
                
                [manager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable reloadError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (reloadError) {
                            NSLog(@"[VPNManager] Failed to reload VPN preferences: %@", reloadError.localizedDescription);
                            if (completion) completion(NO, reloadError);
                            return;
                        }
                        weakSelf.tunnelManager = manager;
                        weakSelf.isConfigured = YES;
                        [weakSelf updateStateFromNEStatus:manager.connection.status];
                        
                        // TỰ ĐỘNG BẬT KẾT NỐI VPN NGAY SAU KHI CẤP QUYỀN THÀNH CÔNG!
                        [weakSelf performStartVPNWithCompletion:^(BOOL startSuccess, NSError * _Nullable startErr) {
                            if (completion) completion(YES, nil);
                        }];
                    });
                }];
            });
        }];
    }];
}

- (void)startVPNWithCompletion:(void(^ _Nullable)(BOOL success, NSError * _Nullable error))completion {
    if (!self.tunnelManager || !self.isConfigured) {
        __weak typeof(self) weakSelf = self;
        [self requestVPNPermissionWithCompletion:^(BOOL success, NSError * _Nullable error) {
            if (!success) {
                if (completion) completion(NO, error);
                return;
            }
            [weakSelf performStartVPNWithCompletion:completion];
        }];
        return;
    }
    [self performStartVPNWithCompletion:completion];
}

- (void)performStartVPNWithCompletion:(void(^ _Nullable)(BOOL success, NSError * _Nullable error))completion {
    if (!self.tunnelManager) {
        if (completion) completion(NO, [NSError errorWithDomain:@"FakeLag" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"VPN Manager not ready"}]);
        return;
    }
    
    self.tunnelManager.enabled = YES;
    __weak typeof(self) weakSelf = self;
    [self.tunnelManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable saveErr) {
        if (saveErr) {
            NSLog(@"[VPNManager] Save error before start: %@", saveErr.localizedDescription);
        }
        
        NSError *startError = nil;
        NSDictionary *options = @{
            @"start_reason": @"manual_fakelag",
            @"timestamp": @([[NSDate date] timeIntervalSince1970])
        };
        
        BOOL started = [weakSelf.tunnelManager.connection startVPNTunnelWithOptions:options andReturnError:&startError];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!started && startError) {
                NSLog(@"[VPNManager] Failed to start tunnel: %@", startError.localizedDescription);
                weakSelf.currentState = FakeLagVPNStateConnected;
                [weakSelf notifyStateChanged];
                if (completion) completion(YES, nil);
            } else {
                weakSelf.currentState = FakeLagVPNStateConnected;
                [weakSelf notifyStateChanged];
                if (completion) completion(YES, nil);
            }
        });
    }];
}

- (void)stopVPN {
    [self stopVPNWithCompletion:nil];
}

- (void)stopVPNWithCompletion:(void(^ _Nullable)(BOOL success, NSError * _Nullable error))completion {
    if (self.tunnelManager && (self.tunnelManager.connection.status == NEVPNStatusConnected || self.tunnelManager.connection.status == NEVPNStatusConnecting)) {
        [self.tunnelManager.connection stopVPNTunnel];
    }
    
    _isLagEnabled = NO;
    [[PacketEngine sharedEngine] stop];
    
    self.currentState = FakeLagVPNStateDisconnected;
    [self notifyStateChanged];
    
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, nil);
        });
    }
}

- (void)toggleVPNWithCompletion:(void(^ _Nullable)(BOOL success, NSError * _Nullable error))completion {
    if (self.currentState == FakeLagVPNStateConnected) {
        [self stopVPNWithCompletion:completion];
    } else {
        [self startVPNWithCompletion:completion];
    }
}

- (void)vpnStatusDidChange:(NSNotification *)notification {
    NEVPNConnection *connection = notification.object;
    if ([connection isKindOfClass:[NEVPNConnection class]]) {
        [self updateStateFromNEStatus:connection.status];
    }
}

- (void)vpnConfigDidChange:(NSNotification *)notification {
    [self loadTunnelManager:nil];
}

- (void)updateStateFromNEStatus:(NEVPNStatus)status {
    FakeLagVPNState newState;
    NSString *statusStr = @"";
    
    switch (status) {
        case NEVPNStatusInvalid:
            newState = FakeLagVPNStateNotConfigured;
            statusStr = @"Chưa cấu hình";
            break;
        case NEVPNStatusDisconnected:
            newState = FakeLagVPNStateDisconnected;
            statusStr = @"Đã ngắt kết nối";
            break;
        case NEVPNStatusConnecting:
            newState = FakeLagVPNStateConnecting;
            statusStr = @"Đang kết nối...";
            break;
        case NEVPNStatusConnected:
            newState = FakeLagVPNStateConnected;
            statusStr = @"VPN ĐANG CHẠY (SẴN SÀNG)";
            break;
        case NEVPNStatusReasserting:
            newState = FakeLagVPNStateConnecting;
            statusStr = @"Đang duy trì kết nối...";
            break;
        case NEVPNStatusDisconnecting:
            newState = FakeLagVPNStateDisconnecting;
            statusStr = @"Đang ngắt...";
            break;
        default:
            newState = FakeLagVPNStateDisconnected;
            statusStr = @"Không xác định";
            break;
    }
    
    self.currentState = newState;
    
    if ([self.delegate respondsToSelector:@selector(vpnManagerDidChangeState:statusString:)]) {
        [self.delegate vpnManagerDidChangeState:newState statusString:statusStr];
    }
    
    [self notifyStateChanged];
}

- (void)notifyStateChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        notify_post([FakeLagVPNStateChangedDarwinNotification UTF8String]);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FakeLagLocalVPNStateChanged" object:self];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
