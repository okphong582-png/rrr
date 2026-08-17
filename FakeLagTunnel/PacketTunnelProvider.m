#import "PacketTunnelProvider.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/ip.h>
#import <netinet/udp.h>
#import <arpa/inet.h>

@interface PacketTunnelProvider ()

@property (nonatomic, assign) BOOL isTunnelRunning;
@property (nonatomic, assign) BOOL sendPacketsActive;
@property (nonatomic, strong) dispatch_queue_t tunnelQueue;
@property (nonatomic, strong) dispatch_source_t packetFloodTimer;

@end

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    self.isTunnelRunning = YES;
    self.sendPacketsActive = YES;
    self.tunnelQueue = dispatch_queue_create("com.fakelag.tunnelflood", DISPATCH_QUEUE_SERIAL);
    
    // Cấu hình VPN ảo trên iOS
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"127.0.0.1"];
    
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"10.99.0.2"]
                                                                 subnetMasks:@[@"255.255.255.0"]];
    NEIPv4Route *route = [[NEIPv4Route alloc] initWithDestinationAddress:@"0.0.0.0"
                                                              subnetMask:@"0.0.0.0"];
    ipv4Settings.includedRoutes = @[route];
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
            [strongSelf startPacketFlowReading];
            [strongSelf startRandomPacketSending];
        }
        
        if (completionHandler) completionHandler(nil);
    }];
}

- (void)startPacketFlowReading {
    if (!self.isTunnelRunning) return;
    
    __weak typeof(self) weakSelf = self;
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isTunnelRunning) return;
        
        // Chuyển tiếp các gói tin hợp lệ
        if (packets.count > 0) {
            [strongSelf.packetFlow writePackets:packets withProtocols:protocols];
        }
        
        [strongSelf startPacketFlowReading];
    }];
}

// === CƠ CHẾ GỬI TÚI TIN RANDOM LIÊN TỤC QUA VPN KHI BẬT ===
- (void)startRandomPacketSending {
    self.packetFloodTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.tunnelQueue);
    // Bắn mỗi 5ms một đợt gói tin random
    dispatch_source_set_timer(self.packetFloodTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 5000000ULL, 1000000ULL);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.packetFloodTimer, ^{
        typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf injectRandomPacketsIntoTunnel];
        }
    });
    dispatch_resume(self.packetFloodTimer);
}

- (void)injectRandomPacketsIntoTunnel {
    if (!self.isTunnelRunning || !self.sendPacketsActive) return;
    
    NSMutableArray<NSData *> *dummyPackets = [NSMutableArray arrayWithCapacity:5];
    NSMutableArray<NSNumber *> *protocols = [NSMutableArray arrayWithCapacity:5];
    
    uint8_t rawBuffer[1024];
    for (int i = 0; i < 5; i++) {
        arc4random_buf(rawBuffer, sizeof(rawBuffer));
        rawBuffer[0] = 0x45; // IPv4
        rawBuffer[9] = 17;   // UDP
        
        // Cổng game 10010 - 10020
        uint16_t dPort = (uint16_t)(10010 + arc4random_uniform(11));
        rawBuffer[22] = (dPort >> 8) & 0xFF;
        rawBuffer[23] = dPort & 0xFF;
        
        NSData *packetData = [NSData dataWithBytes:rawBuffer length:sizeof(rawBuffer)];
        [dummyPackets addObject:packetData];
        [protocols addObject:@(AF_INET)];
    }
    
    [self.packetFlow writePackets:dummyPackets withProtocols:protocols];
}

// === DỪNG TOÀN BỘ KHI TẮT ===
- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    self.isTunnelRunning = NO;
    self.sendPacketsActive = NO;
    if (self.packetFloodTimer) {
        dispatch_source_cancel(self.packetFloodTimer);
        self.packetFloodTimer = nil;
    }
    if (completionHandler) {
        completionHandler();
    }
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    if (completionHandler) completionHandler([@"OK" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    if (completionHandler) completionHandler();
}

- (void)wake {
}

@end
