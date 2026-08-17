#import "PacketTunnelProvider.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@interface PacketTunnelProvider () {
    BOOL _isTunnelRunning;
    dispatch_queue_t _tunnelQueue;
    dispatch_source_t _packetFloodTimer;
}
@end

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    _isTunnelRunning = YES;
    _tunnelQueue = dispatch_queue_create("com.fakelag.tunnelqueue", DISPATCH_QUEUE_SERIAL);
    
    // Configure virtual network settings
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"127.0.0.1"];
    
    // IPv4 Settings
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"10.99.0.2"]
                                                                 subnetMasks:@[@"255.255.255.0"]];
    // Include route for loopback / simulated subnet
    NEIPv4Route *route = [[NEIPv4Route alloc] initWithDestinationAddress:@"10.99.0.0"
                                                              subnetMask:@"255.255.255.0"];
    ipv4Settings.includedRoutes = @[route];
    settings.IPv4Settings = ipv4Settings;
    
    // DNS Settings
    NEDNSSettings *dnsSettings = [[NEDNSSettings alloc] initWithServers:@[@"1.1.1.1", @"8.8.8.8"]];
    settings.DNSSettings = dnsSettings;
    settings.MTU = @(1400);
    
    __weak typeof(self) weakSelf = self;
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[FakeLagTunnel] Failed to set network settings: %@", error.localizedDescription);
            if (completionHandler) completionHandler(error);
            return;
        }
        
        // Start packet processing and background random packet generator
        [weakSelf startPacketFlowReading];
        [weakSelf startRandomPacketFlood];
        
        if (completionHandler) completionHandler(nil);
    }];
}

- (void)startPacketFlowReading {
    if (!_isTunnelRunning) return;
    
    __weak typeof(self) weakSelf = self;
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        if (!weakSelf || !weakSelf->_isTunnelRunning) return;
        
        // Process packets and continue reading loop
        [weakSelf startPacketFlowReading];
    }];
}

- (void)startRandomPacketFlood {
    _packetFloodTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _tunnelQueue);
    // Fire every 5ms (200 times per second)
    dispatch_source_set_timer(_packetFloodTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 5000000ULL, 1000000ULL);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_packetFloodTimer, ^{
        [weakSelf sendSimulatedRandomPackets];
    });
    dispatch_resume(_packetFloodTimer);
}

- (void)sendSimulatedRandomPackets {
    if (!_isTunnelRunning) return;
    
    // Generate dummy IP packets with random payload
    NSMutableArray<NSData *> *dummyPackets = [NSMutableArray arrayWithCapacity:5];
    NSMutableArray<NSNumber *> *protocols = [NSMutableArray arrayWithCapacity:5];
    
    uint8_t rawBuffer[512];
    for (int i = 0; i < 5; i++) {
        arc4random_buf(rawBuffer, sizeof(rawBuffer));
        // Set IPv4 version and header length
        rawBuffer[0] = 0x45;
        // Protocol UDP
        rawBuffer[9] = 17;
        
        NSData *packetData = [NSData dataWithBytes:rawBuffer length:sizeof(rawBuffer)];
        [dummyPackets addObject:packetData];
        [protocols addObject:@(AF_INET)];
    }
    
    [self.packetFlow writePackets:dummyPackets withProtocols:protocols];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    _isTunnelRunning = NO;
    if (_packetFloodTimer) {
        dispatch_source_cancel(_packetFloodTimer);
        _packetFloodTimer = nil;
    }
    if (completionHandler) {
        completionHandler();
    }
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    if (completionHandler) {
        completionHandler([@"OK" dataUsingEncoding:NSUTF8StringEncoding]);
    }
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    if (completionHandler) {
        completionHandler();
    }
}

- (void)wake {
}

@end
