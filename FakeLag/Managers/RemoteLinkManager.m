#import "RemoteLinkManager.h"
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>
#import <sys/stat.h>

NSString * const RemoteLinkStateChangedNotification = @"com.fakelag.remotestatechanged";

static NSString * const kSharedPlistPath1 = @"/var/mobile/Library/Preferences/com.fakelag.shared.plist";
static NSString * const kSharedPlistPath2 = @"/tmp/fakelag_shared_config.plist";

static NSString * const kPrefKeyServerBaseUrl = @"Remote_ServerBaseUrl";
static NSString * const kPrefKeyFakeLagOn     = @"Remote_FakeLag_UrlOn";
static NSString * const kPrefKeyFakeLagOff    = @"Remote_FakeLag_UrlOff";
static NSString * const kPrefKeyTeleKillOn    = @"Remote_TeleKill_UrlOn";
static NSString * const kPrefKeyTeleKillOff   = @"Remote_TeleKill_UrlOff";
static NSString * const kPrefKeyGhostOn       = @"Remote_Ghost_UrlOn";
static NSString * const kPrefKeyGhostOff      = @"Remote_Ghost_UrlOff";

static NSString * const kPrefKeyFakeLagActive = @"Remote_FakeLag_IsActive";
static NSString * const kPrefKeyTeleKillActive= @"Remote_TeleKill_IsActive";
static NSString * const kPrefKeyGhostActive   = @"Remote_Ghost_IsActive";

static NSString * const kPrefKeyShowFakeLag   = @"Remote_Show_FakeLag";
static NSString * const kPrefKeyShowTeleKill  = @"Remote_Show_TeleKill";
static NSString * const kPrefKeyShowGhost     = @"Remote_Show_Ghost";

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
        _fakeLagConfig.isVisibleInHUD = YES;
        
        _teleKillConfig = [[RemoteFeatureConfig alloc] init];
        _teleKillConfig.type = RemoteFeatureTeleKill;
        _teleKillConfig.name = @"TeleKill";
        _teleKillConfig.icon = @"⚡";
        _teleKillConfig.isVisibleInHUD = YES;
        
        _ghostConfig = [[RemoteFeatureConfig alloc] init];
        _ghostConfig.type = RemoteFeatureGhost;
        _ghostConfig.name = @"Ghost Lag";
        _ghostConfig.icon = @"👻";
        _ghostConfig.isVisibleInHUD = YES;
        
        _showFakeLagInHUD = YES;
        _showTeleKillInHUD = YES;
        _showGhostInHUD = YES;
        
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

- (void)setShowFakeLagInHUD:(BOOL)showFakeLagInHUD {
    _showFakeLagInHUD = showFakeLagInHUD;
    self.fakeLagConfig.isVisibleInHUD = showFakeLagInHUD;
}

- (void)setShowTeleKillInHUD:(BOOL)showTeleKillInHUD {
    _showTeleKillInHUD = showTeleKillInHUD;
    self.teleKillConfig.isVisibleInHUD = showTeleKillInHUD;
}

- (void)setShowGhostInHUD:(BOOL)showGhostInHUD {
    _showGhostInHUD = showGhostInHUD;
    self.ghostConfig.isVisibleInHUD = showGhostInHUD;
}

- (NSDictionary *)readSharedDict {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kSharedPlistPath1];
    if (!dict) {
        dict = [NSDictionary dictionaryWithContentsOfFile:kSharedPlistPath2];
    }
    return dict;
}

