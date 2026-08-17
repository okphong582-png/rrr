#import "SettingsViewController.h"
#import "VPNManager.h"
#import "PacketEngine.h"

@interface SettingsViewController ()

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Cài Đặt Nâng Cao";
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.09 alpha:1.0];
    
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithTitle:@"Xong"
                                                                style:UIBarButtonItemStyleDone
                                                               target:self
                                                               action:@selector(dismissVC)];
    self.navigationItem.rightBarButtonItem = doneBtn;
    
    [self setupTableView];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.09 alpha:1.0];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
}

- (void)dismissVC {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2; // Target Host & Target Port
    if (section == 1) return 2; // VPN Reinstall & Reset Stats
    if (section == 2) return 3; // Info items
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"MỤC TIÊU GÓI TIN";
    if (section == 1) return @"QUẢN LÝ VPN & BỘ ĐỆM";
    if (section == 2) return @"THÔNG TIN ỨNG DỤNG";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"SettingsCell"];
        cell.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.15 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    }
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Địa Chỉ IP Mục Tiêu";
            cell.detailTextLabel.text = [PacketEngine sharedEngine].targetHost;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"Cổng Port Mục Tiêu";
            cell.detailTextLabel.text = [PacketEngine sharedEngine].targetPort == 0 ? @"Ngẫu nhiên (Random)" : [NSString stringWithFormat:@"%u", [PacketEngine sharedEngine].targetPort];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Cấp Lại Quyền VPN";
            cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1.0];
            cell.detailTextLabel.text = @"Yêu cầu hệ thống";
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            cell.textLabel.text = @"Đặt Lại Vị Trí Nút Nổi";
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.detailTextLabel.text = @"Về góc màn hình";
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Phiên Bản";
            cell.detailTextLabel.text = @"1.0.0 (TrollStore Build)";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Cơ Chế Overlay";
            cell.detailTextLabel.text = @"AssistiveTouch HUD";
        } else {
            cell.textLabel.text = @"Tương Thích";
            cell.detailTextLabel.text = @"iOS 14.0 - 17.0 (TrollStore)";
        }
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0 && indexPath.row == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Địa Chỉ IP Mục Tiêu"
                                                                       message:@"Nhập 'random' hoặc địa chỉ IP cụ thể (ví dụ 127.0.0.1)"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.text = [PacketEngine sharedEngine].targetHost;
            textField.placeholder = @"random hoặc 127.0.0.1";
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *text = alert.textFields.firstObject.text;
            if (text.length > 0) {
                [PacketEngine sharedEngine].targetHost = text;
                [tableView reloadData];
            }
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cổng Port Mục Tiêu"
                                                                       message:@"Nhập 0 để tự động random port mỗi gói tin, hoặc nhập port cụ thể (1-65535)"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.keyboardType = UIKeyboardTypeNumberPad;
            textField.text = [NSString stringWithFormat:@"%u", [PacketEngine sharedEngine].targetPort];
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *text = alert.textFields.firstObject.text;
            [PacketEngine sharedEngine].targetPort = (uint16_t)[text intValue];
            [tableView reloadData];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        [[VPNManager sharedManager] requestVPNPermissionWithCompletion:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *msg = success ? @"Cấu hình VPN đã được cập nhật thành công!" : error.localizedDescription;
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:success ? @"Thành Công" : @"Lỗi"
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            });
        }];
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"FakeLag_Button_X"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"FakeLag_Button_Y"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Đặt Lại"
                                                                       message:@"Vị trí nút nổi đã được đưa về mặc định."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end
