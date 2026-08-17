#import "PacketTunnelProvider.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/ip.h>
#import <netinet/udp.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>

@interface UDPNatSession : NSObject
@property (nonatomic, assign) int socketFd;
@property (nonatomic, assign) uint16_t clientPort;
@property (nonatomic, assign) uint32_t clientIP;
@property (nonatomic, assign) uint16_t remotePort;
@property (nonatomic, assign) uint32_t remoteIP;
@property (nonatomic, strong) dispatch_source_t readSource;
@end

@implementation UDPNatSession
@end

@interface PacketTunnelProvider ()

@property (nonatomic, assign) BOOL isTunnelRunning;
@property (nonatomic, assign) BOOL freezeActive;
@property (nonatomic, strong) dispatch_queue_t tunnelQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UDPNatSession *> *natTable;
@property (nonatomic, strong) NSMutableArray<NSData *> *freezePacketBuffer;

@end

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    self.isTunnelRunning = YES;
    self.freezeActive = YES;
    self.natTable = [NSMutableDictionary dictionary];
    self.freezePacketBuffer = [NSMutableArray array];
    self.tunnelQueue = dispatch_queue_create("com.fakelag.freezetunnel", DISPATCH_QUEUE_SERIAL);
    
    // Cấu hình TUN interface cho NetworkExtension VPN
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"127.0.0.1"];
    
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"10.99.0.2"]
                                                                 subnetMasks:@[@"255.255.255.0"]];
    // Định tuyến toàn bộ lưu lượng hoặc dải game
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
            [strongSelf startPacketFlowReading];
        }
        
        if (completionHandler) completionHandler(nil);
    }];
}

// === ĐỌC GÓI TIN TỪ GAME VÀ CHUYỂN TIẾP RA SERVER THẬT ===
- (void)startPacketFlowReading {
    if (!self.isTunnelRunning) return;
    
    __weak typeof(self) weakSelf = self;
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isTunnelRunning) return;
        
        for (NSData *pktData in packets) {
            [strongSelf processOutboundPacket:pktData];
        }
        
        [strongSelf startPacketFlowReading];
    }];
}

// Xử lý gói tin outbound từ iPhone ra Internet
- (void)processOutboundPacket:(NSData *)pktData {
    if (pktData.length < 28) return;
    
    const uint8_t *bytes = (const uint8_t *)pktData.bytes;
    uint8_t ipVer = (bytes[0] >> 4) & 0x0F;
    if (ipVer != 4) return;
    
    uint8_t protocol = bytes[9];
    if (protocol != 17) return; // Chỉ xử lý UDP cho game
    
    uint8_t ihl = (bytes[0] & 0x0F) * 4;
    if (pktData.length < ihl + 8) return;
    
    uint32_t srcIP = *(uint32_t *)&bytes[12];
    uint32_t dstIP = *(uint32_t *)&bytes[16];
    uint16_t srcPort = ntohs(*(uint16_t *)&bytes[ihl]);
    uint16_t dstPort = ntohs(*(uint16_t *)&bytes[ihl + 2]);
    uint16_t udpLen = ntohs(*(uint16_t *)&bytes[ihl + 4]);
    
    // Bỏ qua DNS
    if (srcPort == 53 || dstPort == 53) return;
    
    NSUInteger payloadOffset = ihl + 8;
    if (pktData.length < payloadOffset) return;
    NSUInteger payloadLen = pktData.length - payloadOffset;
    const uint8_t *payloadBytes = bytes + payloadOffset;
    
    NSString *sessionKey = [NSString stringWithFormat:@"%u_%u_%u", srcPort, dstIP, dstPort];
    UDPNatSession *session = self.natTable[sessionKey];
    
    if (!session) {
        int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (sock < 0) return;
        
        int flags = fcntl(sock, F_GETFL, 0);
        fcntl(sock, F_SETFL, flags | O_NONBLOCK);
        
        session = [[UDPNatSession alloc] init];
        session.socketFd = sock;
        session.clientPort = srcPort;
        session.clientIP = srcIP;
        session.remotePort = dstPort;
        session.remoteIP = dstIP;
        
        // Tạo background listener để đọc phản hồi từ Server Game
        __weak typeof(self) weakSelf = self;
        session.readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, sock, 0, self.tunnelQueue);
        dispatch_source_set_event_handler(session.readSource, ^{
            typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf handleInboundUDPFromSession:session];
            }
        });
        dispatch_resume(session.readSource);
        
        self.natTable[sessionKey] = session;
    }
    
    // Gửi dữ liệu ra game server
    struct sockaddr_in destAddr;
    memset(&destAddr, 0, sizeof(destAddr));
    destAddr.sin_family = AF_INET;
    destAddr.sin_port = htons(dstPort);
    destAddr.sin_addr.s_addr = dstIP;
    
    sendto(session.socketFd, payloadBytes, payloadLen, 0, (struct sockaddr *)&destAddr, sizeof(destAddr));
}

