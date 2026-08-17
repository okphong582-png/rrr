#import "PacketTunnelProvider.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/ip.h>
#import <netinet/udp.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>

@interface PacketTunnelProvider ()

@property (nonatomic, assign) BOOL isTunnelRunning;
@property (nonatomic, assign) BOOL isSendingPackets;
@property (nonatomic, strong) dispatch_queue_t floodQueue;
@property (nonatomic, strong) dispatch_source_t floodTimer;

@end

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    self.isTunnelRunning = YES;
    self.isSendingPackets = YES; // Khi bật VPN -> Kích hoạt gửi túi tin ngẫu nhiên
    self.floodQueue = dispatch_queue_create("com.fakelag.packetengine", DISPATCH_QUEUE_SERIAL);
    
    // Cấu hình TUN interface trên iOS
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"127.0.0.1"];
    
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"10.99.0.2"]
                                                                 subnetMasks:@[@"255.255.255.0"]];
    NEIPv4Route *defaultRoute = [[NEIPv4Route alloc] initWithDestinationAddress:@"0.0.0.0"
                                                                     subnetMask:@"0.0.0.0"];
    ipv4Settings.includedRoutes = @[defaultRoute];
    settings.IPv4Settings = ipv4Settings;
    
    NEDNSSettings *dnsSettings = [[NEDNSSettings alloc] initWithServers:@[@"1.1.1.1", @"8.8.8.8"]];
    settings.DNSSettings = dnsSettings;
    settings.MTU = @(1400);
    
    __weak typeof(self) weakSelf = self;
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            NSLog(@"[FakeLagTunnel] Lỗi cấu hình VPN: %@", error.localizedDescription);
            if (completionHandler) completionHandler(error);
            return;
        }
        
        if (strongSelf) {
            [strongSelf startNormalPacketForwarding];
            [strongSelf startContinuousPacketFlood];
        }
        
        if (completionHandler) completionHandler(nil);
    }];
}

// Chuyển tiếp các gói tin bình thường của hệ thống
- (void)startNormalPacketForwarding {
    if (!self.isTunnelRunning) return;
    
    __weak typeof(self) weakSelf = self;
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isTunnelRunning) return;
        
        if (packets.count > 0) {
            [strongSelf.packetFlow writePackets:packets withProtocols:protocols];
        }
        
        [strongSelf startNormalPacketForwarding];
    }];
}

// === KHI BẬT: BẮN TÚI TIN RANDOM LIÊN TỤC LÊN CỔNG GAME (10010 - 10020) LÀM ĐỊCH ĐƠ ===
- (void)startContinuousPacketFlood {
    if (self.floodTimer) {
        dispatch_source_cancel(self.floodTimer);
        self.floodTimer = nil;
    }
    
    self.isSendingPackets = YES;
    self.floodTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.floodQueue);
    
    // Tần số cực cao: 3ms mỗi đợt burst túi tin
    dispatch_source_set_timer(self.floodTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 3000000ULL, 500000ULL);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.floodTimer, ^{
        typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.isSendingPackets && strongSelf.isTunnelRunning) {
            [strongSelf sendRandomGamePacketsBurst];
        }
    });
    dispatch_resume(self.floodTimer);
}

// Gửi 1 đợt túi tin ngẫu nhiên vào luồng VPN cổng game 10010 - 10020
- (void)sendRandomGamePacketsBurst {
    NSMutableArray<NSData *> *burstPackets = [NSMutableArray arrayWithCapacity:8];
    NSMutableArray<NSNumber *> *protos = [NSMutableArray arrayWithCapacity:8];
    
    uint8_t buffer[1024];
    for (int i = 0; i < 8; i++) {
        arc4random_buf(buffer, sizeof(buffer));
        
        // Cấu hình IPv4 Header
        buffer[0] = 0x45;
        buffer[1] = 0x00;
        buffer[2] = 0x04;
        buffer[3] = 0x00; // 1024 bytes
        buffer[8] = 64;   // TTL
        buffer[9] = 17;   // Protocol UDP
        
        // Random cổng game đích: 10010 đến 10020
        uint16_t gamePort = (uint16_t)(10010 + arc4random_uniform(11));
        buffer[22] = (gamePort >> 8) & 0xFF;
        buffer[23] = gamePort & 0xFF;
        
        // Độ dài UDP Header
        uint16_t udpLen = 1004;
        buffer[24] = (udpLen >> 8) & 0xFF;
        buffer[25] = udpLen & 0xFF;
        
        [burstPackets addObject:[NSData dataWithBytes:buffer length:sizeof(buffer)]];
        [protos addObject:@(AF_INET)];
    }
    
    [self.packetFlow writePackets:burstPackets withProtocols:protos];
}

// === KHI TẮT: NGƯNG GỬI TÚI TIN NGAY LẬP TỨC 100% ===
- (void)stopSendingPacketsImmediately {
    self.isSendingPackets = NO;
    if (self.floodTimer) {
        dispatch_source_cancel(self.floodTimer);
        self.floodTimer = nil;
    }
    NSLog(@"[FakeLagTunnel] ĐÃ DỪNG GỬI TÚI TIN HOÀN TOÀN!");
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    self.isTunnelRunning = NO;
    [self stopSendingPacketsImmediately];
    
    if (completionHandler) {
        completionHandler();
    }
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    NSString *cmd = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    if ([cmd isEqualToString:@"FREEZE_ON"] || [cmd isEqualToString:@"START_FLOOD"]) {
        [self startContinuousPacketFlood];
    } else if ([cmd isEqualToString:@"FREEZE_OFF"] || [cmd isEqualToString:@"STOP_FLOOD"]) {
        [self stopSendingPacketsImmediately];
    }
    
    if (completionHandler) completionHandler([@"OK" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    if (completionHandler) completionHandler();
}

- (void)wake {
}

@end
