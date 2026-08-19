#import "SettingsViewController.h"
#import "RemoteLinkManager.h"
#import "HUDLauncher.h"

@interface SettingsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Cài Đặt Link & Menu";
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.10 alpha:1.0];
    
    UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc] initWithTitle:@"Lưu & Xong"
                                                                style:UIBarButtonItemStyleDone
                                                               target:self
                                                               action:@selector(saveAndDismiss)];
    self.navigationItem.rightBarButtonItem = saveBtn;
    
    [self setupTableView];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.10 alpha:1.0];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
}

- (void)saveAndDismiss {
    [[RemoteLinkManager sharedManager] saveAllConfigs];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 6;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2; // Server Base URL & Tự động sinh link
    if (section == 1) return 3; // FakeLag (On, Off, Test)
    if (section == 2) return 3; // TeleKill (On, Off, Test)
    if (section == 3) return 3; // Ghost (On, Off, Test)
    if (section == 4) return 3; // Tùy chọn hiển thị từng tính năng trên menu
    if (section == 5) return 2; // Nút Nổi Overlay & Thông tin
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"🌐 SERVER BASE URL CHUNG";
    if (section == 1) return @"🧊 LINK FAKELAG (FREEZE ĐỊCH)";
    if (section == 2) return @"⚡ LINK TELEKILL (DỊCH CHUYỂN)";
    if (section == 3) return @"👻 LINK GHOST LAG (TÀNG HÌNH)";
    if (section == 4) return @"🎯 CHỌN TÍNH NĂNG HIỆN TRÊN MENU NỔI";
    if (section == 5) return @"🎛️ TÙY CHỈNH NÚT NỔI OVERLAY";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ConfigCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ConfigCell"];
        cell.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.17 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11.5];
        cell.detailTextLabel.numberOfLines = 2;
    }
    cell.accessoryView = nil;
    
    RemoteLinkManager *mgr = [RemoteLinkManager sharedManager];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Server Base URL";
            cell.detailTextLabel.text = mgr.serverBaseUrl ?: @"Chưa nhập (Ví dụ: https://xxx.trycloudflare.com)";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"⚡ Tự Động Áp Dụng Cho 3 Tính Năng";
            cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.85 alpha:1.0];
            cell.detailTextLabel.text = @"Tự điền link /freeze, /tele, /ghost và /off";
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Link Khi BẬT FakeLag (ON)";
            cell.detailTextLabel.text = mgr.fakeLagConfig.urlOn ?: @"Chưa cài đặt";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Link Khi TẮT FakeLag (OFF)";
            cell.detailTextLabel.text = mgr.fakeLagConfig.urlOff ?: @"Chưa cài đặt";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"▶ Test Thử Link FakeLag";
            cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.75 blue:1.0 alpha:1.0];
            cell.detailTextLabel.text = @"Gửi thử GET request kiểm tra phản hồi";
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Link Khi BẬT TeleKill (ON)";
            cell.detailTextLabel.text = mgr.teleKillConfig.urlOn ?: @"Chưa cài đặt";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Link Khi TẮT TeleKill (OFF)";
            cell.detailTextLabel.text = mgr.teleKillConfig.urlOff ?: @"Chưa cài đặt";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"▶ Test Thử Link TeleKill";
            cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.45 blue:0.1 alpha:1.0];
            cell.detailTextLabel.text = @"Gửi thử GET request kiểm tra phản hồi";
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Link Khi BẬT Ghost (ON)";
            cell.detailTextLabel.text = mgr.ghostConfig.urlOn ?: @"Chưa cài đặt";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Link Khi TẮT Ghost (OFF)";
            cell.detailTextLabel.text = mgr.ghostConfig.urlOff ?: @"Chưa cài đặt";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"▶ Test Thử Link Ghost";
            cell.textLabel.textColor = [UIColor colorWithRed:0.75 green:0.45 blue:1.0 alpha:1.0];
            cell.detailTextLabel.text = @"Gửi thử GET request kiểm tra phản hồi";
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if (indexPath.section == 4) {
        // Section 4: Chọn tính năng hiển thị trên menu nổi
        UISwitch *visSwitch = [[UISwitch alloc] init];
        visSwitch.onTintColor = [UIColor colorWithRed:0.0 green:0.80 blue:0.45 alpha:1.0];
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"🧊 Hiện FakeLag (Freeze)";
            cell.detailTextLabel.text = @"Bật/tắt hiển thị dòng FakeLag trên Menu Nổi";
            visSwitch.on = mgr.showFakeLagInHUD;
            [visSwitch addTarget:self action:@selector(toggleShowFakeLag:) forControlEvents:UIControlEventValueChanged];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"⚡ Hiện TeleKill";
            cell.detailTextLabel.text = @"Bật/tắt hiển thị dòng TeleKill trên Menu Nổi";
            visSwitch.on = mgr.showTeleKillInHUD;
            [visSwitch addTarget:self action:@selector(toggleShowTeleKill:) forControlEvents:UIControlEventValueChanged];
        } else {
            cell.textLabel.text = @"👻 Hiện Ghost Lag";
            cell.detailTextLabel.text = @"Bật/tắt hiển thị dòng Ghost trên Menu Nổi";
            visSwitch.on = mgr.showGhostInHUD;
            [visSwitch addTarget:self action:@selector(toggleShowGhost:) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = visSwitch;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else if (indexPath.section == 5) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Đặt Lại Vị Trí Nút Nổi";
            cell.detailTextLabel.text = @"Đưa về vị trí mặc định ở góc màn hình";
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            cell.textLabel.text = @"Cơ Chế Hoạt Động";
            cell.detailTextLabel.text = @"GET nội dung URL • Đồng bộ 2 chiều liên tiến trình 100%";
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    return cell;
}

- (void)toggleShowFakeLag:(UISwitch *)sender {
    [RemoteLinkManager sharedManager].showFakeLagInHUD = sender.isOn;
    [[RemoteLinkManager sharedManager] saveAllConfigs];
}

- (void)toggleShowTeleKill:(UISwitch *)sender {
    [RemoteLinkManager sharedManager].showTeleKillInHUD = sender.isOn;
    [[RemoteLinkManager sharedManager] saveAllConfigs];
}

- (void)toggleShowGhost:(UISwitch *)sender {
    [RemoteLinkManager sharedManager].showGhostInHUD = sender.isOn;
    [[RemoteLinkManager sharedManager] saveAllConfigs];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RemoteLinkManager *mgr = [RemoteLinkManager sharedManager];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [self editStringValue:mgr.serverBaseUrl title:@"Server Base URL" message:@"Nhập địa chỉ URL của Server (ví dụ https://abc.trycloudflare.com)" completion:^(NSString *newVal) {
                mgr.serverBaseUrl = newVal;
                [mgr saveAllConfigs];
                [self.tableView reloadData];
            }];
        } else {
            [mgr applyBaseUrlToAllFeatures:mgr.serverBaseUrl];
            [self showToast:@"Đã tự động tạo và lưu 3 Link thành công!"];
            [self.tableView reloadData];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [self editStringValue:mgr.fakeLagConfig.urlOn title:@"Link BẬT FakeLag" message:@"Nhập URL khi gạt BẬT FakeLag" completion:^(NSString *newVal) {
                mgr.fakeLagConfig.urlOn = newVal;
                [mgr saveConfig:mgr.fakeLagConfig];
                [self.tableView reloadData];
            }];
        } else if (indexPath.row == 1) {
            [self editStringValue:mgr.fakeLagConfig.urlOff title:@"Link TẮT FakeLag" message:@"Nhập URL khi gạt TẮT FakeLag" completion:^(NSString *newVal) {
                mgr.fakeLagConfig.urlOff = newVal;
                [mgr saveConfig:mgr.fakeLagConfig];
                [self.tableView reloadData];
            }];
        } else {
            [self testFeatureUrl:RemoteFeatureFakeLag];
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            [self editStringValue:mgr.teleKillConfig.urlOn title:@"Link BẬT TeleKill" message:@"Nhập URL khi gạt BẬT TeleKill" completion:^(NSString *newVal) {
                mgr.teleKillConfig.urlOn = newVal;
                [mgr saveConfig:mgr.teleKillConfig];
                [self.tableView reloadData];
            }];
        } else if (indexPath.row == 1) {
            [self editStringValue:mgr.teleKillConfig.urlOff title:@"Link TẮT TeleKill" message:@"Nhập URL khi gạt TẮT TeleKill" completion:^(NSString *newVal) {
                mgr.teleKillConfig.urlOff = newVal;
                [mgr saveConfig:mgr.teleKillConfig];
                [self.tableView reloadData];
            }];
        } else {
            [self testFeatureUrl:RemoteFeatureTeleKill];
        }
    } else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            [self editStringValue:mgr.ghostConfig.urlOn title:@"Link BẬT Ghost" message:@"Nhập URL khi gạt BẬT Ghost" completion:^(NSString *newVal) {
                mgr.ghostConfig.urlOn = newVal;
                [mgr saveConfig:mgr.ghostConfig];
                [self.tableView reloadData];
            }];
        } else if (indexPath.row == 1) {
            [self editStringValue:mgr.ghostConfig.urlOff title:@"Link TẮT Ghost" message:@"Nhập URL khi gạt TẮT Ghost" completion:^(NSString *newVal) {
                mgr.ghostConfig.urlOff = newVal;
                [mgr saveConfig:mgr.ghostConfig];
                [self.tableView reloadData];
            }];
        } else {
            [self testFeatureUrl:RemoteFeatureGhost];
        }
    } else if (indexPath.section == 5) {
        if (indexPath.row == 0) {
            [[NSUserDefaults standardUserDefaults] setDouble:115 forKey:@"HUD_Panel_PosX"];
            [[NSUserDefaults standardUserDefaults] setDouble:220 forKey:@"HUD_Panel_PosY"];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"HUD_Panel_IsMini"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self showToast:@"Đã đặt lại vị trí nút nổi về mặc định!"];
        }
    }
}

