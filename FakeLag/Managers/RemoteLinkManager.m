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
static NSString * const kPrefKeyHUDScale      = @"Remote_HUD_Scale";

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
        
        _hudScale = 1.0;
        
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

- (void)writeSharedDict:(NSDictionary *)dict {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:nil];
    if (data) {
        [data writeToFile:kSharedPlistPath1 atomically:YES];
        chmod([kSharedPlistPath1 UTF8String], 0666);
        
        [data writeToFile:kSharedPlistPath2 atomically:YES];
        chmod([kSharedPlistPath2 UTF8String], 0666);
    }
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
    
    if (valForKey(kPrefKeyHUDScale) != nil) {
        self.hudScale = [valForKey(kPrefKeyHUDScale) doubleValue];
        if (self.hudScale < 0.6 || self.hudScale > 2.0) self.hudScale = 1.0;
    } else {
        self.hudScale = 1.0;
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
    dict[kPrefKeyHUDScale]       = @(self.hudScale);
    
    [self writeSharedDict:dict];
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    for (NSString *key in dict) {
        [ud setObject:dict[key] forKey:key];
    }
    [ud synchronize];
    
    notify_post("com.fakelag.remotestatechanged");
}

- (RemoteFeatureConfig *)configForType:(RemoteFeatureType)type {
    switch (type) {
        case RemoteFeatureFakeLag: return self.fakeLagConfig;
        case RemoteFeatureTeleKill: return self.teleKillConfig;
        case RemoteFeatureGhost: return self.ghostConfig;
    }
}

- (void)applyBaseUrlToAllFeatures:(NSString *)baseUrl {
    if (!baseUrl || baseUrl.length == 0) return;
    
    NSString *clean = [baseUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([clean hasSuffix:@"/"]) {
        clean = [clean substringToIndex:clean.length - 1];
    }
    
    self.serverBaseUrl = clean;
    self.fakeLagConfig.urlOn  = [NSString stringWithFormat:@"%@/freeze", clean];
    self.fakeLagConfig.urlOff = [NSString stringWithFormat:@"%@/off", clean];
    
    self.teleKillConfig.urlOn  = [NSString stringWithFormat:@"%@/tele", clean];
    self.teleKillConfig.urlOff = [NSString stringWithFormat:@"%@/off", clean];
    
    self.ghostConfig.urlOn  = [NSString stringWithFormat:@"%@/ghost", clean];
    self.ghostConfig.urlOff = [NSString stringWithFormat:@"%@/off", clean];
    
    [self saveAllConfigs];
}

- (void)setFeature:(RemoteFeatureType)type active:(BOOL)active completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion {
    RemoteFeatureConfig *config = [self configForType:type];
    config.isActive = active;
    [self saveAllConfigs];
    
    NSString *targetUrl = active ? config.urlOn : config.urlOff;
    
    [self executeGetUrl:targetUrl completion:^(BOOL success, NSString * _Nullable responseText, NSInteger statusCode) {
        config.lastResponse = responseText;
        config.lastStatusCode = statusCode;
        config.lastExecuted = [NSDate date];
        
        if (success) {
            AudioServicesPlaySystemSound(1519); // Peek feedback
        } else {
            AudioServicesPlaySystemSound(1521); // Error feedback
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RemoteLinkStateChangedNotification object:nil];
            if (completion) completion(success, responseText, statusCode);
        });
    }];
}

- (void)toggleFeature:(RemoteFeatureType)type completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion {
    RemoteFeatureConfig *config = [self configForType:type];
    [self setFeature:type active:!config.isActive completion:completion];
}

- (void)turnOffAllFeaturesWithCompletion:(void(^ _Nullable)(BOOL success))completion {
    self.fakeLagConfig.isActive = NO;
    self.teleKillConfig.isActive = NO;
    self.ghostConfig.isActive = NO;
    [self saveAllConfigs];
    
    NSString *offUrl = [NSString stringWithFormat:@"%@/off", self.serverBaseUrl ?: @"http://127.0.0.1:20000"];
    
    [self executeGetUrl:offUrl completion:^(BOOL success, NSString * _Nullable responseText, NSInteger statusCode) {
        AudioServicesPlaySystemSound(1520);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RemoteLinkStateChangedNotification object:nil];
            if (completion) completion(success);
        });
    }];
}

- (void)executeGetUrl:(NSString *)urlString completion:(void(^ _Nullable)(BOOL success, NSString * _Nullable responseText, NSInteger statusCode))completion {
    if (!urlString || urlString.length == 0) {
        if (self.logHandler) self.logHandler(@"[ERR] URL trống, vui lòng cài đặt link!");
        if (completion) completion(NO, @"URL Empty", 0);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (self.logHandler) self.logHandler([NSString stringWithFormat:@"[ERR] URL không hợp lệ: %@", urlString]);
        if (completion) completion(NO, @"Invalid URL", 0);
        return;
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"GET";
    [req setValue:@"FakeLag-VIP/2.0" forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    
    if (self.logHandler) {
        self.logHandler([NSString stringWithFormat:@"[GET] Đang gửi: %@", urlString]);
    }
    
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSInteger statusCode = 0;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            statusCode = [(NSHTTPURLResponse *)response statusCode];
        }
        
        if (error) {
            NSString *errLog = [NSString stringWithFormat:@"[FAIL] Lỗi: %@ (%ld)", error.localizedDescription, (long)statusCode];
            if (self.logHandler) self.logHandler(errLog);
            if (completion) completion(NO, error.localizedDescription, statusCode);
            return;
        }
        
        NSString *respText = @"";
        if (data) {
            respText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        }
        
        NSString *succLog = [NSString stringWithFormat:@"[OK %ld] Phản hồi: %@", (long)statusCode, respText.length > 60 ? [respText substringToIndex:60] : respText];
        if (self.logHandler) self.logHandler(succLog);
        
        BOOL isHttpSuccess = (statusCode >= 200 && statusCode < 300);
        if (completion) completion(isHttpSuccess, respText, statusCode);
    }];
    
    [task resume];
}

@end
