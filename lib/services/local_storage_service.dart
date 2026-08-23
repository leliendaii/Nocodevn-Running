import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/run_session.dart';

class LocalStorageService {
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserName = 'auth_user_name';
  static const String _keyUserUsername = 'auth_user_username';
  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserRole = 'auth_user_role';
  static const String _keyUserAvatar = 'auth_user_avatar';
  static const String _keyRememberMe = 'auth_remember_me';
  static const String _keyLastActive = 'auth_last_active';
  static const String _keyAdminPassword = 'auth_admin_password';
  static const String _keySavedAccounts = 'auth_saved_accounts';

  // Offline Cache & Pending Sync
  static const String _keyPendingRuns = 'offline_pending_runs';
  static const String _keyCachedSessions = 'offline_cached_sessions';

  /// Lưu phiên đăng nhập người dùng và thiết lập 30 ngày
  static Future<void> saveUserSession({
    required AppUser user,
    required bool rememberMe,
    String? password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId, user.id);
      await prefs.setString(_keyUserName, user.name);
      await prefs.setString(_keyUserUsername, user.username);
      await prefs.setString(_keyUserEmail, user.email);
      await prefs.setString(_keyUserRole, user.role == UserRole.admin ? 'admin' : 'user');
      await prefs.setString(_keyUserAvatar, user.avatarUrl);
      await prefs.setBool(_keyRememberMe, rememberMe);
      await prefs.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);

