import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/run_session.dart';

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
  // XÁC THỰC TÀI KHOẢN CLOUD (MÃ HÓA & BĂM BCRYPT)
  // ==========================================

  /// Đăng ký tài khoản mới lên Supabase Cloud (Mật khẩu được băm và mã hóa chuẩn bảo mật quốc tế)
  static Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'user',
  }) async {
    final supa = client;
    if (supa == null) return null;

    try {
      final response = await supa.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
        },
      );
      return response;
    } catch (e) {
      debugPrint('Lỗi đăng ký Supabase: $e');
      rethrow;
    }
  }

  /// Đăng nhập tài khoản với Supabase Cloud
  static Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    final supa = client;
    if (supa == null) return null;

    try {
      final response = await supa.auth.signInWithPassword(
        email: email,
        password: password,
      );
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
      await supa.auth.signOut();
    } catch (e) {
      debugPrint('Lỗi đăng xuất Supabase: $e');
    }
  }

  /// Đổi mật khẩu tài khoản trên Cloud
  static Future<bool> changePassword(String newPassword) async {
    final supa = client;
    if (supa == null) return false;
    try {
      await supa.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      debugPrint('Lỗi đổi mật khẩu Supabase: $e');
      return false;
    }
  }

  /// Cập nhật thông tin người dùng (Tên, Avatar) lên Cloud
  static Future<bool> updateUserProfile({String? name, String? avatarUrl}) async {
    final supa = client;
    if (supa == null) return false;
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;

      await supa.auth.updateUser(
        UserAttributes(data: data),
      );
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
          .order('start_time', ascending: false);

      final List<RunSession> list = [];
      for (final item in data) {
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
      await supa.from('run_sessions').insert({
        'id': session.id,
        'user_id': session.userId,
        'user_name': session.userName,
        'start_time': session.startTime.toIso8601String(),
        'end_time': session.endTime.toIso8601String(),
        'duration_seconds': session.durationSeconds,
        'distance_km': session.distanceKm,
        'calories': session.calories,
        'notes': session.notes,
      });
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
        'calories': (newDistanceKm * 62).round(),
      };
      if (newNotes != null) {
        updateData['notes'] = newNotes;
      }

      await supa.from('run_sessions').update(updateData).eq('id', id);
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
      await supa.from('run_sessions').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Lỗi xóa buổi chạy Supabase: $e');
      return false;
    }
  }
}
