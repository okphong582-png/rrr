#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FakeLagMode) {
    FakeLagModeFreeze,     // 🧊 Freeze Địch (Mặc Định): Chặn gói Server Inbound 10011-10019 (30-1079B) làm đối phương đơ đứng yên
    FakeLagModeTeleKill,   // ⚡ TeleKill: Chặn lưu gói di chuyển Port 10010-10020, xả Burst 4 pkts / 5ms
    FakeLagModeGhost,      // 👻 Ghost Lag: Lệch hitbox (Chặn gói đồng bộ 55-300B)
    FakeLagModeFlood       // 💥 Flood Lag: Bắn gói tin ngẫu nhiên dồn dập tạo 999ms ping
};

@protocol PacketEngineDelegate <NSObject>
@optional
- (void)packetEngineDidUpdateStatsWithPackets:(NSUInteger)totalPackets
                                        bytes:(NSUInteger)totalBytes
                                  packetsSec:(NSUInteger)pps
                                     bytesSec:(NSUInteger)bps
                                  bufferedPkts:(NSUInteger)buffered;
- (void)packetEngineStateChanged:(BOOL)isRunning;
- (void)packetEngineModeChanged:(FakeLagMode)mode;
@end

@interface PacketEngine : NSObject

@property (nonatomic, weak) id<PacketEngineDelegate> delegate;
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, assign) FakeLagMode currentMode;

@property (nonatomic, assign) NSUInteger packetSize;
@property (nonatomic, assign) NSUInteger packetsPerSecond;
@property (nonatomic, assign) NSUInteger burstCount;
@property (nonatomic, assign) NSTimeInterval burstInterval;
@property (nonatomic, copy) NSString *targetHost;
@property (nonatomic, assign) uint16_t targetPort;

@property (nonatomic, readonly) NSUInteger bufferedPacketCount;

+ (instancetype)sharedEngine;

- (void)start;
- (void)stop;
- (void)toggle;
- (void)switchMode:(FakeLagMode)newMode;
- (void)cycleNextMode;

- (NSString *)nameForMode:(FakeLagMode)mode;

@end

NS_ASSUME_NONNULL_END
