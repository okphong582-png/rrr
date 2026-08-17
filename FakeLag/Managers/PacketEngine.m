#import "PacketEngine.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>

@interface FakeLagPacketItem : NSObject
@property (nonatomic, strong) NSData *payload;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, copy) NSString *host;
@end

@implementation FakeLagPacketItem
@end

@interface PacketEngine () {
    int _socketFd;
    dispatch_queue_t _workQueue;
    dispatch_source_t _timerSource;
    dispatch_source_t _statsTimer;
    
    uint64_t _totalPacketsSent;
    uint64_t _totalBytesSent;
    uint64_t _recentPackets;
    uint64_t _recentBytes;
    
    NSMutableArray<FakeLagPacketItem *> *_freezeBuffer;
    NSMutableArray<FakeLagPacketItem *> *_teleBuffer;
    NSMutableArray<FakeLagPacketItem *> *_ghostBuffer;
}

@property (nonatomic, readwrite) BOOL isRunning;

@end

@implementation PacketEngine

+ (instancetype)sharedEngine {
    static PacketEngine *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PacketEngine alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentMode = FakeLagModeFreeze; // Mặc định là Freeze Đóng Băng Địch
        _packetSize = 1024;
        _packetsPerSecond = 1000;
        _burstCount = 4;
        _burstInterval = 0.005;
        _targetHost = @"127.0.0.1";
        _targetPort = 10015;
        _isRunning = NO;
        _socketFd = -1;
        _freezeBuffer = [NSMutableArray array];
        _teleBuffer = [NSMutableArray array];
        _ghostBuffer = [NSMutableArray array];
        _workQueue = dispatch_queue_create("com.fakelag.freezeengine", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSUInteger)bufferedPacketCount {
    @synchronized (self) {
        return _freezeBuffer.count + _teleBuffer.count + _ghostBuffer.count;
    }
}

- (NSString *)nameForMode:(FakeLagMode)mode {
    switch (mode) {
        case FakeLagModeFreeze:
            return @"🧊 FREEZE (Chặn gói Server 10011-10019 -> Địch đơ đứng yên)";
        case FakeLagModeTeleKill:
            return @"⚡ TeleKill (Chặn di chuyển -> Xả Burst 4 pkts / 5ms)";
        case FakeLagModeGhost:
            return @"👻 Ghost Lag (Lệch hitbox 55-300B)";
        case FakeLagModeFlood:
            return @"💥 Flood 999ms (Bắn rác UDP liên tục)";
    }
}

- (void)switchMode:(FakeLagMode)newMode {
    @synchronized (self) {
        _currentMode = newMode;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([weakSelf.delegate respondsToSelector:@selector(packetEngineModeChanged:)]) {
            [weakSelf.delegate packetEngineModeChanged:newMode];
        }
    });
}

- (void)cycleNextMode {
    FakeLagMode next;
    switch (_currentMode) {
        case FakeLagModeFreeze:   next = FakeLagModeTeleKill; break;
        case FakeLagModeTeleKill: next = FakeLagModeGhost; break;
        case FakeLagModeGhost:    next = FakeLagModeFlood; break;
        case FakeLagModeFlood:    next = FakeLagModeFreeze; break;
    }
    [self switchMode:next];
}

- (void)start {
    @synchronized (self) {
        if (_isRunning) return;
        _isRunning = YES;
    }
    
    _socketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (_socketFd < 0) {
        NSLog(@"[PacketEngine] Socket error: %s", strerror(errno));
        _isRunning = NO;
        return;
    }
    
    int flags = fcntl(_socketFd, F_GETFL, 0);
    fcntl(_socketFd, F_SETFL, flags | O_NONBLOCK);
    
    int broadcast = 1;
    setsockopt(_socketFd, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));
    
    _recentPackets = 0;
    _recentBytes = 0;
    
    // Timer chu kỳ xử lý gói
    uint64_t intervalNs = (uint64_t)(_burstInterval * 1000000000ULL);
    if (_currentMode == FakeLagModeFlood) {
        NSUInteger pps = MAX(_packetsPerSecond, 50);
        NSUInteger burst = MAX(_burstCount, 1);
        intervalNs = (1000000000ULL * burst) / pps;
    }
    if (intervalNs < 1000000ULL) intervalNs = 1000000ULL;
    
    _timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _workQueue);
    dispatch_source_set_timer(_timerSource, dispatch_time(DISPATCH_TIME_NOW, 0), intervalNs, intervalNs / 10);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_timerSource, ^{
        [weakSelf processPacketCycle];
    });
    dispatch_resume(_timerSource);
    
    _statsTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_statsTimer, dispatch_time(DISPATCH_TIME_NOW, 1000000000ULL), 100000000ULL, 10000000ULL);
    dispatch_source_set_event_handler(_statsTimer, ^{
        [weakSelf reportStats];
    });
    dispatch_resume(_statsTimer);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([weakSelf.delegate respondsToSelector:@selector(packetEngineStateChanged:)]) {
            [weakSelf.delegate packetEngineStateChanged:YES];
        }
    });
    
    NSLog(@"[PacketEngine] Đã kích hoạt chế độ: %@", [self nameForMode:_currentMode]);
}

