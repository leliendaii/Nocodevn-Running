import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class LocalStorageService {
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserName = 'auth_user_name';
  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserRole = 'auth_user_role';
  static const String _keyUserAvatar = 'auth_user_avatar';
  static const String _keyRememberMe = 'auth_remember_me';
  static const String _keyLastActive = 'auth_last_active';
  static const String _keyAdminPassword = 'auth_admin_password';
  static const String _keySavedAccounts = 'auth_saved_accounts';

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
      final userEmail = prefs.getString(_keyUserEmail);
      final userRoleStr = prefs.getString(_keyUserRole);
      final userAvatar = prefs.getString(_keyUserAvatar) ?? '';

      if (userId == null || userEmail == null) return null;

      // Cập nhật lại thời gian hoạt động mới nhất
      await prefs.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);

      return AppUser(
        id: userId,
        name: userName ?? userEmail.split('@').first,
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
    String? email,
    String? avatarUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name != null) await prefs.setString(_keyUserName, name);
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

  /// Đăng xuất - Xóa phiên đăng nhập
  static Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserName);
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
