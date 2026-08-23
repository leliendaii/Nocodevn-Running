import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';

class AuthProvider with ChangeNotifier {
  AppUser? _currentUser;
  bool _rememberMe = true;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get rememberMe => _rememberMe;

  set rememberMe(bool val) {
    _rememberMe = val;
    notifyListeners();
  }

  AuthProvider() {
    _initAuth();
  }

  /// Khởi tạo và kiểm tra phiên đăng nhập trực tiếp với Supabase Server
  Future<void> _initAuth() async {
    // 1. Kiểm tra session trên server Supabase trước
    final serverUser = await SupabaseService.verifyServerSession();
    if (serverUser != null) {
      final meta = serverUser.userMetadata ?? {};
      final roleStr = meta['role'] as String? ?? 'user';

      _currentUser = AppUser(
        id: serverUser.id,
        name: meta['name'] as String? ?? serverUser.email?.split('@').first ?? 'Người dùng',
        email: serverUser.email ?? '',
        role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
        avatarUrl: (meta['avatar_url'] as String?) ?? '',
      );
      notifyListeners();
      return;
    }

    // 2. Nếu server không có session hoặc user đã bị xóa trên DB -> kiểm tra cache và xóa bỏ nếu không hợp lệ
    final savedUser = await LocalStorageService.loadSavedUserSession();
    if (savedUser != null) {
      // Xác thực lại với Server Supabase
      if (SupabaseService.isConfigured) {
        final verifiedUser = await SupabaseService.verifyServerSession();
        if (verifiedUser == null) {
          // Tài khoản đã bị xóa trên Supabase DB -> Đăng xuất ngay lập tức
          await LocalStorageService.clearUserSession();
          _currentUser = null;
          notifyListeners();
          return;
        }
      }
      _currentUser = savedUser;
      notifyListeners();
    }
  }

  /// Kiểm tra liên tục xem tài khoản có bị xóa trên Supabase DB không
  Future<bool> checkUserStillExistsOnServer() async {
    if (_currentUser == null) return false;
    if (!SupabaseService.isConfigured) return true;

    final serverUser = await SupabaseService.verifyServerSession();
    if (serverUser == null) {
      // User đã bị xóa trên Supabase DB -> Logout ngay!
      logout();
      return false;
    }

    // Cập nhật lại Role nếu admin đổi trên web Supabase
    final meta = serverUser.userMetadata ?? {};
    final roleStr = meta['role'] as String? ?? 'user';
    final newRole = roleStr == 'admin' ? UserRole.admin : UserRole.user;

    if (_currentUser!.role != newRole || _currentUser!.name != (meta['name'] ?? _currentUser!.name)) {
      _currentUser = AppUser(
        id: _currentUser!.id,
        name: meta['name'] as String? ?? _currentUser!.name,
        email: _currentUser!.email,
        role: newRole,
        avatarUrl: (meta['avatar_url'] as String?) ?? _currentUser!.avatarUrl,
      );
      await LocalStorageService.saveUserSession(user: _currentUser!, rememberMe: _rememberMe);
      notifyListeners();
    }

    return true;
  }

  /// Đăng ký tài khoản mới lên Supabase Cloud
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String role = 'user',
    bool remember = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();

    if (cleanEmail.isEmpty || cleanName.isEmpty || password.isEmpty) {
      return 'Vui lòng điền đầy đủ tất cả các trường thông tin.';
    }

    if (password.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }

    try {
      if (SupabaseService.isConfigured) {
        final res = await SupabaseService.signUp(
          email: cleanEmail,
          password: password,
          name: cleanName,
          role: role,
        );

        if (res?.user != null) {
          final newUser = AppUser(
            id: res!.user!.id,
            name: cleanName,
            email: cleanEmail,
            role: role == 'admin' ? UserRole.admin : UserRole.user,
          );

          _currentUser = newUser;
          await LocalStorageService.saveUserSession(user: newUser, rememberMe: remember, password: password);
          notifyListeners();
          return null;
        }
      }
    } catch (e) {
      debugPrint('Supabase signup error: $e');
      return 'Lỗi đăng ký: ${e.toString().replaceAll('Exception:', '').trim()}';
    }

