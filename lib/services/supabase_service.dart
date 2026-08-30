import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/run_session.dart';
import 'calorie_calculator.dart';

class SupabaseService {
  // Thông tin Supabase Cloud chính thức của bạn
  static const String supabaseUrl = 'https://feomtpqthkendplcotoc.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_ORTj3-mqtLmBku0Ybu9rVw_7vZugC69';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseUrl != 'https://YOUR_PROJECT_ID.supabase.co';

  static SupabaseClient? get client {
    if (!isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static User? get currentAuthUser {
    return client?.auth.currentUser;
  }

  /// Khởi tạo Supabase khi khởi động app
  static Future<void> initialize() async {
    if (isConfigured) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: supabaseAnonKey,
        );
        debugPrint('✅ Đã kết nối Supabase Cloud thành công!');
      } catch (e) {
        debugPrint('⚠️ Lỗi kết nối Supabase: $e');
      }
    } else {
      debugPrint('ℹ️ Supabase chưa điền URL/Key. App đang chạy ở chế độ Dữ liệu Bộ nhớ.');
    }
  }

  // ==========================================
  // XÁC THỰC TÀI KHOẢN & BẢNG PROFILES CLOUD (SIÊU TỐC)
  // ==========================================

  /// Tìm email tương ứng qua username (cho phép đăng nhập bằng username)
  static Future<String?> fetchEmailByUsername(String username) async {
    final supa = client;
    if (supa == null) return null;
    try {
      final cleanUsername = username.trim().toLowerCase();
      final res = await supa
          .from('profiles')
          .select('email')
          .ilike('username', cleanUsername)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(milliseconds: 2500), onTimeout: () => null);
      return res?['email'] as String?;
    } catch (e) {
      debugPrint('Lỗi tìm email theo username: $e');
      return null;
    }
  }

  /// Xác thực phiên thực tế với server Supabase (Không block UI)
  static Future<User?> verifyServerSession() async {
    final supa = client;
    if (supa == null) return null;

    try {
      final res = await supa.auth.getUser().timeout(const Duration(milliseconds: 2500));
      return res.user;
    } catch (e) {
      return null;
    }
  }

  /// Lấy thông tin chi tiết và quyền hạn từ bảng profiles (1 Query duy nhất - Tốc độ < 0.5s)
  static Future<Map<String, dynamic>?> fetchProfile(String userId, [String? email, String? username]) async {
    final supa = client;
    if (supa == null) return null;
    try {
      final List<String> orFilters = [];
      if (userId.isNotEmpty) orFilters.add('id.eq.$userId');
      if (email != null && email.isNotEmpty) orFilters.add('email.ilike.${email.trim()}');
      if (username != null && username.isNotEmpty) orFilters.add('username.ilike.${username.trim()}');

      if (orFilters.isEmpty) return null;

      final res = await supa
          .from('profiles')
          .select()
          .or(orFilters.join(','))
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(milliseconds: 2500), onTimeout: () => null);
      return res;
    } catch (e) {
      debugPrint('Lỗi fetch profiles: $e');
      return null;
    }
  }

  /// Cập nhật thông tin vào bảng profiles
  static Future<bool> updateProfileTable(String userId, {String? name, String? username, String? email, String? role, String? avatarUrl}) async {
    final supa = client;
    if (supa == null) return false;
    try {
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (username != null) updateData['username'] = username.toLowerCase().trim();
      if (email != null) updateData['email'] = email;
      if (role != null) updateData['role'] = role;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      await supa.from('profiles').update(updateData).eq('id', userId).timeout(const Duration(seconds: 3));
      return true;
    } catch (e) {
      debugPrint('Lỗi update profiles table: $e');
      return false;
    }
  }

  /// Lấy toàn bộ danh sách hồ sơ người dùng (profiles) từ Supabase Cloud
  static Future<List<Map<String, dynamic>>?> fetchAllProfiles() async {
    final supa = client;
    if (supa == null) return null;
    try {
      final res = await supa
          .from('profiles')
          .select()
          .timeout(const Duration(seconds: 4));
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Lỗi fetchAllProfiles: $e');
      return null;
    }
  }

  /// Lấy vai trò (role) chính xác từ Supabase DB
  static String extractRole(User user, [Map<String, dynamic>? profile]) {
    if (profile != null && profile['role'] != null) {
      final r = profile['role'].toString().toLowerCase().trim();
      if (r == 'admin') return 'admin';
      return 'user';
    }
    final meta = user.userMetadata ?? {};
    final role = meta['role'] as String?;
    if (role == 'admin') return 'admin';
    return 'user';
  }

  /// Đăng ký tài khoản mới lên Supabase Cloud (Tự động gửi OTP 4 số)
  static Future<AuthResponse?> signUp({
    required String email,
    required String username,
    required String password,
    required String name,
    String role = 'user',
  }) async {
    final supa = client;
    if (supa == null) return null;

    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();

    try {
      final response = await supa.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'name': name.trim(),
          'username': cleanUsername,
          'role': role,
        },
      ).timeout(const Duration(seconds: 6));

      // Tự động thêm ngay vào bảng profiles
      if (response.user != null) {
        supa.from('profiles').upsert({
          'id': response.user!.id,
          'email': cleanEmail,
          'username': cleanUsername,
          'name': name.trim(),
          'role': role,
          'avatar_url': '',
        }).timeout(const Duration(seconds: 3), onTimeout: () => null);
      }

      return response;
    } catch (e) {
      debugPrint('Lỗi đăng ký Supabase: $e');
      rethrow;
    }
  }

  /// Xác thực mã OTP gửi về Email qua Supabase Cloud
  static Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final supa = client;
    if (supa == null) throw Exception('Supabase client chưa kết nối.');

    try {
      final response = await supa.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.signup,
      ).timeout(const Duration(seconds: 5));
      return response;
    } catch (e) {
      debugPrint('Lỗi xác thực OTP Supabase: $e');
      rethrow;
    }
  }

  /// Gửi lại mã OTP qua Email thực tế
  static Future<void> resendEmailOtp({required String email}) async {
    final supa = client;
    if (supa == null) throw Exception('Supabase client chưa kết nối.');

    try {
      await supa.auth.resend(
        email: email.trim().toLowerCase(),
        type: OtpType.signup,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Lỗi gửi lại OTP Supabase: $e');
      rethrow;
    }
  }

  /// Đăng nhập tài khoản với Supabase Cloud (Siêu nhanh < 1s)
  static Future<AuthResponse?> signIn({
    required String identifier,
    required String password,
  }) async {
    final supa = client;
    if (supa == null) return null;

    String targetEmail = identifier.trim().toLowerCase();

    // Nếu người dùng nhập Username (không có ký tự @), tìm email tương ứng từ DB
    if (!targetEmail.contains('@')) {
      final resolvedEmail = await fetchEmailByUsername(targetEmail);
      if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
        targetEmail = resolvedEmail;
      }
    }

    try {
      final response = await supa.auth.signInWithPassword(
        email: targetEmail,
        password: password,
      ).timeout(const Duration(seconds: 5));
      return response;
    } catch (e) {
      debugPrint('Lỗi đăng nhập Supabase: $e');
      rethrow;
    }
  }

  /// Đăng xuất khỏi Cloud
  static Future<void> signOut() async {
    final supa = client;
    if (supa == null) return;
    try {
      await supa.auth.signOut().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Lỗi đăng xuất Supabase: $e');
    }
  }

  /// Gửi email khôi phục mật khẩu (chứa mã OTP 6 số)
  static Future<String> sendPasswordResetEmail(String identifier) async {
    final supa = client;
    if (supa == null) throw Exception('Supabase client chưa kết nối.');

    String targetEmail = identifier.trim().toLowerCase();

    // Nếu người dùng nhập Username, tự động tìm email tương ứng từ DB profiles
    if (!targetEmail.contains('@')) {
      final resolvedEmail = await fetchEmailByUsername(targetEmail);
      if (resolvedEmail == null || resolvedEmail.isEmpty) {
        throw Exception('Không tìm thấy tài khoản với tên đăng nhập "$identifier".');
      }
      targetEmail = resolvedEmail;
    }

    try {
      await supa.auth.resetPasswordForEmail(targetEmail).timeout(const Duration(seconds: 5));
      return targetEmail;
    } catch (e) {
      debugPrint('Lỗi gửi reset password Supabase: $e');
      rethrow;
    }
  }

  /// Xác thực mã OTP khôi phục mật khẩu và cập nhật mật khẩu mới
  static Future<void> verifyResetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final supa = client;
    if (supa == null) throw Exception('Supabase client chưa kết nối.');

    try {
      final cleanEmail = email.trim().toLowerCase();
      // 1. Xác thực OTP loại Recovery
      await supa.auth.verifyOTP(
        email: cleanEmail,
        token: token.trim(),
        type: OtpType.recovery,
      ).timeout(const Duration(seconds: 6));

      // 2. Cập nhật mật khẩu mới
      await supa.auth.updateUser(
        UserAttributes(password: newPassword),
      ).timeout(const Duration(seconds: 5));

      // 3. Đăng xuất sạch phiên tạm thời để người dùng đăng nhập lại
      await supa.auth.signOut().timeout(const Duration(seconds: 3), onTimeout: () => null);
    } catch (e) {
      debugPrint('Lỗi verify reset password OTP: $e');
      rethrow;
    }
  }

  /// Đổi mật khẩu tài khoản trên Cloud
  static Future<bool> changePassword(String newPassword) async {
    final supa = client;
    if (supa == null) return false;
    try {
      await supa.auth.updateUser(
        UserAttributes(password: newPassword),
      ).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) {
      debugPrint('Lỗi đổi mật khẩu Supabase: $e');
      return false;
    }
  }

  /// Cập nhật thông tin người dùng lên Cloud
  static Future<bool> updateUserProfile({String? name, String? username, String? avatarUrl, String? role, String? userId}) async {
    final supa = client;
    if (supa == null) return false;
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (username != null) data['username'] = username.toLowerCase().trim();
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      if (role != null) data['role'] = role;

      await supa.auth.updateUser(
        UserAttributes(data: data),
      ).timeout(const Duration(seconds: 4));

      final uid = userId ?? supa.auth.currentUser?.id;
      if (uid != null) {
        updateProfileTable(uid, name: name, username: username, role: role, avatarUrl: avatarUrl);
      }

      return true;
    } catch (e) {
      debugPrint('Lỗi cập nhật profile Supabase: $e');
      return false;
    }
  }

  // ==========================================
  // QUẢN LÝ DỮ LIỆU BUỔI CHẠY (RUN SESSIONS)
  // ==========================================

  /// Lấy toàn bộ danh sách buổi chạy từ Supabase Cloud
  static Future<List<RunSession>?> fetchRunSessions() async {
    final supa = client;
    if (supa == null) return null;

    try {
      final data = await supa
          .from('run_sessions')
          .select()
          .order('start_time', ascending: false)
          .timeout(const Duration(seconds: 4));

      final List<RunSession> list = [];
      for (final item in data) {
        final List<RunPoint> routePoints = [];
        if (item['route_points'] is List) {
          for (final pt in item['route_points']) {
            if (pt is Map && pt['x'] != null && pt['y'] != null) {
              routePoints.add(RunPoint((pt['x'] as num).toDouble(), (pt['y'] as num).toDouble()));
            }
          }
        }

        list.add(
          RunSession(
            id: item['id'].toString(),
            userId: item['user_id'] ?? 'user_default',
            userName: item['user_name'] ?? 'Người chạy',
            startTime: DateTime.parse(item['start_time']),
            endTime: item['end_time'] != null ? DateTime.parse(item['end_time']) : DateTime.now(),
            durationSeconds: (item['duration_seconds'] as num?)?.toInt() ?? 0,
            distanceKm: (item['distance_km'] as num?)?.toDouble() ?? 0.0,
            calories: (item['calories'] as num?)?.toInt() ?? 0,
            notes: item['notes'] ?? '',
            routePoints: routePoints,
          ),
        );
      }
      return list;
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu Supabase: $e');
      return null;
    }
  }

  /// Thêm buổi chạy mới lên Supabase Cloud
  static Future<bool> insertRunSession(RunSession session) async {
    final supa = client;
    if (supa == null) return false;

    try {
      final payload = <String, dynamic>{
        'id': session.id,
        'user_id': session.userId,
        'user_name': session.userName,
        'start_time': session.startTime.toIso8601String(),
        'end_time': session.endTime.toIso8601String(),
        'duration_seconds': session.durationSeconds,
        'distance_km': session.distanceKm,
        'calories': session.calories,
        'notes': session.notes,
      };
      if (session.routePoints.isNotEmpty) {
        payload['route_points'] = session.routePoints.map((p) => {'x': p.x, 'y': p.y}).toList();
      }

      await supa.from('run_sessions').insert(payload).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) {
      debugPrint('Lỗi thêm buổi chạy Supabase: $e');
      return false;
    }
  }

  /// Admin cập nhật số KM và thời gian chạy lên Cloud
  static Future<bool> updateRunSession(
    String id, {
    required double newDistanceKm,
    required int newDurationSeconds,
    String? newNotes,
  }) async {
    final supa = client;
    if (supa == null) return false;

    try {
      final Map<String, dynamic> updateData = {
        'distance_km': newDistanceKm,
        'duration_seconds': newDurationSeconds,
        'calories': CalorieCalculator.calculate(
          distanceKm: newDistanceKm,
          durationSeconds: newDurationSeconds,
        ),
      };
      if (newNotes != null) {
        updateData['notes'] = newNotes;
      }

      await supa.from('run_sessions').update(updateData).eq('id', id).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) {
      debugPrint('Lỗi cập nhật buổi chạy Supabase: $e');
      return false;
    }
  }

  /// Xóa buổi chạy khỏi Cloud
  static Future<bool> deleteRunSession(String id) async {
    final supa = client;
    if (supa == null) return false;

    try {
      await supa.from('run_sessions').delete().eq('id', id).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) {
      debugPrint('Lỗi xóa buổi chạy Supabase: $e');
      return false;
    }
  }
}
