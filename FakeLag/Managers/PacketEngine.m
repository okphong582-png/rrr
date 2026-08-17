#import "PacketEngine.h"

@interface PacketEngine ()

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
        _isRunning = NO;
    }
    return self;
}

- (NSUInteger)bufferedPacketCount {
    return 0;
}

- (NSString *)nameForMode:(FakeLagMode)mode {
    return @"❄️ Freeze Chu Kỳ (2.0s Drop / 0.5s Thả - Ping Thấp, Địch Đơ)";
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
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([weakSelf.delegate respondsToSelector:@selector(packetEngineStateChanged:)]) {
            [weakSelf.delegate packetEngineStateChanged:YES];
        }
    });
    
    NSLog(@"[PacketEngine] KÍCH HOẠT FREEZE CHU KỲ (2s Drop, 0.5s Thả)");
}

- (void)stop {
    @synchronized (self) {
        if (!_isRunning) return;
        _isRunning = NO;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([weakSelf.delegate respondsToSelector:@selector(packetEngineStateChanged:)]) {
            [weakSelf.delegate packetEngineStateChanged:NO];
        }
    });
    
    NSLog(@"[PacketEngine] TẮT FREEZE CHU KỲ");
}

- (void)toggle {
    if (self.isRunning) {
        [self stop];
    } else {
        [self start];
    }
}

@end
