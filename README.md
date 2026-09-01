# 🏃‍♂️ Nocodevn Running (v1.2.0)

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-brightgreen" alt="Platform" />
  <img src="https://img.shields.io/badge/Style-Pro%20Sport%20Dark%20Neon-FF2A42" alt="Pro Sport" />
</p>

**Nocodevn Running** là ứng dụng theo dõi chạy bộ chuyên nghiệp, kết hợp độ chính xác cao của định vị GPS với công nghệ mô phỏng lộ trình 3D độc quyền và Huấn luyện viên giọng nói tiếng Việt. Ứng dụng được thiết kế theo phong cách thể thao Pro Dark Mode hiện đại (Neon Đỏ `#FF2A42` & Neon Xanh `#139EFE`), mang lại trải nghiệm luyện tập sống động và cảm hứng bứt phá mỗi ngày.

---

## 🌟 Tính Năng Nổi Bật

### 1. 📡 Theo Dõi Chạy Bộ Thời Gian Thực (Pro GPS Tracking)
* **Bộ lọc Kalman 3 Lớp Chuyên Nghiệp**:
  * *Lớp 1 (Physical Bounds Filter)*: Lọc bỏ sai số sóng vệ tinh và bước nhảy tọa độ bất thường.
  * *Lớp 2 (2D Kalman Anti-Drift)*: Triệt tiêu hiện tượng trôi dạt GPS khi dừng đèn đỏ hoặc đi chậm. Khóa sàn phương sai chống "liệt" bộ lọc khi đứng yên.
  * *Lớp 3 (10s Rolling Pace)*: Làm mịn nhịp Pace theo cửa sổ trượt 10 giây, phản ánh tức thì tốc độ chân chạy.
* **Cơ Chế Chống Deadlock Tọa Độ (Auto-Resync)**: Nhận diện chính xác và tiếp tục đếm km ngay lập tức khi bạn bứt tốc nhanh, dừng lại rồi chạy tiếp.
* **Đầy Đủ Thông Số Thể Thao Thời Gian Thực**: Quãng đường (KM), Thời gian chạy thực tế (Wall-clock), Nhịp Pace, Calo tiêu hao (chuẩn y học thể thao ACSM), Vận tốc trung bình (km/h).
* **Tự Động Nhận Diện Trạng Thái Vận Động**: Nhận diện tức thì: *Đứng yên*, *Đi bộ*, *Chạy bộ*, *Bứt tốc*.
* **Chạy Ngầm Xuyên Suốt Trên iOS & Android**: Hỗ trợ `AppleSettings.fitness`, giữ kết nối GPS ổn định ngay cả khi khóa màn hình hoặc nhét túi quần.
* **Bảng Thông Báo Trực Tiếp Đếm Từng Giây (Live Workout Notification)**: Hiển thị thời gian, cự ly và pace nhảy liên tục từng giây ngoài màn hình khóa.

---

### 2. 🎥 Video Lộ Trình 3D Độc Quyền (3D Route Flyover)
* **Mô Phỏng 3D Sống Động**: Xem lại toàn bộ cung đường đã chạy trên nền bản đồ 3D địa hình trực quan.
* **2 Chế Độ Xem Linh Hoạt**:
  * *Chế độ Theo dõi (Follow-cam)*: Góc quay 3D nghiêng thể thao bám sát từng bước chân của vận động viên từ vạch xuất phát đến đích.
  * *Chế độ Toàn cảnh (Overview)*: Camera bao quát toàn bộ lộ trình với hiệu ứng zoom nghệ thuật.
* **Thẻ Thông Số HUD Chuyên Nghiệp**: Hiển thị realtime cự ly, thời gian, pace và calo theo từng mét chạy.
* **Xuất Video MP4 60FPS Chất Lượng Cao**: Cho phép tải video về thư viện ảnh điện thoại để chia sẻ lên TikTok, Facebook Reels, Instagram Story hoặc khoe thành tích với bạn bè.
* **Tối Ưu Hóa Render Siêu Tốc**: Bộ đệm tile bản đồ thông minh và cơ chế giải phóng GPU tức thì khi thoát, hoàn toàn không bị delay hay kẹt màn hình.

---

