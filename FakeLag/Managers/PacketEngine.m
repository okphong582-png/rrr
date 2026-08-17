#import "PacketEngine.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>

@interface PacketEngine () {
    int _socketFd;
    dispatch_queue_t _workQueue;
    dispatch_source_t _timerSource;
    dispatch_source_t _statsTimer;
    
    uint64_t _totalPacketsSent;
    uint64_t _totalBytesSent;
    uint64_t _recentPackets;
    uint64_t _recentBytes;
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
        _currentMode = FakeLagModeFreeze;
        _packetSize = 1024;        // Kích thước túi tin (1024 Bytes)
        _packetsPerSecond = 1500;  // Tốc độ gửi túi tin (1500 gói/giây)
        _burstCount = 10;          // Số lượng gói mỗi đợt bắn
        _burstInterval = 0.005;    // 5ms mỗi đợt bắn
        _targetHost = @"127.0.0.1";
        _targetPort = 10015;       // Cổng game
        _isRunning = NO;
        _socketFd = -1;
        _workQueue = dispatch_queue_create("com.fakelag.randompacketengine", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSUInteger)bufferedPacketCount {
    return 0;
}

- (NSString *)nameForMode:(FakeLagMode)mode {
    return @"Gửi Túi Tin Random Qua VPN (Đóng Băng / Fake Lag)";
}

- (void)switchMode:(FakeLagMode)newMode {
    _currentMode = newMode;
}

- (void)cycleNextMode {
    // Single unified random packet flood mode
}

// === BẮT ĐẦU GỬI TÚI TIN RANDOM QUA VPN ===
- (void)start {
    @synchronized (self) {
        if (_isRunning) return;
        _isRunning = YES;
    }
    
    // Tạo Socket UDP
    _socketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (_socketFd < 0) {
        NSLog(@"[PacketEngine] Không thể tạo Socket: %s", strerror(errno));
        _isRunning = NO;
        return;
    }
    
    int flags = fcntl(_socketFd, F_GETFL, 0);
    fcntl(_socketFd, F_SETFL, flags | O_NONBLOCK);
    
    int broadcast = 1;
    setsockopt(_socketFd, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));
    
    _recentPackets = 0;
    _recentBytes = 0;
    
    // Timer gửi liên tục với tần số cao (mỗi 5ms gửi 1 đợt burst túi tin)
    uint64_t intervalNs = 5000000ULL; // 5ms
    _timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _workQueue);
    dispatch_source_set_timer(_timerSource, dispatch_time(DISPATCH_TIME_NOW, 0), intervalNs, intervalNs / 10);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_timerSource, ^{
        [weakSelf sendRandomPacketBurst];
    });
    dispatch_resume(_timerSource);
    
    // Timer thống kê số túi tin
    _statsTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_statsTimer, dispatch_time(DISPATCH_TIME_NOW, 1000000000ULL), 1000000000ULL, 100000000ULL);
    dispatch_source_set_event_handler(_statsTimer, ^{
        [weakSelf reportStats];
    });
    dispatch_resume(_statsTimer);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([weakSelf.delegate respondsToSelector:@selector(packetEngineStateChanged:)]) {
            [weakSelf.delegate packetEngineStateChanged:YES];
        }
    });
    
    NSLog(@"[PacketEngine] BẮT ĐẦU GỬI TÚI TIN RANDOM (PPS: %lu, Size: %lu bytes)", (unsigned long)_packetsPerSecond, (unsigned long)_packetSize);
}

// === DỪNG GỬI TÚI TIN ===
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
    
    NSLog(@"[PacketEngine] ĐÃ DỪNG GỬI TÚI TIN. Tổng gói đã phát: %llu pkts", _totalPacketsSent);
}

- (void)toggle {
    if (self.isRunning) {
        [self stop];
    } else {
        [self start];
    }
}

// Gửi 1 đợt túi tin ngẫu nhiên (Random Packet Burst)
- (void)sendRandomPacketBurst {
    if (!_isRunning || _socketFd < 0) return;
    
    NSUInteger size = MAX(MIN(_packetSize, 1472), 64);
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
        // Sinh payload ngẫu nhiên hoàn toàn (Túi tin random)
        arc4random_buf(buffer, size);
        
        // Random hóa cổng game (10010 - 10020) hoặc cổng tùy chỉnh
        uint16_t port = _targetPort > 0 ? _targetPort : (uint16_t)(10010 + arc4random_uniform(11));
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

- (void)reportStats {
    if (!_isRunning) return;
    
    NSUInteger pps = (NSUInteger)_recentPackets;
    NSUInteger bps = (NSUInteger)_recentBytes;
    _recentPackets = 0;
    _recentBytes = 0;
    
    if ([self.delegate respondsToSelector:@selector(packetEngineDidUpdateStatsWithPackets:bytes:packetsSec:bytesSec:bufferedPkts:)]) {
        [self.delegate packetEngineDidUpdateStatsWithPackets:(NSUInteger)_totalPacketsSent
                                                      bytes:(NSUInteger)_totalBytesSent
                                                packetsSec:pps
                                                   bytesSec:bps
                                               bufferedPkts:0];
    }
}

- (void)dealloc {
    [self stop];
}

@end
