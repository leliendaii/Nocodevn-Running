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
    required double distanceKm,
    required int durationSeconds,
    required int calories,
    required String notes,
  }) async {
    final supa = client;
    if (supa == null) return false;

    try {
      await supa.from('run_sessions').update({
        'distance_km': distanceKm,
        'duration_seconds': durationSeconds,
        'calories': calories,
        'notes': notes,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Lỗi cập nhật buổi chạy Supabase: $e');
      return false;
    }
  }

  /// Admin xóa buổi chạy trên Cloud
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
