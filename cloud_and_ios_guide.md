# 📘 Hướng Dẫn Kết Nối Supabase Cloud & Xuất File Cài Đặt iPhone (Diawi)

---

## PHẦN 1: KẾT NỐI DATABASE ĐÁM MÂY (SUPABASE)

### Bước 1: Tạo dự án Supabase miễn phí
1. Truy cập [https://supabase.com](https://supabase.com) và đăng ký/đăng nhập (bằng tài khoản GitHub hoặc Google).
2. Nhấn nút **"New project"**.
3. Đặt tên dự án (ví dụ: `RunningTracker`) và đặt mật khẩu database -> Bấm **"Create new project"** (chờ khoảng 1 phút để hệ thống khởi tạo).

---

### Bước 2: Tạo Bảng Dữ Liệu (Run Sessions Table)
1. Ở thanh menu bên trái Supabase, chọn mục **"SQL Editor"** (biểu tượng `>_`).
2. Bấm **"New query"**, dán toàn bộ đoạn mã SQL bên dưới vào và bấm **"Run"**:

```sql
-- Tạo bảng lưu trữ các buổi chạy bộ
CREATE TABLE IF NOT EXISTS run_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    user_name TEXT NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    distance_km NUMERIC(6, 2) NOT NULL DEFAULT 0.0,
    calories INTEGER NOT NULL DEFAULT 0,
    notes TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cho phép đọc và ghi dữ liệu công khai (hoặc qua API Key)
ALTER TABLE run_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Cho phép đọc dữ liệu buổi chạy" 
ON run_sessions FOR SELECT USING (true);

CREATE POLICY "Cho phép thêm buổi chạy" 
ON run_sessions FOR INSERT WITH CHECK (true);

CREATE POLICY "Cho phép Admin sửa buổi chạy" 
ON run_sessions FOR UPDATE USING (true);

CREATE POLICY "Cho phép Admin xóa buổi chạy" 
ON run_sessions FOR DELETE USING (true);
```

---

### Bước 3: Lấy URL và API Key điền vào App
1. Ở menu bên trái Supabase, vào **Project Settings (biểu tượng bánh răng)** > chọn **API**.
2. Copy 2 thông số:
   - **Project URL** (dạng `https://xyz...supabase.co`)
   - **anon / public key** (chuỗi ký tự dài)
3. Mở file [lib/services/supabase_service.dart](file:///d:/Mobile/Running/lib/services/supabase_service.dart) trong Antigravity và thay thế vào 2 dòng đầu:

```dart
static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co'; // Thay bằng URL của bạn
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY'; // Thay bằng Key của bạn
```

> 🎉 **Xong!** Bây giờ mỗi khi bạn bấm "Kết thúc" buổi chạy hoặc Admin bấm "Sửa KM/Thời gian", dữ liệu sẽ lưu thẳng lên đám mây thời gian thực!

---

## PHẦN 2: XUẤT FILE .IPA & TẠO LINK DIAWI GỬI QUA ZALO CÀI VÀO IPHONE

Tôi đã tạo sẵn file cấu hình tự động tại [.github/workflows/build_ios_diawi.yml](file:///d:/Mobile/Running/.github/workflows/build_ios_diawi.yml).

### Bước 1: Đẩy mã nguồn lên GitHub
Mở Terminal trong Antigravity và chạy các lệnh:
```bash
git init
git add .
git commit -m "Khoi tao app chay bo va admin"
git branch -M main
git remote add origin https://github.com/USERNAME/TEN_REPO_CUA_BAN.git
git push -u origin main
```

---

### Bước 2: Lấy API Token miễn phí trên Diawi
1. Truy cập [https://www.diawi.com](https://www.diawi.com) và đăng ký một tài khoản miễn phí.
2. Vào mục **Dashboard** > **API** > Nhấn **Generate API Token**.
3. Copy mã Token vừa tạo.

---

### Bước 3: Thêm Token vào GitHub
1. Mở trang dự án của bạn trên **GitHub**.
2. Vào tab **Settings** > chọn **Secrets and variables** > chọn **Actions**.
3. Bấm **"New repository secret"**:
   - **Name**: `DIAWI_TOKEN`
   - **Secret**: *(Dán mã token Diawi vừa copy ở trên)*
4. Bấm **"Add secret"**.

---

### Bước 4: Chạy Build và Nhận Link Cài Đặt iPhone
1. Trên GitHub, chuyển sang tab **Actions**.
2. Chọn workflow **"Build iOS IPA & Upload to Diawi"** ở cột bên trái.
3. Bấm nút **"Run workflow"** > chọn nhánh `main` > bấm **Run**.
4. Chờ máy Mac ảo của GitHub biên dịch trong khoảng 3 - 5 phút.
5. Khi hoàn thành, mở vào lượt chạy, bạn sẽ thấy ngay:
   - **🎉 Link cài đặt Diawi** (Ví dụ: `https://install.diawi.com/abc123xyz`).
   - File **`app.ipa`** để tải về nếu muốn lưu trữ.

---

### Bước 5: Cài đặt trên iPhone
1. Copy đường **Link Diawi** gửi vào **Zalo**.
2. Mở Zalo trên iPhone, bấm vào link -> Mở bằng **Safari**.
3. Nhấn nút **"Install Application"**.
4. Vào *Cài đặt trên iPhone > Cài đặt chung > Quản lý VPN & Thiết bị* -> Bấm **Tin cậy (Trust)**.

👉 **Mở app lên và tận hưởng thành quả ứng dụng chạy bộ của riêng bạn!**