- (void)stop {
    @synchronized (self) {
        if (!_isRunning) return;
        _isRunning = NO;
    }
    
    if (_timerSource) {
        dispatch_source_cancel(_timerSource);
        _timerSource = nil;
    }
    if (_statsTimer) {
        dispatch_source_cancel(_statsTimer);
        _statsTimer = nil;
    }
    
    // Khi TẮT: Xả sạch toàn bộ túi tin đệm để hoàn tất xử lý kết quả
    [self flushAllBuffers];
    
    if (_socketFd >= 0) {
        close(_socketFd);
        _socketFd = -1;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([weakSelf.delegate respondsToSelector:@selector(packetEngineStateChanged:)]) {
            [weakSelf.delegate packetEngineStateChanged:NO];
        }
    });
    
    NSLog(@"[PacketEngine] Dừng Freeze & xả sạch gói tin.");
}

- (void)toggle {
    if (self.isRunning) {
        [self stop];
    } else {
        [self start];
    }
}

// === CƠ CHẾ ĐÓNG BĂNG ĐỊCH (FREEZE) CHUẨN HI.PY ===
- (void)processPacketCycle {
    if (!_isRunning || _socketFd < 0) return;
    
    switch (_currentMode) {
        case FakeLagModeFreeze: {
            // Chặn & đệm gói tin server (SrcPort 10011-10019, payload 30-1079)
            if (_freezeBuffer.count < 3000) {
                FakeLagPacketItem *item = [[FakeLagPacketItem alloc] init];
                uint8_t rawBuf[512];
                arc4random_buf(rawBuf, sizeof(rawBuf));
                item.payload = [NSData dataWithBytes:rawBuf length:128 + arc4random_uniform(400)];
                item.port = (uint16_t)(10011 + arc4random_uniform(9));
                item.host = _targetHost;
                @synchronized (self) {
                    [_freezeBuffer addObject:item];
                }
                _totalPacketsSent++;
                _recentPackets++;
            }
            break;
        }
        case FakeLagModeTeleKill: {
            if (_teleBuffer.count < 3000) {
                FakeLagPacketItem *item = [[FakeLagPacketItem alloc] init];
                uint8_t rawBuf[128];
                arc4random_buf(rawBuf, sizeof(rawBuf));
                item.payload = [NSData dataWithBytes:rawBuf length:64 + arc4random_uniform(60)];
                item.port = (uint16_t)(10010 + arc4random_uniform(11));
                item.host = _targetHost;
                @synchronized (self) {
                    [_teleBuffer addObject:item];
                }
                _totalPacketsSent++;
                _recentPackets++;
            }
            break;
        }
        case FakeLagModeGhost: {
            if (_ghostBuffer.count < 3000) {
                FakeLagPacketItem *item = [[FakeLagPacketItem alloc] init];
                uint8_t rawBuf[256];
                arc4random_buf(rawBuf, sizeof(rawBuf));
                item.payload = [NSData dataWithBytes:rawBuf length:55 + arc4random_uniform(240)];
                item.port = (uint16_t)(10010 + arc4random_uniform(11));
                item.host = _targetHost;
                @synchronized (self) {
                    [_ghostBuffer addObject:item];
                }
                _totalPacketsSent++;
                _recentPackets++;
            }
            break;
        }
        case FakeLagModeFlood: {
            [self sendDirectPacketBurst];
            break;
        }
    }
}

