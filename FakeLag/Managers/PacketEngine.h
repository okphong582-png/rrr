#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PacketEngineDelegate <NSObject>
@optional
- (void)packetEngineDidUpdateStatsWithPackets:(NSUInteger)totalPackets
                                        bytes:(NSUInteger)totalBytes
                                  packetsSec:(NSUInteger)pps
                                     bytesSec:(NSUInteger)bps;
- (void)packetEngineStateChanged:(BOOL)isRunning;
@end

@interface PacketEngine : NSObject

@property (nonatomic, weak) id<PacketEngineDelegate> delegate;
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, assign) NSUInteger packetSize;        // Bytes per packet (default 1024)
@property (nonatomic, assign) NSUInteger packetsPerSecond;   // Desired PPS (default 1000)
@property (nonatomic, assign) NSUInteger burstCount;         // Packets per burst (default 20)
@property (nonatomic, copy) NSString *targetHost;          // Target IP (default 127.0.0.1 / random)
@property (nonatomic, assign) uint16_t targetPort;          // Target Port (default 0 for random)

+ (instancetype)sharedEngine;

- (void)start;
- (void)stop;
- (void)toggle;

@end

NS_ASSUME_NONNULL_END
