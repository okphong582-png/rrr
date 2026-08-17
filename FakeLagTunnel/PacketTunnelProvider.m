#import "PacketTunnelProvider.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/ip.h>
#import <netinet/udp.h>
#import <arpa/inet.h>

@interface PacketTunnelProvider () {
    BOOL _isTunnelRunning;
    BOOL _freezeActive;
    dispatch_queue_t _tunnelQueue;
    NSMutableArray<NSData *> *_freezePacketBuffer;
}
@end

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    _isTunnelRunning = YES;
    _freezeActive = YES;
    _freezePacketBuffer = [NSMutableArray array];
    _tunnelQueue = dispatch_queue_create("com.fakelag.freezetunnel", DISPATCH_QUEUE_SERIAL);
    
    // Cấu hình Virtual Network Settings cho VPN hệ thống iOS
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"127.0.0.1"];
    
    // IPv4 Settings
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"10.99.0.2"]
                                                                 subnetMasks:@[@"255.255.255.0"]];
    NEIPv4Route *route = [[NEIPv4Route alloc] initWithDestinationAddress:@"0.0.0.0"
                                                              subnetMask:@"0.0.0.0"];
    ipv4Settings.includedRoutes = @[route];
    settings.IPv4Settings = ipv4Settings;
    
    // DNS Settings
    NEDNSSettings *dnsSettings = [[NEDNSSettings alloc] initWithServers:@[@"1.1.1.1", @"8.8.8.8"]];
    settings.DNSSettings = dnsSettings;
    settings.MTU = @(1400);
    
    __weak typeof(self) weakSelf = self;
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[FakeLagTunnel] Lỗi thiết lập VPN: %@", error.localizedDescription);
            if (completionHandler) completionHandler(error);
            return;
        }
        
        // Bắt đầu lắng nghe và chặn gói tin Freeze
        [weakSelf startPacketFlowReading];
        
        if (completionHandler) completionHandler(nil);
    }];
}

// === CƠ CHẾ FREEZE (ĐÓNG BĂNG ĐỊCH) CHUẨN 100% HI.PY ===
// FILTER_I: (udp.SrcPort >= 10011 and udp.SrcPort <= 10019) and (30 <= payload_len <= 1079)
// Chặn gói tin từ Server gửi về máy -> Toàn bộ đối phương / địch trên màn hình đứng đơ bất động
- (void)startPacketFlowReading {
    if (!_isTunnelRunning) return;
    
    __weak typeof(self) weakSelf = self;
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        if (!weakSelf || !weakSelf->_isTunnelRunning) return;
        
        NSMutableArray<NSData *> *passPackets = [NSMutableArray array];
        NSMutableArray<NSNumber *> *passProtocols = [NSMutableArray array];
        
        for (NSUInteger i = 0; i < packets.count; i++) {
            NSData *pktData = packets[i];
            NSNumber *proto = protocols[i];
            
            if (pktData.length >= 28) {
                const uint8_t *bytes = (const uint8_t *)pktData.bytes;
                uint8_t ipVersion = (bytes[0] >> 4) & 0x0F;
                
                if (ipVersion == 4) {
                    uint8_t ipProto = bytes[9];
                    
                    if (ipProto == 17) { // Giao thức UDP
                        uint16_t srcPort = (bytes[20] << 8) | bytes[21];
                        uint16_t dstPort = (bytes[22] << 8) | bytes[23];
                        NSUInteger totalIpLen = (bytes[2] << 8) | bytes[3];
                        NSUInteger udpPayloadLen = pktData.length >= 28 ? (pktData.length - 28) : 0;
                        
                        // Bỏ qua các port bảo vệ hệ thống: DNS (53), NTP (123), SSDP (1900)
                        if (srcPort == 53 || dstPort == 53 || srcPort == 123 || srcPort == 1900) {
                            [passPackets addObject:pktData];
                            [passProtocols addObject:proto];
                            continue;
                        }
                        
                        // === ÁP DỤNG BỘ LỌC FREEZE CHUẨN HI.PY ===
                        if (weakSelf->_freezeActive) {
                            // Chặn gói tin Inbound từ Game Server gửi về máy client
                            if (srcPort >= 10011 && srcPort <= 10019) {
                                if ((udpPayloadLen >= 30 && udpPayloadLen <= 1079) ||
                                    (totalIpLen >= 58 && totalIpLen <= 1107)) {
                                    
                                    // Lưu vào bộ đệm Freeze buffer và DROP (chặn không cho game nhận)
                                    // -> Kết quả: Địch trên màn hình đứng đơ bất động
                                    @synchronized (weakSelf) {
                                        if (weakSelf->_freezePacketBuffer.count < 3000) {
                                            [weakSelf->_freezePacketBuffer addObject:pktData];
                                        }
                                    }
                                    continue; // DROP GÓI TIN ĐỂ ĐÓNG BĂNG ĐỊCH
                                }
                            }
                        }
                    }
                }
            }
            
            // Các gói tin thông thường khác cho qua
            [passPackets addObject:pktData];
            [passProtocols addObject:proto];
        }
        
        if (passPackets.count > 0) {
            [weakSelf.packetFlow writePackets:passPackets withProtocols:passProtocols];
        }
        
        // Tiếp tục vòng lặp đọc gói
        [weakSelf startPacketFlowReading];
    }];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    _isTunnelRunning = NO;
    _freezeActive = NO;
    
    // Khi TẮT Freeze: Xả toàn bộ túi tin đệm để game đồng bộ kết quả sát thương
    @synchronized (self) {
        if (_freezePacketBuffer.count > 0) {
            NSMutableArray<NSNumber *> *protos = [NSMutableArray arrayWithCapacity:_freezePacketBuffer.count];
            for (NSUInteger i = 0; i < _freezePacketBuffer.count; i++) {
                [protos addObject:@(AF_INET)];
            }
            [self.packetFlow writePackets:_freezePacketBuffer withProtocols:protos];
            [_freezePacketBuffer removeAllObjects];
        }
    }
    
    if (completionHandler) {
        completionHandler();
    }
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    NSString *cmd = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    if ([cmd isEqualToString:@"FREEZE_ON"]) {
        _freezeActive = YES;
    } else if ([cmd isEqualToString:@"FREEZE_OFF"]) {
        _freezeActive = NO;
        // Xả đệm
        @synchronized (self) {
            if (_freezePacketBuffer.count > 0) {
                NSMutableArray<NSNumber *> *protos = [NSMutableArray arrayWithCapacity:_freezePacketBuffer.count];
                for (NSUInteger i = 0; i < _freezePacketBuffer.count; i++) {
                    [protos addObject:@(AF_INET)];
                }
                [self.packetFlow writePackets:_freezePacketBuffer withProtocols:protos];
                [_freezePacketBuffer removeAllObjects];
            }
        }
    }
    
    if (completionHandler) {
        completionHandler([@"OK" dataUsingEncoding:NSUTF8StringEncoding]);
    }
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    if (completionHandler) completionHandler();
}

- (void)wake {
}

@end