      // Cập nhật vào danh sách tài khoản đã lưu
      if (password != null && password.isNotEmpty) {
        await saveAccountCredentials(user.email, password, user.name, user.role == UserRole.admin);
      }
    } catch (e) {
      debugPrint('Lỗi lưu phiên người dùng: $e');
    }
  }

  /// Tải thông tin người dùng đã lưu (Kiểm tra điều kiện 30 ngày)
  static Future<AppUser?> loadSavedUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      if (!rememberMe) return null;

      final lastActiveMs = prefs.getInt(_keyLastActive) ?? 0;
      if (lastActiveMs == 0) return null;

      final lastActiveDate = DateTime.fromMillisecondsSinceEpoch(lastActiveMs);
      final differenceInDays = DateTime.now().difference(lastActiveDate).inDays;

      // Nếu quá 30 ngày không mở app -> Bắt đăng nhập lại
      if (differenceInDays >= 30) {
        await clearUserSession();
        return null;
      }

      final userId = prefs.getString(_keyUserId);
      final userName = prefs.getString(_keyUserName);
      final userUsername = prefs.getString(_keyUserUsername) ?? '';
      final userEmail = prefs.getString(_keyUserEmail);
      final userRoleStr = prefs.getString(_keyUserRole);
      final userAvatar = prefs.getString(_keyUserAvatar) ?? '';

      if (userId == null || userEmail == null) return null;

      // Cập nhật lại thời gian hoạt động mới nhất
      await prefs.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);

      return AppUser(
        id: userId,
        name: userName ?? userEmail.split('@').first,
        username: userUsername,
        email: userEmail,
        role: userRoleStr == 'admin' ? UserRole.admin : UserRole.user,
        avatarUrl: userAvatar,
      );
    } catch (e) {
      debugPrint('Lỗi tải phiên người dùng: $e');
      return null;
    }
  }

  /// Cập nhật thông tin người dùng đã lưu
  static Future<void> updateSavedProfile({
    String? name,
    String? username,
    String? email,
    String? avatarUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name != null) await prefs.setString(_keyUserName, name);
      if (username != null) await prefs.setString(_keyUserUsername, username);
      if (email != null) await prefs.setString(_keyUserEmail, email);
      if (avatarUrl != null) await prefs.setString(_keyUserAvatar, avatarUrl);
      await prefs.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Lỗi cập nhật profile cục bộ: $e');
    }
  }

  /// Lưu mật khẩu Admin riêng
  static Future<void> saveAdminPassword(String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAdminPassword, password);
    } catch (e) {
      debugPrint('Lỗi lưu mật khẩu admin: $e');
    }
  }

  static Future<String> loadAdminPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAdminPassword) ?? 'admin';
    } catch (e) {
      return 'admin';
    }
  }

  /// Lưu tài khoản vào danh sách vĩnh viễn trên máy
  static Future<void> saveAccountCredentials(String email, String password, String name, bool isAdmin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString(_keySavedAccounts) ?? '{}';
      final Map<String, dynamic> map = jsonDecode(accountsJson);

      map[email.toLowerCase()] = {
        'email': email.toLowerCase(),
        'password': password,
        'name': name,
        'role': isAdmin ? 'admin' : 'user',
      };

      await prefs.setString(_keySavedAccounts, jsonEncode(map));
    } catch (e) {
      debugPrint('Lỗi lưu tài khoản: $e');
    }
  }

  /// Lấy toàn bộ danh sách tài khoản đã lưu
  static Future<Map<String, Map<String, dynamic>>> loadSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString(_keySavedAccounts) ?? '{}';
      final Map<String, dynamic> map = jsonDecode(accountsJson);
      final Map<String, Map<String, dynamic>> result = {};

      map.forEach((key, value) {
        if (value is Map) {
          result[key] = Map<String, dynamic>.from(value);
        }
      });
      return result;
    } catch (e) {
      return {};
    }
  }

  // ==========================================
  // OFFLINE-FIRST CACHE & PENDING QUEUE
  // ==========================================

  /// Lưu buổi chạy chưa đồng bộ (Pending sync)
  static Future<void> savePendingOfflineRun(RunSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString(_keyPendingRuns) ?? '[]';
      final List<dynamic> list = jsonDecode(listJson);

      final Map<String, dynamic> item = {
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

      // Tránh trùng lặp
      list.removeWhere((el) => el['id'] == session.id);
      list.add(item);

      await prefs.setString(_keyPendingRuns, jsonEncode(list));
    } catch (e) {
      debugPrint('Lỗi lưu offline pending run: $e');
    }
  }

  /// Tải danh sách buổi chạy đang chờ đồng bộ
  static Future<List<RunSession>> loadPendingOfflineRuns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString(_keyPendingRuns) ?? '[]';
      final List<dynamic> list = jsonDecode(listJson);

      final List<RunSession> sessions = [];
      for (final item in list) {
        sessions.add(
          RunSession(
            id: item['id'].toString(),
            userId: item['user_id'] ?? 'user_default',
            userName: item['user_name'] ?? 'Người chạy',
            startTime: DateTime.parse(item['start_time']),
            endTime: DateTime.parse(item['end_time']),
            durationSeconds: (item['duration_seconds'] as num?)?.toInt() ?? 0,
            distanceKm: (item['distance_km'] as num?)?.toDouble() ?? 0.0,
            calories: (item['calories'] as num?)?.toInt() ?? 0,
            notes: item['notes'] ?? '',
          ),
        );
      }
      return sessions;
    } catch (e) {
      debugPrint('Lỗi tải pending offline runs: $e');
      return [];
    }
  }

  /// Xóa buổi chạy đã đồng bộ thành công khỏi hàng đợi
  static Future<void> removePendingOfflineRun(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString(_keyPendingRuns) ?? '[]';
      final List<dynamic> list = jsonDecode(listJson);
      list.removeWhere((el) => el['id'] == id);
      await prefs.setString(_keyPendingRuns, jsonEncode(list));
    } catch (e) {
      debugPrint('Lỗi xóa pending offline run: $e');
    }
  }

  /// Cache toàn bộ lịch sử chạy bộ vào máy
  static Future<void> cacheAllRunSessions(List<RunSession> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> list = sessions.map((s) => {
        'id': s.id,
        'user_id': s.userId,
        'user_name': s.userName,
        'start_time': s.startTime.toIso8601String(),
        'end_time': s.endTime.toIso8601String(),
        'duration_seconds': s.durationSeconds,
        'distance_km': s.distanceKm,
        'calories': s.calories,
        'notes': s.notes,
      }).toList();

      await prefs.setString(_keyCachedSessions, jsonEncode(list));
    } catch (e) {
      debugPrint('Lỗi cache run sessions: $e');
    }
  }

  /// Tải lịch sử chạy bộ từ cache khi chưa có mạng
  static Future<List<RunSession>> loadCachedRunSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString(_keyCachedSessions) ?? '[]';
      final List<dynamic> list = jsonDecode(listJson);

      final List<RunSession> sessions = [];
      for (final item in list) {
        sessions.add(
          RunSession(
            id: item['id'].toString(),
            userId: item['user_id'] ?? 'user_default',
            userName: item['user_name'] ?? 'Người chạy',
            startTime: DateTime.parse(item['start_time']),
            endTime: DateTime.parse(item['end_time']),
            durationSeconds: (item['duration_seconds'] as num?)?.toInt() ?? 0,
            distanceKm: (item['distance_km'] as num?)?.toDouble() ?? 0.0,
            calories: (item['calories'] as num?)?.toInt() ?? 0,
            notes: item['notes'] ?? '',
          ),
        );
      }
      return sessions;
    } catch (e) {
      return [];
    }
  }

  /// Đăng xuất - Xóa phiên đăng nhập
  static Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keyUserUsername);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserRole);
      await prefs.remove(_keyUserAvatar);
      await prefs.remove(_keyRememberMe);
      await prefs.remove(_keyLastActive);
    } catch (e) {
      debugPrint('Lỗi xóa phiên: $e');
    }
  }
}