// === CƠ CHẾ FREEZE (ĐÓNG BĂNG ĐỊCH) CHUẨN 100% HI.PY ===
// Khi Server Game gửi gói tọa độ địch về (SrcPort 10011-10019, payload 30-1079)
// Nếu FREEZE ĐANG BẬT -> DROP HOÀN TOÀN (LƯU VÀO BUFFER) -> ĐỊCH ĐƠ BẤT ĐỘNG
- (void)handleInboundUDPFromSession:(UDPNatSession *)session {
    uint8_t buffer[2048];
    struct sockaddr_in fromAddr;
    socklen_t fromLen = sizeof(fromAddr);
    
    ssize_t received = recvfrom(session.socketFd, buffer, sizeof(buffer), 0, (struct sockaddr *)&fromAddr, &fromLen);
    if (received <= 0) return;
    
    uint16_t serverSrcPort = ntohs(fromAddr.sin_port);
    NSUInteger payloadLen = (NSUInteger)received;
    
    // BỘ LỌC FREEZE HI.PY: (10011 <= SrcPort <= 10019) và (30 <= payload <= 1079)
    BOOL isGameFreezePacket = (serverSrcPort >= 10011 && serverSrcPort <= 10019 && payloadLen >= 30 && payloadLen <= 1079);
    
    // Tạo raw IP/UDP packet để trả về cho game client
    NSData *rebuiltPacket = [self buildIPv4UDPPacketWithPayload:buffer
                                                         length:payloadLen
                                                          srcIP:fromAddr.sin_addr.s_addr
                                                        srcPort:serverSrcPort
                                                          dstIP:session.clientIP
                                                        dstPort:session.clientPort];
    
    if (self.freezeActive && isGameFreezePacket) {
        // === ĐANG BẬT FREEZE: CHẶN GÓI VỊ TRÍ TỪ SERVER ===
        // Game trên iPhone không nhận được tọa độ di chuyển của đối phương
        // -> KẾT QUẢ: TOÀN BỘ ĐỊCH TRÊN MÀN HÌNH ĐỨNG ĐƠ BẤT ĐỘNG
        @synchronized (self) {
            if (self.freezePacketBuffer.count < 3000) {
                [self.freezePacketBuffer addObject:rebuiltPacket];
            }
        }
        return; // DROP GÓI TIN ĐỂ ĐÓNG BĂNG ĐỊCH
    }
    
    // Nếu FREEZE TẮT hoặc gói tin bình thường -> Gửi lại về game ngay
    if (rebuiltPacket) {
        [self.packetFlow writePackets:@[rebuiltPacket] withProtocols:@[@(AF_INET)]];
    }
}

