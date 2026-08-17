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
@property (nonatomic, assign) BOOL freezeEnabled;
@property (nonatomic, assign) BOOL isDropPhase;
@property (nonatomic, assign) NSTimeInterval cycleStart;
@property (nonatomic, strong) dispatch_queue_t tunnelQueue;

@end

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    self.isTunnelRunning = YES;
    self.freezeEnabled = YES;
    self.isDropPhase = YES;
    self.cycleStart = [NSDate timeIntervalSinceReferenceDate];
    self.tunnelQueue = dispatch_queue_create("com.fakelag.cyclicfreeze", DISPATCH_QUEUE_SERIAL);
    
    // Cấu hình TUN interface cho NetworkExtension VPN
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
        __strong PacketTunnelProvider *strongSelf = weakSelf;
        if (error) {
            NSLog(@"[FakeLagTunnel] Lỗi cấu hình VPN: %@", error.localizedDescription);
            if (completionHandler) completionHandler(error);
            return;
        }
        
        if (strongSelf) {
            [strongSelf startPacketProcessing];
        }
        
        if (completionHandler) completionHandler(nil);
    }];
}

// === CƠ CHẾ FREEZE CHU KỲ (2.0s DROP, 0.5s THẢ) - PING THẤP, ĐỊCH ĐƠ HOÀN TOÀN ===
- (void)startPacketProcessing {
    if (!self.isTunnelRunning) return;
    
    __weak typeof(self) weakSelf = self;
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        __strong PacketTunnelProvider *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isTunnelRunning) return;
        
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        NSTimeInterval elapsed = now - strongSelf.cycleStart;
        
        // Quản lý chu kỳ: 2.0s Drop -> 0.5s Thả
        const NSTimeInterval CYCLE_DROP = 2.0;
        const NSTimeInterval CYCLE_RELEASE = 0.5;
        
        if (strongSelf.isDropPhase && elapsed >= CYCLE_DROP) {
            strongSelf.isDropPhase = NO;
            strongSelf.cycleStart = now;
        } else if (!strongSelf.isDropPhase && elapsed >= CYCLE_RELEASE) {
            strongSelf.isDropPhase = YES;
            strongSelf.cycleStart = now;
        }
        
        NSMutableArray<NSData *> *forwardPackets = [NSMutableArray arrayWithCapacity:packets.count];
        NSMutableArray<NSNumber *> *forwardProtocols = [NSMutableArray arrayWithCapacity:protocols.count];
        
        for (NSUInteger i = 0; i < packets.count; i++) {
            NSData *pktData = packets[i];
            NSNumber *proto = protocols[i];
            
            BOOL dropThis = NO;
            
            if (pktData.length >= 28) {
                const uint8_t *bytes = (const uint8_t *)pktData.bytes;
                uint8_t ipVer = (bytes[0] >> 4) & 0x0F;
                
                if (ipVer == 4 && bytes[9] == 17) { // IPv4 UDP
                    uint8_t ihl = (bytes[0] & 0x0F) * 4;
                    if (pktData.length >= ihl + 8) {
                        uint16_t srcPort = ntohs(*(uint16_t *)&bytes[ihl]);
                        uint16_t dstPort = ntohs(*(uint16_t *)&bytes[ihl + 2]);
                        
                        // Bỏ qua DNS (53), NTP (123)
                        if (srcPort != 53 && dstPort != 53 && srcPort != 123) {
                            // Nhận diện cổng game UDP (10010 - 10020)
                            BOOL isGameTraffic = (srcPort >= 10010 && srcPort <= 10020) || (dstPort >= 10010 && dstPort <= 10020);
                            
                            // Nếu FREEZE ĐANG BẬT và đang trong pha 2.0s Drop -> DROP GÓI TIN
                            if (strongSelf.freezeEnabled && strongSelf.isDropPhase && isGameTraffic) {
                                dropThis = YES;
                            }
                        }
                    }
                }
            }
            
            if (!dropThis) {
                [forwardPackets addObject:pktData];
                [forwardProtocols addObject:proto];
            }
        }
        
        if (forwardPackets.count > 0) {
            [strongSelf.packetFlow writePackets:forwardPackets withProtocols:forwardProtocols];
        }
        
        [strongSelf startPacketProcessing];
    }];
}

// === TẮT FREEZE: THẢ TOÀN BỘ 100% ===
- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    self.isTunnelRunning = NO;
    self.freezeEnabled = NO;
    self.isDropPhase = NO;
    
    if (completionHandler) {
        completionHandler();
    }
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    NSString *cmd = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    if ([cmd isEqualToString:@"FREEZE_ON"]) {
        self.freezeEnabled = YES;
        self.isDropPhase = YES;
        self.cycleStart = [NSDate timeIntervalSinceReferenceDate];
    } else if ([cmd isEqualToString:@"FREEZE_OFF"]) {
        self.freezeEnabled = NO;
        self.isDropPhase = NO;
    }
    
    if (completionHandler) completionHandler([@"OK" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    if (completionHandler) completionHandler();
}

- (void)wake {
}

@end