### 3. 📊 Phân Tích Từng KM Chi Tiết (Splits / Lap Breakdown)
* **Tự Động Chia Chặng Mỗi 1.0 KM**: Tính toán chi tiết thời gian, pace, số bước chân và calo tiêu hao của từng kilomet.
* **Chỉ Báo Tăng/Giảm Nhịp Độ**: So sánh chênh lệch giây với chặng trước đó (ví dụ: `▲ -19s` hay `▼ +11s`).
* **Biểu Đồ Thanh Tốc Độ Gradient**: Phối màu Gradient trực quan (Đỏ - Cam rực rỡ cho chặng nhanh nhất, Xanh neon - Cyan cho chặng ổn định).
* **Huy Hiệu Chặng Nhanh Nhất (Best Split 🔥)**: Tôn vinh kilomet bứt phá tốt nhất trong buổi chạy.
* **Khối Tổng Kết Đáy Bảng Rõ Ràng**: Badge **TỔNG**, hiển thị đầy đủ tổng KM, Tốc độ TB, Pace TB, Tổng số bước chân (có phân cách hàng nghìn) và Tổng Calo.

---

### 4. 🎙️ Huấn Luyện Viên Giọng Nói Tiếng Việt (Voice Coach Motivation)
* **Phát Giọng Nói Chuẩn Tiếng Việt**: Tích hợp Text-to-Speech truyền cảm, âm điệu tự nhiên.
* **Thông Báo Tự Động Qua Từng Cột Mốc**:
  * Đọc hiệu lệnh khi: *Bắt đầu*, *Tạm dừng*, *Tiếp tục*.
  * Tự động đọc tổng kết mỗi khi hoàn thành 1 KM: *"Bạn đã chạy được X km trong vòng Y phút, Pace Z"*.
  * Tổng kết sau khi kết thúc buổi chạy.
* **Nhắc Nhở Giờ Chạy Truyền Cảm Hứng**: Cất giọng động viên vào giờ hẹn chạy bộ:  
  > *"Chào [Tên], đã đến giờ chạy rồi. Cùng xỏ giày và bứt phá hôm nay nhé!"*

---

### 5. ⏰ Cài Đặt Luyện Tập Thông Minh (Auto-End & Smart Reminder)
* **Tự Động Chốt Phiên Chạy (Chống Quên)**:
  * Cho phép cài đặt giờ tự động kết thúc (ví dụ: `07:30` sáng).
  * Tự động lưu và chốt phiên chạy khi đến hoặc vượt qua giờ đã cài, ngăn ngừa tình trạng quên tắt app làm sai lệch số liệu Pace và hao pin.
* **Nhắc Nhở Luyện Tập Hàng Ngày**:
  * Cài đặt khung giờ nhắc nhở chạy bộ buổi sáng (ví dụ: `05:30`).
  * Bắn thông báo ngoài màn hình khóa kèm chuông báo, rung haptic và giọng nói Voice Coach tiếp thêm động lực.
  * Hộp thoại tương tác `AnimatedReminderDialog` rung chuông sinh động khi người dùng mở app.

---

### 6. 📈 Lịch Sử & Thống Kê Tiến Độ Luyện Tập
* **Bộ Lọc Đa Khung Thời Gian**: Thống kê linh hoạt theo *Ngày*, *Tuần*, *Tháng*, *Năm*.
* **Biểu Đồ Trực Quan Kép**: Biểu đồ cột đôi thể hiện trực quan quãng đường (km) và thời lượng tập luyện (phút).
* **Lịch Luyện Tập (Calendar View)**: Chấm tròn đánh dấu các ngày có tập luyện, giúp runner dễ dàng theo dõi chuỗi ngày kỷ luật (Streak).
* **Kiến Trúc Lưu Trữ 2 Tầng (Offline-First)**:
  * *Tầng 1 (Local Cache)*: Lưu trữ cục bộ qua `SharedPreferences`, mở app lên là thấy số liệu ngay lập tức mà không cần chờ mạng.
  * *Tầng 2 (Cloud Sync)*: Tự động đồng bộ lên Supabase Cloud khi có kết nối Internet. Hỗ trợ tự động đẩy lại các buổi chạy bị gián đoạn (Pending Sync).

---

