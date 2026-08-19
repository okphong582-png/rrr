#import "RemoteLinkManager.h"
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>

NSString * const RemoteLinkStateChangedNotification = @"com.fakelag.remotestatechanged";

static NSString * const kPrefKeyServerBaseUrl = @"Remote_ServerBaseUrl";
static NSString * const kPrefKeyFakeLagOn     = @"Remote_FakeLag_UrlOn";
static NSString * const kPrefKeyFakeLagOff    = @"Remote_FakeLag_UrlOff";
static NSString * const kPrefKeyTeleKillOn    = @"Remote_TeleKill_UrlOn";
static NSString * const kPrefKeyTeleKillOff   = @"Remote_TeleKill_UrlOff";
static NSString * const kPrefKeyGhostOn       = @"Remote_Ghost_UrlOn";
static NSString * const kPrefKeyGhostOff      = @"Remote_Ghost_UrlOff";

@implementation RemoteFeatureConfig
@end

@interface RemoteLinkManager ()

@property (nonatomic, strong, readwrite) RemoteFeatureConfig *fakeLagConfig;
@property (nonatomic, strong, readwrite) RemoteFeatureConfig *teleKillConfig;
@property (nonatomic, strong, readwrite) RemoteFeatureConfig *ghostConfig;
@property (nonatomic, strong) NSURLSession *urlSession;

@end

@implementation RemoteLinkManager

+ (instancetype)sharedManager {
    static RemoteLinkManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RemoteLinkManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 4.0;
        config.timeoutIntervalForResource = 6.0;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
        _urlSession = [NSURLSession sessionWithConfiguration:config];
        
        _fakeLagConfig = [[RemoteFeatureConfig alloc] init];
        _fakeLagConfig.type = RemoteFeatureFakeLag;
        _fakeLagConfig.name = @"FakeLag (Freeze)";
        _fakeLagConfig.icon = @"🧊";
        
        _teleKillConfig = [[RemoteFeatureConfig alloc] init];
        _teleKillConfig.type = RemoteFeatureTeleKill;
        _teleKillConfig.name = @"TeleKill";
        _teleKillConfig.icon = @"⚡";
        
        _ghostConfig = [[RemoteFeatureConfig alloc] init];
        _ghostConfig.type = RemoteFeatureGhost;
        _ghostConfig.name = @"Ghost Lag";
        _ghostConfig.icon = @"👻";
        
        [self loadAllConfigs];
    }
    return self;
}

- (RemoteFeatureConfig *)configForType:(RemoteFeatureType)type {
    switch (type) {
        case RemoteFeatureFakeLag: return self.fakeLagConfig;
        case RemoteFeatureTeleKill: return self.teleKillConfig;
        case RemoteFeatureGhost: return self.ghostConfig;
    }
}