// Hàm đóng gói IP Header + UDP Header chuẩn RFC 791/768
- (NSData *)buildIPv4UDPPacketWithPayload:(const uint8_t *)payload
                                   length:(NSUInteger)payloadLen
                                    srcIP:(uint32_t)srcIP
                                  srcPort:(uint16_t)srcPort
                                    dstIP:(uint32_t)dstIP
                                  dstPort:(uint16_t)dstPort {
    NSUInteger totalLen = 20 + 8 + payloadLen;
    NSMutableData *pktData = [NSMutableData dataWithLength:totalLen];
    uint8_t *pktBytes = (uint8_t *)pktData.mutableBytes;
    
    // IP Header (20 bytes)
    pktBytes[0] = 0x45; // IPv4, Header Length 20
    pktBytes[1] = 0x00;
    pktBytes[2] = (totalLen >> 8) & 0xFF;
    pktBytes[3] = totalLen & 0xFF;
    pktBytes[4] = 0x00;
    pktBytes[5] = 0x00;
    pktBytes[6] = 0x40; // Don't fragment
    pktBytes[7] = 0x00;
    pktBytes[8] = 64;   // TTL
    pktBytes[9] = 17;   // UDP Protocol
    pktBytes[10] = 0x00; // Checksum placeholder
    pktBytes[11] = 0x00;
    *(uint32_t *)&pktBytes[12] = srcIP;
    *(uint32_t *)&pktBytes[13] = dstIP;
    
    // Calculate IP Checksum
    uint32_t sum = 0;
    for (int i = 0; i < 20; i += 2) {
        sum += (pktBytes[i] << 8) + pktBytes[i + 1];
    }
    while (sum >> 16) {
        sum = (sum & 0xFFFF) + (sum >> 16);
    }
    uint16_t ipChecksum = htons(~sum);
    *(uint16_t *)&pktBytes[10] = ipChecksum;
    
    // UDP Header (8 bytes)
    uint16_t udpTotalLen = 8 + payloadLen;
    pktBytes[20] = (srcPort >> 8) & 0xFF;
    pktBytes[21] = srcPort & 0xFF;
    pktBytes[22] = (dstPort >> 8) & 0xFF;
    pktBytes[23] = dstPort & 0xFF;
    pktBytes[24] = (udpTotalLen >> 8) & 0xFF;
    pktBytes[25] = udpTotalLen & 0xFF;
    pktBytes[26] = 0x00; // UDP Checksum optional
    pktBytes[27] = 0x00;
    
    // Copy Payload
    memcpy(pktBytes + 28, payload, payloadLen);
    
    return pktData;
}

// === DỪNG VPN & XẢ SẠCH ĐỆM FREEZE ===
- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    self.isTunnelRunning = NO;
    self.freezeActive = NO;
    
    // Xả toàn bộ túi tin đệm khi dừng để game đồng bộ sát thương
    @synchronized (self) {
        if (self.freezePacketBuffer.count > 0) {
            NSMutableArray<NSNumber *> *protos = [NSMutableArray arrayWithCapacity:self.freezePacketBuffer.count];
            for (NSUInteger i = 0; i < self.freezePacketBuffer.count; i++) {
                [protos addObject:@(AF_INET)];
            }
            [self.packetFlow writePackets:self.freezePacketBuffer withProtocols:protos];
            [self.freezePacketBuffer removeAllObjects];
        }
    }
    
    // Đóng các socket NAT
    for (UDPNatSession *session in self.natTable.allValues) {
        if (session.readSource) {
            dispatch_source_cancel(session.readSource);
        }
        if (session.socketFd >= 0) {
            close(session.socketFd);
        }
    }
    [self.natTable removeAllObjects];
    
    if (completionHandler) {
        completionHandler();
    }
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    NSString *cmd = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    if ([cmd isEqualToString:@"FREEZE_ON"]) {
        self.freezeActive = YES;
    } else if ([cmd isEqualToString:@"FREEZE_OFF"]) {
        self.freezeActive = NO;
        // Xả đệm tức thì
        @synchronized (self) {
            if (self.freezePacketBuffer.count > 0) {
                NSMutableArray<NSNumber *> *protos = [NSMutableArray arrayWithCapacity:self.freezePacketBuffer.count];
                for (NSUInteger i = 0; i < self.freezePacketBuffer.count; i++) {
                    [protos addObject:@(AF_INET)];
                }
                [self.packetFlow writePackets:self.freezePacketBuffer withProtocols:protos];
                [self.freezePacketBuffer removeAllObjects];
            }
        }
    }
    
    if (completionHandler) completionHandler([@"OK" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    if (completionHandler) completionHandler();
}

- (void)wake {
}

@end
