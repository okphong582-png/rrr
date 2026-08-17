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
        _packetSize = 1024;
        _packetsPerSecond = 1000;
        _burstCount = 20;
        _targetHost = @"127.0.0.1";
        _targetPort = 0;
        _isRunning = NO;
        _socketFd = -1;
        _workQueue = dispatch_queue_create("com.fakelag.packetengine", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)start {
    @synchronized (self) {
        if (_isRunning) return;
        _isRunning = YES;
    }
    
    // Create UDP Socket
    _socketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (_socketFd < 0) {
        NSLog(@"[PacketEngine] Failed to create socket: %s", strerror(errno));
        _isRunning = NO;
        return;
    }
    
    // Set socket non-blocking
    int flags = fcntl(_socketFd, F_GETFL, 0);
    fcntl(_socketFd, F_SETFL, flags | O_NONBLOCK);
    
    // Enable broadcast
    int broadcast = 1;
    setsockopt(_socketFd, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));
    
    _totalPacketsSent = 0;
    _totalBytesSent = 0;
    _recentPackets = 0;
    _recentBytes = 0;
    
    // Calculate timer interval for bursts
    // If target PPS = 1000 and burst = 20, timer fires 50 times per second (every 20ms)
    NSUInteger pps = MAX(_packetsPerSecond, 50);
    NSUInteger burst = MAX(_burstCount, 1);
    uint64_t intervalNs = (1000000000ULL * burst) / pps;
    if (intervalNs < 1000000ULL) intervalNs = 1000000ULL; // Min 1ms
    
    _timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _workQueue);
    dispatch_source_set_timer(_timerSource, dispatch_time(DISPATCH_TIME_NOW, 0), intervalNs, intervalNs / 10);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_timerSource, ^{
        [weakSelf sendPacketBurst];
    });
    dispatch_resume(_timerSource);
    
    // Stats reporting timer (every 1.0 second)
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
    
    NSLog(@"[PacketEngine] Started generating random packets (Target PPS: %lu, Size: %lu)", (unsigned long)_packetsPerSecond, (unsigned long)_packetSize);
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
    
    NSLog(@"[PacketEngine] Stopped. Total sent: %llu packets, %llu bytes", _totalPacketsSent, _totalBytesSent);
}

- (void)toggle {
    if (self.isRunning) {
        [self stop];
    } else {
        [self start];
    }
}

- (void)sendPacketBurst {
    if (!_isRunning || _socketFd < 0) return;
    
    NSUInteger size = MAX(MIN(_packetSize, 1472), 32);
    uint8_t buffer[1500];
    
    struct sockaddr_in destAddr;
    memset(&destAddr, 0, sizeof(destAddr));
    destAddr.sin_family = AF_INET;
    
    const char *ipStr = [_targetHost UTF8String];
    if (!ipStr || strlen(ipStr) == 0 || [_targetHost isEqualToString:@"random"]) {
        // Random target IP address
        destAddr.sin_addr.s_addr = arc4random();
    } else {
        inet_pton(AF_INET, ipStr, &destAddr.sin_addr);
    }
    
    NSUInteger burst = MAX(_burstCount, 1);
    for (NSUInteger i = 0; i < burst; i++) {
        // Generate random bytes payload
        arc4random_buf(buffer, size);
        
        // Randomize destination port if set to 0
        uint16_t port = _targetPort > 0 ? _targetPort : (uint16_t)(1024 + arc4random_uniform(64511));
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
    
    if ([self.delegate respondsToSelector:@selector(packetEngineDidUpdateStatsWithPackets:bytes:packetsSec:bytesSec:)]) {
        [self.delegate packetEngineDidUpdateStatsWithPackets:(NSUInteger)_totalPacketsSent
                                                      bytes:(NSUInteger)_totalBytesSent
                                                packetsSec:pps
                                                   bytesSec:bps];
    }
}

- (void)dealloc {
    [self stop];
}

@end