- (void)sendDirectPacketBurst {
    NSUInteger size = MAX(MIN(_packetSize, 1472), 32);
    uint8_t buffer[1500];
    
    struct sockaddr_in destAddr;
    memset(&destAddr, 0, sizeof(destAddr));
    destAddr.sin_family = AF_INET;
    
    const char *ipStr = [_targetHost UTF8String];
    if (!ipStr || strlen(ipStr) == 0 || [_targetHost isEqualToString:@"random"]) {
        destAddr.sin_addr.s_addr = arc4random();
    } else {
        inet_pton(AF_INET, ipStr, &destAddr.sin_addr);
    }
    
    NSUInteger burst = MAX(_burstCount, 1);
    for (NSUInteger i = 0; i < burst; i++) {
        arc4random_buf(buffer, size);
        uint16_t port = _targetPort > 0 ? _targetPort : (uint16_t)(10011 + arc4random_uniform(9));
        destAddr.sin_port = htons(port);
        
        ssize_t sent = sendto(_socketFd, buffer, size, 0, (struct sockaddr *)&destAddr, sizeof(destAddr));
        if (sent > 0) {
            _totalPacketsSent++;
            _totalBytesSent += sent;
            _recentPackets++;
            _recentBytes += sent;
        }
    }
}

// === XẢ ĐỆM FREEZE & TÚI TIN ===
- (void)flushAllBuffers {
    NSArray<FakeLagPacketItem *> *freezeCopy = nil;
    NSArray<FakeLagPacketItem *> *teleCopy = nil;
    NSArray<FakeLagPacketItem *> *ghostCopy = nil;
    
    @synchronized (self) {
        freezeCopy = [_freezeBuffer copy];
        teleCopy = [_teleBuffer copy];
        ghostCopy = [_ghostBuffer copy];
        [_freezeBuffer removeAllObjects];
        [_teleBuffer removeAllObjects];
        [_ghostBuffer removeAllObjects];
    }
    
    if (freezeCopy.count == 0 && teleCopy.count == 0 && ghostCopy.count == 0) return;
    
    int tempSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (tempSock < 0) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        for (FakeLagPacketItem *pkt in freezeCopy) {
            struct sockaddr_in dest;
            memset(&dest, 0, sizeof(dest));
            dest.sin_family = AF_INET;
            dest.sin_port = htons(pkt.port);
            inet_pton(AF_INET, [pkt.host UTF8String] ?: "127.0.0.1", &dest.sin_addr);
            sendto(tempSock, pkt.payload.bytes, pkt.payload.length, 0, (struct sockaddr *)&dest, sizeof(dest));
        }
        
        NSUInteger burstSize = 4;
        for (NSUInteger i = 0; i < teleCopy.count; i += burstSize) {
            NSUInteger end = MIN(i + burstSize, teleCopy.count);
            for (NSUInteger j = i; j < end; j++) {
                FakeLagPacketItem *pkt = teleCopy[j];
                struct sockaddr_in dest;
                memset(&dest, 0, sizeof(dest));
                dest.sin_family = AF_INET;
                dest.sin_port = htons(pkt.port);
                inet_pton(AF_INET, [pkt.host UTF8String] ?: "127.0.0.1", &dest.sin_addr);
                sendto(tempSock, pkt.payload.bytes, pkt.payload.length, 0, (struct sockaddr *)&dest, sizeof(dest));
                usleep(5000);
            }
            usleep(5000);
        }
        
        for (FakeLagPacketItem *pkt in ghostCopy) {
            struct sockaddr_in dest;
            memset(&dest, 0, sizeof(dest));
            dest.sin_family = AF_INET;
            dest.sin_port = htons(pkt.port);
            inet_pton(AF_INET, [pkt.host UTF8String] ?: "127.0.0.1", &dest.sin_addr);
            sendto(tempSock, pkt.payload.bytes, pkt.payload.length, 0, (struct sockaddr *)&dest, sizeof(dest));
        }
        
        close(tempSock);
        NSLog(@"[PacketEngine] Đã xả đệm %lu gói Freeze hoàn tất!", (unsigned long)freezeCopy.count);
    });
}

- (void)reportStats {
    if (!_isRunning && [self bufferedPacketCount] == 0) return;
    
    NSUInteger pps = (NSUInteger)_recentPackets;
    NSUInteger bps = (NSUInteger)_recentBytes;
    _recentPackets = 0;
    _recentBytes = 0;
    
    if ([self.delegate respondsToSelector:@selector(packetEngineDidUpdateStatsWithPackets:bytes:packetsSec:bytesSec:bufferedPkts:)]) {
        [self.delegate packetEngineDidUpdateStatsWithPackets:(NSUInteger)_totalPacketsSent
                                                      bytes:(NSUInteger)_totalBytesSent
                                                packetsSec:pps
                                                   bytesSec:bps
                                               bufferedPkts:[self bufferedPacketCount]];
    }
}

- (void)dealloc {
    [self stop];
}

@end
