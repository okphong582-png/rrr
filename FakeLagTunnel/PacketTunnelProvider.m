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
@property (nonatomic, assign) BOOL freezeActive;
@property (nonatomic, strong) dispatch_queue_t tunnelQueue;
@property (nonatomic, strong) NSMutableArray<NSData *> *freezePacketBuffer;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *freezeProtocolBuffer;

@end

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    self.isTunnelRunning = YES;
    self.freezeActive = YES;
    self.freezePacketBuffer = [NSMutableArray arrayWithCapacity:3000];
    self.freezeProtocolBuffer = [NSMutableArray arrayWithCapacity:3000];
    self.tunnelQueue = dispatch_queue_create("com.fakelag.freezetunnel", DISPATCH_QUEUE_SERIAL);
    
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
        typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            NSLog(@"[FakeLagTunnel] Lỗi cấu hình VPN: %@", error.localizedDescription);
            if (completionHandler) completionHandler(error);
            return;
        }
        
        if (strongSelf) {
            [strongSelf startPacketInterception];
        }
        
        if (completionHandler) completionHandler(nil);
    }];
}

// === BỘ LỌC GÓI TIN CHUẨN 100% HI.PY (TELEKILL & FREEZE) ===
- (void)startPacketInterception {
    if (!self.isTunnelRunning) return;
    
    __weak typeof(self) weakSelf = self;
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isTunnelRunning) return;
        
        NSMutableArray<NSData *> *passPackets = [NSMutableArray arrayWithCapacity:packets.count];
        NSMutableArray<NSNumber *> *passProtocols = [NSMutableArray arrayWithCapacity:protocols.count];
        
        for (NSUInteger i = 0; i < packets.count; i++) {
            NSData *pktData = packets[i];
            NSNumber *proto = protocols[i];
            
            BOOL shouldDrop = NO;
            
            if (pktData.length >= 28) {
                const uint8_t *bytes = (const uint8_t *)pktData.bytes;
                uint8_t ipVer = (bytes[0] >> 4) & 0x0F;
                
                if (ipVer == 4 && bytes[9] == 17) { // IPv4 UDP
                    uint8_t ihl = (bytes[0] & 0x0F) * 4;
                    if (pktData.length >= ihl + 8) {
                        uint16_t srcPort = ntohs(*(uint16_t *)&bytes[ihl]);
                        uint16_t dstPort = ntohs(*(uint16_t *)&bytes[ihl + 2]);
                        NSUInteger payloadLen = pktData.length - (ihl + 8);
                        
                        // BỎ QUA DNS (53), NTP (123), SSDP (1900), WireGuard (51820-51835) CHUẨN HI.PY
                        if (srcPort != 53 && dstPort != 53 && srcPort != 123 && srcPort != 1900) {
                            
                            // 1. BỘ LỌC FREEZE HI.PY: (10011 <= SrcPort <= 10019) và (30 <= payload <= 1079)
                            BOOL isFreezeInbound = (srcPort >= 10011 && srcPort <= 10019 && payloadLen >= 30 && payloadLen <= 1079);
                            
                            // 2. BỘ LỌC TELEKILL / FREEZE OUTBOUND HI.PY: (10010 <= DstPort <= 10020) và payload >= 43
                            BOOL isGameOutbound = (dstPort >= 10010 && dstPort <= 10020 && payloadLen >= 43);
                            
                            // 3. TOÀN BỘ CỔNG GAME 10010 - 10020
                            BOOL isGamePort = (srcPort >= 10010 && srcPort <= 10020) || (dstPort >= 10010 && dstPort <= 10020);
                            
                            if (strongSelf.freezeActive && (isFreezeInbound || isGameOutbound || isGamePort)) {
                                shouldDrop = YES;
                                @synchronized (strongSelf) {
                                    if (strongSelf.freezePacketBuffer.count < 3000) {
                                        [strongSelf.freezePacketBuffer addObject:pktData];
                                        [strongSelf.freezeProtocolBuffer addObject:proto];
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if (!shouldDrop) {
                [passPackets addObject:pktData];
                [passProtocols addObject:proto];
            }
        }
        
        // Cho qua các gói không bị chặn
        if (passPackets.count > 0) {
            [strongSelf.packetFlow writePackets:passPackets withProtocols:passProtocols];
        }
        
        [strongSelf startPacketInterception];
    }];
}

// === DỪNG VPN & XẢ SẠCH ĐỆM GÓI TIN ĐỂ ĐỒNG BỘ GAME ===
- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    self.isTunnelRunning = NO;
    self.freezeActive = NO;
    
    [self flushFreezeBuffer];
    
    if (completionHandler) {
        completionHandler();
    }
}

- (void)flushFreezeBuffer {
    @synchronized (self) {
        if (self.freezePacketBuffer.count > 0) {
            [self.packetFlow writePackets:self.freezePacketBuffer withProtocols:self.freezeProtocolBuffer];
            [self.freezePacketBuffer removeAllObjects];
            [self.freezeProtocolBuffer removeAllObjects];
        }
    }
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    NSString *cmd = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    if ([cmd isEqualToString:@"FREEZE_ON"]) {
        self.freezeActive = YES;
    } else if ([cmd isEqualToString:@"FREEZE_OFF"]) {
        self.freezeActive = NO;
        [self flushFreezeBuffer];
    }
    
    if (completionHandler) completionHandler([@"OK" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    if (completionHandler) completionHandler();
}

- (void)wake {
}

@end