- (void)loadAllConfigs {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    self.serverBaseUrl = [ud stringForKey:kPrefKeyServerBaseUrl] ?: @"http://127.0.0.1:20000";
    
    self.fakeLagConfig.urlOn = [ud stringForKey:kPrefKeyFakeLagOn] ?: [NSString stringWithFormat:@"%@/freeze", self.serverBaseUrl];
    self.fakeLagConfig.urlOff = [ud stringForKey:kPrefKeyFakeLagOff] ?: [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
    
    self.teleKillConfig.urlOn = [ud stringForKey:kPrefKeyTeleKillOn] ?: [NSString stringWithFormat:@"%@/tele", self.serverBaseUrl];
    self.teleKillConfig.urlOff = [ud stringForKey:kPrefKeyTeleKillOff] ?: [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
    
    self.ghostConfig.urlOn = [ud stringForKey:kPrefKeyGhostOn] ?: [NSString stringWithFormat:@"%@/ghost", self.serverBaseUrl];
    self.ghostConfig.urlOff = [ud stringForKey:kPrefKeyGhostOff] ?: [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
}

- (void)saveConfig:(RemoteFeatureConfig *)config {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    switch (config.type) {
        case RemoteFeatureFakeLag:
            [ud setObject:config.urlOn forKey:kPrefKeyFakeLagOn];
            [ud setObject:config.urlOff forKey:kPrefKeyFakeLagOff];
            break;
        case RemoteFeatureTeleKill:
            [ud setObject:config.urlOn forKey:kPrefKeyTeleKillOn];
            [ud setObject:config.urlOff forKey:kPrefKeyTeleKillOff];
            break;
        case RemoteFeatureGhost:
            [ud setObject:config.urlOn forKey:kPrefKeyGhostOn];
            [ud setObject:config.urlOff forKey:kPrefKeyGhostOff];
            break;
    }
    [ud synchronize];
}

- (void)saveAllConfigs {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:self.serverBaseUrl forKey:kPrefKeyServerBaseUrl];
    [self saveConfig:self.fakeLagConfig];
    [self saveConfig:self.teleKillConfig];
    [self saveConfig:self.ghostConfig];
    [ud synchronize];
}

- (void)applyBaseUrlToAllFeatures:(NSString *)baseUrl {
    NSString *cleanUrl = [baseUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([cleanUrl hasSuffix:@"/"]) {
        cleanUrl = [cleanUrl substringToIndex:cleanUrl.length - 1];
    }
    self.serverBaseUrl = cleanUrl;
    
    self.fakeLagConfig.urlOn = [NSString stringWithFormat:@"%@/freeze", cleanUrl];
    self.fakeLagConfig.urlOff = [NSString stringWithFormat:@"%@/off", cleanUrl];
    
    self.teleKillConfig.urlOn = [NSString stringWithFormat:@"%@/tele", cleanUrl];
    self.teleKillConfig.urlOff = [NSString stringWithFormat:@"%@/off", cleanUrl];
    
    self.ghostConfig.urlOn = [NSString stringWithFormat:@"%@/ghost", cleanUrl];
    self.ghostConfig.urlOff = [NSString stringWithFormat:@"%@/off", cleanUrl];
    
    [self saveAllConfigs];
}

- (void)setFeature:(RemoteFeatureType)type active:(BOOL)active completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion {
    RemoteFeatureConfig *config = [self configForType:type];
    config.isActive = active;
    
    NSString *targetUrl = active ? config.urlOn : config.urlOff;
    if (!targetUrl || targetUrl.length == 0) {
        targetUrl = active ? [NSString stringWithFormat:@"%@/on", self.serverBaseUrl] : [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
    }
    
    // Rung phản hồi haptic
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:active ? UIImpactFeedbackStyleHeavy : UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
    
    [self executeGetUrl:targetUrl completion:^(BOOL success, NSString * _Nullable responseText, NSInteger statusCode) {
        config.lastResponse = responseText;
        config.lastStatusCode = statusCode;
        config.lastExecuted = [NSDate date];
        
        [self notifyChange];
        
        if (completion) {
            completion(success, responseText, statusCode);
        }
    }];
}

- (void)toggleFeature:(RemoteFeatureType)type completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion {
    RemoteFeatureConfig *config = [self configForType:type];
    BOOL nextState = !config.isActive;
    [self setFeature:type active:nextState completion:completion];
}

- (void)turnOffAllFeaturesWithCompletion:(void(^ _Nullable)(BOOL success))completion {
    self.fakeLagConfig.isActive = NO;
    self.teleKillConfig.isActive = NO;
    self.ghostConfig.isActive = NO;
    
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleRigid];
    [haptic impactOccurred];
    
    NSString *offUrl = [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
    [self executeGetUrl:offUrl completion:^(BOOL success, NSString * _Nullable responseText, NSInteger statusCode) {
        self.fakeLagConfig.lastResponse = responseText;
        self.teleKillConfig.lastResponse = responseText;
        self.ghostConfig.lastResponse = responseText;
        
        [self notifyChange];
        
        if (completion) {
            completion(success);
        }
    }];
}

// === THỰC THI HTTP GET NHƯ TÍNH NĂNG "LẤY NỘI DUNG URL" CỦA IOS ===
- (void)executeGetUrl:(NSString *)urlString completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion {
    if (!urlString || urlString.length == 0) {
        if (completion) completion(NO, @"URL rỗng", 0);
        return;
    }
    
    NSString *trimmed = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![trimmed hasPrefix:@"http://"] && ![trimmed hasPrefix:@"https://"]) {
        trimmed = [@"http://" stringByAppendingString:trimmed];
    }
    
    NSURL *url = [NSURL URLWithString:trimmed];
    if (!url) {
        if (completion) completion(NO, @"URL không hợp lệ", 0);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSInteger statusCode = 0;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            statusCode = ((NSHTTPURLResponse *)response).statusCode;
        }
        
        NSString *respStr = @"";
        if (data) {
            respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        }
        
        BOOL isSuccess = (!error && (statusCode >= 200 && statusCode < 400));
        NSString *logMsg = [NSString stringWithFormat:@"[%@] GET %@ -> Status: %ld %@",
                            isSuccess ? @"OK" : @"ERR",
                            trimmed,
                            (long)statusCode,
                            error ? error.localizedDescription : (respStr.length > 50 ? [respStr substringToIndex:50] : respStr)];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.logHandler) {
                weakSelf.logHandler(logMsg);
            }
            if (completion) {
                completion(isSuccess, isSuccess ? respStr : (error.localizedDescription ?: @"Lỗi kết nối"), statusCode);
            }
        });
    }];
    
    [task resume];
}

- (void)notifyChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        notify_post("com.fakelag.remotestatechanged");
        [[NSNotificationCenter defaultCenter] postNotificationName:RemoteLinkStateChangedNotification object:self];
    });
}

@end
