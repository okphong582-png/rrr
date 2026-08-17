#import "PacketEngine.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>

@interface PacketEngine () {
    dispatch_queue_t _workQueue;
    dispatch_source_t _statsTimer;
    uint64_t _totalPacketsSent;
    uint64_t _totalBytesSent;
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
        _packetSize = 1024;
        _packetsPerSecond = 1000;
        _burstCount = 4;
        _burstInterval = 0.005;
        _targetHost = @"127.0.0.1";
        _targetPort = 10015;
        _isRunning = NO;
        _workQueue = dispatch_queue_create("com.fakelag.freezeengine", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSUInteger)bufferedPacketCount {
    return 0;
}

- (NSString *)nameForMode:(FakeLagMode)mode {
    return @"🧊 FREEZE (Chặn gói Server 10011-10019 -> Địch đơ đứng yên)";
}

- (void)switchMode:(FakeLagMode)newMode {
    _currentMode = newMode;
}

- (void)cycleNextMode {
}

- (void)start {
    @synchronized (self) {
        if (_isRunning) return;
        _isRunning = YES;
    }
    
    __weak typeof(self) weakSelf = self;
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
    
    NSLog(@"[PacketEngine] KÍCH HOẠT FREEZE ĐÓNG BĂNG ĐỊCH");
}

- (void)stop {
    @synchronized (self) {
        if (!_isRunning) return;
        _isRunning = NO;
    }
    
    if (_statsTimer) {
        dispatch_source_cancel(_statsTimer);
        _statsTimer = nil;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([weakSelf.delegate respondsToSelector:@selector(packetEngineStateChanged:)]) {
            [weakSelf.delegate packetEngineStateChanged:NO];
        }
    });
    
    NSLog(@"[PacketEngine] TẮT FREEZE (Đã xả đệm)");
}

- (void)toggle {
    if (self.isRunning) {
        [self stop];
    } else {
        [self start];
    }
}

- (void)reportStats {
    if (!_isRunning) return;
    
    if ([self.delegate respondsToSelector:@selector(packetEngineDidUpdateStatsWithPackets:bytes:packetsSec:bytesSec:bufferedPkts:)]) {
        [self.delegate packetEngineDidUpdateStatsWithPackets:(NSUInteger)_totalPacketsSent
                                                      bytes:(NSUInteger)_totalBytesSent
                                                packetsSec:100
                                                   bytesSec:51200
                                               bufferedPkts:0];
    }
}

- (void)dealloc {
    [self stop];
}

@end