- (void)editStringValue:(NSString *)initial title:(NSString *)title message:(NSString *)message completion:(void(^)(NSString *newVal))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = initial;
        textField.placeholder = @"https://...";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *val = alert.textFields.firstObject.text ?: @"";
        if (completion) completion(val);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)testFeatureUrl:(RemoteFeatureType)type {
    RemoteFeatureConfig *config = [[RemoteLinkManager sharedManager] configForType:type];
    NSString *urlToTest = config.urlOn;
    
    [self showToast:[NSString stringWithFormat:@"Đang gửi GET %@...", config.name]];
    
    [[RemoteLinkManager sharedManager] executeGetUrl:urlToTest completion:^(BOOL success, NSString * _Nullable responseText, NSInteger statusCode) {
        NSString *msg = [NSString stringWithFormat:@"Status Code: %ld\n\nPhản hồi: %@", (long)statusCode, responseText ?: @"Không có nội dung"];
        UIAlertController *resAlert = [UIAlertController alertControllerWithTitle:success ? @"✅ GET Thành Công" : @"❌ GET Thất Bại"
                                                                         message:msg
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [resAlert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:resAlert animated:YES completion:nil];
    }];
}

- (void)showToast:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.bounds.size.height - 100, self.view.bounds.size.width - 40, 44)];
    toast.backgroundColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.5 alpha:0.95];
    toast.textColor = [UIColor blackColor];
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.layer.cornerRadius = 10.0;
    toast.clipsToBounds = YES;
    toast.text = msg;
    toast.alpha = 0.0;
    [self.view addSubview:toast];
    
    [UIView animateWithDuration:0.2 animations:^{
        toast.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:1.5 options:0 animations:^{
            toast.alpha = 0.0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    }];
}

@end