    return 'Không thể kết nối đến máy chủ cơ sở dữ liệu Supabase.';
  }

  /// Đăng nhập (Xác thực trực tiếp 100% với Database Supabase)
  Future<String?> login(String email, String password, {bool remember = true}) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || password.isEmpty) {
      return 'Vui lòng nhập đầy đủ Email và Mật khẩu.';
    }

    // Đăng nhập trực tiếp với Supabase Cloud
    try {
      if (SupabaseService.isConfigured) {
        final res = await SupabaseService.signIn(email: cleanEmail, password: password);
        if (res?.user != null) {
          final meta = res!.user!.userMetadata ?? {};
          final roleStr = meta['role'] as String? ?? 'user';

          _currentUser = AppUser(
            id: res.user!.id,
            name: meta['name'] as String? ?? cleanEmail.split('@').first,
            email: cleanEmail,
            role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
            avatarUrl: (meta['avatar_url'] as String?) ?? '',
          );
          await LocalStorageService.saveUserSession(user: _currentUser!, rememberMe: remember, password: password);
          notifyListeners();
          return null;
        }
      }
    } catch (e) {
      debugPrint('Supabase login error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('invalid login credentials') || errStr.contains('user not found')) {
        return 'Tài khoản không tồn tại hoặc sai mật khẩu!';
      }
      return 'Lỗi đăng nhập: ${e.toString().replaceAll('Exception:', '').trim()}';
    }

    return 'Tài khoản hoặc mật khẩu không chính xác!';
  }

  /// Đổi mật khẩu bền vững trên Cloud
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      return 'Mật khẩu mới phải có ít nhất 6 ký tự.';
    }

    if (_currentUser == null) return 'Chưa đăng nhập.';

    if (SupabaseService.isConfigured) {
      final success = await SupabaseService.changePassword(newPassword);
      if (!success) {
        return 'Không thể đổi mật khẩu trên máy chủ Supabase.';
      }
    }

    notifyListeners();
    return null;
  }

  /// Cập nhật Họ tên và Email bền vững
  Future<String?> updateProfile({
    required String newName,
    required String newEmail,
  }) async {
    final cleanName = newName.trim();
    final cleanEmail = newEmail.trim().toLowerCase();

    if (cleanName.isEmpty || cleanEmail.isEmpty) {
      return 'Họ tên và Email không được để trống.';
    }

    if (_currentUser == null) return 'Chưa đăng nhập.';

    final updatedUser = AppUser(
      id: _currentUser!.id,
      name: cleanName,
      email: cleanEmail,
      role: _currentUser!.role,
      avatarUrl: _currentUser!.avatarUrl,
    );

    if (SupabaseService.isConfigured) {
      await SupabaseService.updateUserProfile(name: cleanName);
    }

    await LocalStorageService.updateSavedProfile(name: cleanName, email: cleanEmail);
    _currentUser = updatedUser;
    notifyListeners();
    return null;
  }

  /// Cập nhật ảnh đại diện bền vững
  void updateAvatar(String newAvatarUrl) {
    if (_currentUser == null) return;

    final updatedUser = AppUser(
      id: _currentUser!.id,
      name: _currentUser!.name,
      email: _currentUser!.email,
      role: _currentUser!.role,
      avatarUrl: newAvatarUrl,
    );

    if (SupabaseService.isConfigured) {
      SupabaseService.updateUserProfile(avatarUrl: newAvatarUrl);
    }

    LocalStorageService.updateSavedProfile(avatarUrl: newAvatarUrl);
    _currentUser = updatedUser;
    notifyListeners();
  }

  void logout() {
    SupabaseService.signOut();
    LocalStorageService.clearUserSession();
    _currentUser = null;
    notifyListeners();
  }
}