- (void)loadAllConfigs {
    NSDictionary *sharedDict = [self readSharedDict];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    id (^valForKey)(NSString *) = ^id(NSString *k) {
        if (sharedDict && sharedDict[k] != nil) return sharedDict[k];
        return [ud objectForKey:k];
    };
    
    self.serverBaseUrl = valForKey(kPrefKeyServerBaseUrl) ?: @"http://127.0.0.1:20000";
    
    self.fakeLagConfig.urlOn = valForKey(kPrefKeyFakeLagOn) ?: [NSString stringWithFormat:@"%@/freeze", self.serverBaseUrl];
    self.fakeLagConfig.urlOff = valForKey(kPrefKeyFakeLagOff) ?: [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
    if (valForKey(kPrefKeyFakeLagActive) != nil) {
        self.fakeLagConfig.isActive = [valForKey(kPrefKeyFakeLagActive) boolValue];
    }
    if (valForKey(kPrefKeyShowFakeLag) != nil) {
        self.showFakeLagInHUD = [valForKey(kPrefKeyShowFakeLag) boolValue];
    } else {
        self.showFakeLagInHUD = YES;
    }
    
    self.teleKillConfig.urlOn = valForKey(kPrefKeyTeleKillOn) ?: [NSString stringWithFormat:@"%@/tele", self.serverBaseUrl];
    self.teleKillConfig.urlOff = valForKey(kPrefKeyTeleKillOff) ?: [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
    if (valForKey(kPrefKeyTeleKillActive) != nil) {
        self.teleKillConfig.isActive = [valForKey(kPrefKeyTeleKillActive) boolValue];
    }
    if (valForKey(kPrefKeyShowTeleKill) != nil) {
        self.showTeleKillInHUD = [valForKey(kPrefKeyShowTeleKill) boolValue];
    } else {
        self.showTeleKillInHUD = YES;
    }
    
    self.ghostConfig.urlOn = valForKey(kPrefKeyGhostOn) ?: [NSString stringWithFormat:@"%@/ghost", self.serverBaseUrl];
    self.ghostConfig.urlOff = valForKey(kPrefKeyGhostOff) ?: [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
    if (valForKey(kPrefKeyGhostActive) != nil) {
        self.ghostConfig.isActive = [valForKey(kPrefKeyGhostActive) boolValue];
    }
    if (valForKey(kPrefKeyShowGhost) != nil) {
        self.showGhostInHUD = [valForKey(kPrefKeyShowGhost) boolValue];
    } else {
        self.showGhostInHUD = YES;
    }
}

- (void)saveConfig:(RemoteFeatureConfig *)config {
    [self saveAllConfigs];
}

- (void)saveAllConfigs {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[kPrefKeyServerBaseUrl] = self.serverBaseUrl ?: @"";
    
    dict[kPrefKeyFakeLagOn]      = self.fakeLagConfig.urlOn ?: @"";
    dict[kPrefKeyFakeLagOff]     = self.fakeLagConfig.urlOff ?: @"";
    dict[kPrefKeyFakeLagActive]  = @(self.fakeLagConfig.isActive);
    dict[kPrefKeyShowFakeLag]    = @(self.showFakeLagInHUD);
    
    dict[kPrefKeyTeleKillOn]     = self.teleKillConfig.urlOn ?: @"";
    dict[kPrefKeyTeleKillOff]    = self.teleKillConfig.urlOff ?: @"";
    dict[kPrefKeyTeleKillActive] = @(self.teleKillConfig.isActive);
    dict[kPrefKeyShowTeleKill]   = @(self.showTeleKillInHUD);
    
    dict[kPrefKeyGhostOn]        = self.ghostConfig.urlOn ?: @"";
    dict[kPrefKeyGhostOff]       = self.ghostConfig.urlOff ?: @"";
    dict[kPrefKeyGhostActive]    = @(self.ghostConfig.isActive);
    dict[kPrefKeyShowGhost]      = @(self.showGhostInHUD);
    
    // Ghi vào file chia sẻ chung giữa FakeLag và Daemon FakeLagHUD
    [dict writeToFile:kSharedPlistPath1 atomically:YES];
    chmod([kSharedPlistPath1 UTF8String], 0666);
    
    [dict writeToFile:kSharedPlistPath2 atomically:YES];
    chmod([kSharedPlistPath2 UTF8String], 0666);
    
    // Sync vào NSUserDefaults
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    for (NSString *key in dict) {
        [ud setObject:dict[key] forKey:key];
    }
    [ud synchronize];
    
    [self notifyChange];
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
    // Luôn load cấu hình mới nhất trước khi gọi để đảm bảo URL chính xác
    [self loadAllConfigs];
    
    RemoteFeatureConfig *config = [self configForType:type];
    config.isActive = active;
    
    NSString *targetUrl = active ? config.urlOn : config.urlOff;
    if (!targetUrl || targetUrl.length == 0) {
        targetUrl = active ? [NSString stringWithFormat:@"%@/on", self.serverBaseUrl] : [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
    }
    
    // Lưu trạng thái ngay lập tức và phát thông báo đồng bộ 2 chiều
    [self saveAllConfigs];
    
    // Rung phản hồi haptic
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:active ? UIImpactFeedbackStyleHeavy : UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
    
    [self executeGetUrl:targetUrl completion:^(BOOL success, NSString * _Nullable responseText, NSInteger statusCode) {
        config.lastResponse = responseText;
        config.lastStatusCode = statusCode;
        config.lastExecuted = [NSDate date];
        
        [self saveAllConfigs];
        
        if (completion) {
            completion(success, responseText, statusCode);
        }
    }];
}

- (void)toggleFeature:(RemoteFeatureType)type completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion {
    [self loadAllConfigs];
    RemoteFeatureConfig *config = [self configForType:type];
    BOOL nextState = !config.isActive;
    [self setFeature:type active:nextState completion:completion];
}

- (void)turnOffAllFeaturesWithCompletion:(void(^ _Nullable)(BOOL success))completion {
    [self loadAllConfigs];
    self.fakeLagConfig.isActive = NO;
    self.teleKillConfig.isActive = NO;
    self.ghostConfig.isActive = NO;
    [self saveAllConfigs];
    
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleRigid];
    [haptic impactOccurred];
    
    NSString *offUrl = [NSString stringWithFormat:@"%@/off", self.serverBaseUrl];
    [self executeGetUrl:offUrl completion:^(BOOL success, NSString * _Nullable responseText, NSInteger statusCode) {
        self.fakeLagConfig.lastResponse = responseText;
        self.teleKillConfig.lastResponse = responseText;
        self.ghostConfig.lastResponse = responseText;
        
        [self saveAllConfigs];
        
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