### 7. 🛡️ Tài Khoản & Phân Quyền Quản Trị Hệ Thống (Admin Panel)
* **Xác Thực Người Dùng An Toàn**: Đăng ký, đăng nhập bằng Email và bảo mật mật khẩu qua Supabase Auth.
* **Hồ Sơ Cá Nhân**: Cập nhật họ tên, đổi mật khẩu, đổi Avatar đại diện sinh động.
* **Trang Quản Trị Hệ Thống (Dành riêng cho Admin)**:
  * Quản lý danh sách tất cả vận động viên trong hệ thống.
  * Tra cứu, xem chi tiết và kiểm soát lịch sử chạy bộ của từng thành viên.

---

## 🛠️ Công Nghệ Sử Dụng (Tech Stack)

| Thành phần | Công nghệ / Thư viện |
|---|---|
| **Framework** | [Flutter](https://flutter.dev) (Dart 3, Sound Null Safety) |
| **State Management** | [Provider](https://pub.dev/packages/provider) |
| **Backend & Cloud** | [Supabase](https://supabase.com) (PostgreSQL, Auth, Storage) |
| **Định Vị & Lọc GPS** | [Geolocator](https://pub.dev/packages/geolocator) + Thuật toán lọc Kalman 3 Lớp tùy biến |
| **Biểu Đồ Thống Kê** | [fl_chart](https://pub.dev/packages/fl_chart) |
| **Xuất Video 3D** | [flutter_quick_video_encoder](https://pub.dev/packages/flutter_quick_video_encoder) + Custom Canvas 3D Painter |
| **Thông Báo Ngầm** | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) + [timezone](https://pub.dev/packages/timezone) |
| **Giọng Nói (Voice Coach)** | [flutter_tts](https://pub.dev/packages/flutter_tts) |
| **Lưu Trữ Ảnh/Video** | [gal](https://pub.dev/packages/gal) + [path_provider](https://pub.dev/packages/path_provider) |

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Ứng Dụng

### 1. Yêu Cầu Môi Trường
* **Flutter SDK**: `>= 3.13.1`
* **Dart SDK**: `>= 3.1.0`
* Thiết bị di động thật (iOS hoặc Android) hoặc Simulator/Emulator có hỗ trợ định vị GPS.

### 2. Cài Đặt
```bash
# 1. Clone repository về máy
git clone https://github.com/leliendaii/running.git

# 2. Di chuyển vào thư mục dự án
cd running

# 3. Tải các gói phụ thuộc (dependencies)
flutter pub get

# 4. Kiểm tra mã nguồn
flutter analyze

# 5. Chạy ứng dụng trên thiết bị
flutter run
```

---

## 📱 Cấu Trúc Thư Mục Dự Án

```text
lib/
├── models/             # Data models: RunSession, UserModel, KmSplit...
├── providers/          # State Management: RunningProvider, AuthProvider...
├── screens/            # Giao diện chính:
│   ├── main_shell.dart             # Điều hướng tab chính (Màn hình chính, Lịch sử, Cá nhân)
│   ├── running_screen.dart         # Màn hình theo dõi chạy bộ trực tiếp
│   ├── session_detail_screen.dart  # Chi tiết buổi chạy & Bảng phân tích Splits
│   ├── route_flyover_3d_screen.dart# Xem & xuất video mô phỏng lộ trình 3D
│   ├── auto_end_schedule_screen.dart# Cài đặt tự động chốt & nhắc nhở giờ chạy
│   ├── admin_dashboard_screen.dart # Trang quản trị hệ thống runner (Admin)
│   └── history_screen.dart         # Lịch sử & Thống kê tuần/tháng/năm
├── services/           # Nghiệp vụ:
│   ├── gps_kalman_filter.dart      # Bộ lọc Kalman 3 Lớp chống rung & chống Deadlock
│   ├── voice_coach_service.dart    # Huấn luyện viên giọng nói tiếng Việt
│   ├── live_workout_notification_service.dart # Thông báo ngầm đếm từng giây & Alarm
│   ├── supabase_service.dart       # Tương tác Cloud Supabase API
│   ├── calorie_calculator.dart     # Tính Calo theo chuẩn ACSM
│   └── map_tile_cache_service.dart # Bộ nhớ đệm bản đồ vệ tinh phục vụ video 3D
├── theme/              # Hệ thống màu sắc Neon Đỏ / Xanh, Typography & Dark Mode
└── widgets/            # Các component UI tái sử dụng (Splits card, Dialogs, Avatars...)
```

---

## 📄 Bản Quyền & Giấy Phép

Phát triển bởi **Nocodevn Running Team**.  
Mọi quyền được bảo lưu © 2026.
