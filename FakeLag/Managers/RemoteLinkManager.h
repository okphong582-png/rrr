#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const RemoteLinkStateChangedNotification;

typedef NS_ENUM(NSInteger, RemoteFeatureType) {
    RemoteFeatureFakeLag = 0,   // Freeze / FakeLag
    RemoteFeatureTeleKill = 1,  // TeleKill
    RemoteFeatureGhost = 2      // Ghost Lag
};

@interface RemoteFeatureConfig : NSObject

@property (nonatomic, assign) RemoteFeatureType type;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *icon;
@property (nonatomic, copy) NSString *urlOn;
@property (nonatomic, copy) NSString *urlOff;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, copy, nullable) NSString *lastResponse;
@property (nonatomic, assign) NSInteger lastStatusCode;
@property (nonatomic, copy, nullable) NSDate *lastExecuted;

@end

@interface RemoteLinkManager : NSObject

@property (nonatomic, copy) NSString *serverBaseUrl;
@property (nonatomic, strong, readonly) RemoteFeatureConfig *fakeLagConfig;
@property (nonatomic, strong, readonly) RemoteFeatureConfig *teleKillConfig;
@property (nonatomic, strong, readonly) RemoteFeatureConfig *ghostConfig;
@property (nonatomic, copy) void (^ _Nullable logHandler)(NSString *log);

+ (instancetype)sharedManager;

- (RemoteFeatureConfig *)configForType:(RemoteFeatureType)type;
- (void)saveConfig:(RemoteFeatureConfig *)config;
- (void)saveAllConfigs;
- (void)loadAllConfigs;

// Thực thi GET nội dung URL cho từng tính năng
- (void)setFeature:(RemoteFeatureType)type active:(BOOL)active completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion;
- (void)toggleFeature:(RemoteFeatureType)type completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion;
- (void)turnOffAllFeaturesWithCompletion:(void(^ _Nullable)(BOOL success))completion;

// Áp dụng Server Base URL để tự động sinh 3 link
- (void)applyBaseUrlToAllFeatures:(NSString *)baseUrl;

// Gửi HTTP GET tùy ý
- (void)executeGetUrl:(NSString *)urlString completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion;

@end

NS_ASSUME_NONNULL_END
