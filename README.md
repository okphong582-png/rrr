# ⚡ FakeLag for TrollStore (.tipa)

Ứng dụng tạo fake lag / tăng ping mạng chuyên dụng cho thiết bị iOS cài qua **TrollStore** (iOS 14.0 - 17.0).

Sở hữu cơ chế **Heads-Up Display (HUD) overlay** nổi đè lên màn hình chính và tất cả ứng dụng/game khác tương tự như **TrollSpeed**, kết hợp cấu hình **VPN hệ thống thật** (`NETunnelProviderManager`) và bộ sinh gói tin ngẫu nhiên (`Random Packet Flood Engine`).

---

## ✨ Tính Năng Nổi Bật

1. **Nút Tròn Xanh Nổi Mọi Lúc Mọi Nơi (AssistiveTouch Overlay)**:
   - Cơ chế chạy tiến trình HUD độc lập với đặc quyền TrollStore (`com.apple.private.security.no-sandbox`, `platform-application`).
   - Cửa sổ `UIWindow` cấp độ cao nhất (`windowLevel = 999999`) nổi đè lên SpringBoard và tất cả app.
   - **Xuyên thấu cảm ứng**: Chỉ bắt chạm vào nút tròn xanh `fakelag`, các khu vực khác trên màn hình vẫn vuốt chạm và chơi game hoàn toàn bình thường.
   - Kéo thả (`Drag & Pan`) nút tròn đi khắp các góc màn hình, tự động bám dính viền mép cạnh màn hình.

2. **Cấp Quyền VPN Thật & Sinh Gói Tin Ngẫu Nhiên**:
   - Khi bấm vào nút lần đầu: Tự động kích hoạt hộp thoại hệ thống iOS xin cấp cấu hình VPN thật (*Allow VPN Configurations*).
   - Khi BẬT: Nút chuyển sang **Màu Đỏ Phát Sáng (LAG ON)** với hiệu ứng radar nhấp nháy, phát liên tục hàng nghìn gói tin UDP ngẫu nhiên (512–1400 bytes) làm nghẽn băng thông, tăng jitter và tạo fake lag mạng thực sự.
   - Khi TẮT: Nút quay về **Màu Xanh Neon (fakelag)** và ngắt toàn bộ luồng phát gói tin.

3. **Giao Diện Điều Khiển Cao Cấp**:
   - Tùy chỉnh tốc độ gói tin (100 – 5,000 PPS).
   - Tùy chỉnh kích thước payload gói tin (128 – 1,400 Bytes).
   - Đo đạc lưu lượng mạng và số gói tin đã phát theo thời gian thực (Real-time).

---

## 🛠 Hướng Dẫn Tự Động Build .tipa Trên GitHub Actions

Kho mã nguồn đã được cấu hình sẵn GitHub Actions Workflow (`.github/workflows/build.yml`):

1. Đẩy mã nguồn lên kho GitHub của bạn (`https://github.com/okphong582-png/rrr`).
2. Vào tab **Actions** trên GitHub:
   - Chọn workflow **Build FakeLag TrollStore (.tipa)**.
   - Bấm **Run workflow**.
3. Sau khi quá trình build hoàn tất (khoảng 1-2 phút):
   - Vào mục **Artifacts** hoặc **Releases** để tải file `FakeLag.tipa`.
4. Chia sẻ file `.tipa` sang iPhone và mở bằng **TrollStore** để cài đặt trực tiếp.

---

## 📱 Hướng Dẫn Sử Dụng Trên iPhone

1. Mở ứng dụng **FakeLag** vừa cài từ TrollStore.
2. Bấm nút **"▶ BẬT NÚT NỔI OVERLAY"**.
3. Thoát ra màn hình chính hoặc vào game, bạn sẽ thấy nút tròn xanh có chữ **`fakelag`** nổi trên màn hình.
4. Kéo nút tròn đến vị trí mong muốn.
5. **Chạm 1 lần vào nút tròn**:
   - *Lần đầu*: iOS sẽ hiện bảng cấp quyền VPN -> Chọn **Allow** và xác thực FaceID/Passcode.
   - *Khi kích hoạt*: Nút tròn chuyển sang đỏ `LAG ON` và bắt đầu phát gói tin lag mạng.
   - *Khi muốn dừng*: Chạm lại vào nút tròn để tắt.
6. **Nhấn giữ nút tròn**: Để mở menu tùy chọn nhanh (Đặt lại vị trí, Mở app chính).

---

## 📂 Cấu Trúc Mã Nguồn

- `FakeLag/`: Mã nguồn ứng dụng chính UIKit.
  - `Controllers/MainViewController.m`: Bảng điều khiển, đồng hồ đo lưu lượng, thanh trượt tốc độ.
  - `Controllers/SettingsViewController.m`: Cài đặt IP/Port, quản lý cấp quyền VPN.
  - `Managers/PacketEngine.m`: Bộ sinh gói tin UDP đa luồng tốc độ cao.
  - `Managers/VPNManager.m`: Quản lý `NETunnelProviderManager` và Darwin Notifications.
  - `Managers/HUDLauncher.m`: `posix_spawn` tiến trình HUD độc lập với quyền root.
- `FakeLagHUD/`: Mã nguồn tiến trình HUD nổi ngoài màn hình.
  - `HUDWindow.m`: `UIWindow` tùy biến `hitTest:withEvent:` xuyên thấu cảm ứng.
  - `HUDViewController.m`: Nút tròn xanh `fakelag` kéo thả, hiệu ứng phát sáng radar, bắt chạm Bật/Tắt VPN.
- `FakeLagTunnel/`: NetworkExtension `NEPacketTunnelProvider`.
- `Entitlements/`: Bộ Entitlements đặc quyền TrollStore (`platform-application`, `no-sandbox`, `packet-tunnel`).
- `Scripts/build.sh`: Script biên dịch và đóng gói `.tipa`.
- `.github/workflows/build.yml`: Quy trình CI/CD tự động trên GitHub Actions.
