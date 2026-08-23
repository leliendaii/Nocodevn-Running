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

  /// Khởi tạo và kiểm tra phiên đăng nhập trực tiếp với Supabase Server & Bảng profiles
  Future<void> _initAuth() async {
    // 1. Kiểm tra session trên server Supabase trước
    final serverUser = await SupabaseService.verifyServerSession();
    if (serverUser != null) {
      final profile = await SupabaseService.fetchProfile(serverUser.id, serverUser.email);
      final roleStr = SupabaseService.extractRole(serverUser, profile);
      final displayName = profile?['name'] ?? serverUser.userMetadata?['name'] ?? serverUser.email?.split('@').first ?? 'Người dùng';
      final username = profile?['username'] ?? serverUser.userMetadata?['username'] ?? '';
      final avatar = profile?['avatar_url'] ?? serverUser.userMetadata?['avatar_url'] ?? '';

      _currentUser = AppUser(
        id: serverUser.id,
        name: displayName,
        username: username,
        email: serverUser.email ?? '',
        role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
        avatarUrl: avatar,
      );
      await LocalStorageService.saveUserSession(user: _currentUser!, rememberMe: _rememberMe);
      notifyListeners();
      return;
    }

    // 2. Nếu server không có session hoặc user đã bị xóa trên DB -> kiểm tra cache và xóa bỏ nếu không hợp lệ
    final savedUser = await LocalStorageService.loadSavedUserSession();
    if (savedUser != null) {
      _currentUser = savedUser;
      notifyListeners();
      await refreshProfileFromServer();
    }
  }

  /// Làm mới thông tin quyền Admin và Profile trực tiếp từ Server Supabase
  Future<void> refreshProfileFromServer() async {
    if (_currentUser == null || !SupabaseService.isConfigured) return;

    try {
      final profile = await SupabaseService.fetchProfile(_currentUser!.id, _currentUser!.email);
      if (profile != null) {
        final roleStr = (profile['role'] as String?)?.toLowerCase().trim() ?? 'user';
        final newRole = roleStr == 'admin' ? UserRole.admin : UserRole.user;
        final displayName = profile['name'] as String? ?? _currentUser!.name;
        final username = profile['username'] as String? ?? _currentUser!.username;
        final avatar = profile['avatar_url'] as String? ?? _currentUser!.avatarUrl;

        _currentUser = AppUser(
          id: _currentUser!.id,
          name: displayName,
          username: username,
          email: _currentUser!.email,
          role: newRole,
          avatarUrl: avatar,
        );
        await LocalStorageService.saveUserSession(user: _currentUser!, rememberMe: _rememberMe);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Lỗi làm mới profile: $e');
    }
  }

  /// Kiểm tra liên tục xem tài khoản có bị xóa hoặc được nâng cấp Admin trên Supabase DB không
  Future<bool> checkUserStillExistsOnServer() async {
    if (_currentUser == null) return false;
    if (!SupabaseService.isConfigured) return true;

    final serverUser = await SupabaseService.verifyServerSession();
    if (serverUser == null) {
      // User đã bị xóa trên Supabase DB -> Logout ngay!
      logout();
      return false;
    }

    // Cập nhật lại Role và Username từ bảng profiles trên web Supabase
    final profile = await SupabaseService.fetchProfile(serverUser.id, serverUser.email);
    final roleStr = SupabaseService.extractRole(serverUser, profile);
    final newRole = roleStr == 'admin' ? UserRole.admin : UserRole.user;
    final displayName = profile?['name'] ?? serverUser.userMetadata?['name'] ?? _currentUser!.name;
    final username = profile?['username'] ?? serverUser.userMetadata?['username'] ?? _currentUser!.username;
    final avatar = profile?['avatar_url'] ?? _currentUser!.avatarUrl;

    if (_currentUser!.role != newRole || _currentUser!.name != displayName || _currentUser!.username != username || _currentUser!.avatarUrl != avatar) {
      _currentUser = AppUser(
        id: _currentUser!.id,
        name: displayName,
        username: username,
        email: _currentUser!.email,
        role: newRole,
        avatarUrl: avatar,
      );
      await LocalStorageService.saveUserSession(user: _currentUser!, rememberMe: _rememberMe);
      notifyListeners();
    }

    return true;
  }

  /// Đăng ký tài khoản mới lên Supabase Cloud (Hỗ trợ Username)
  Future<String?> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String role = 'user',
    bool remember = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');
    final cleanName = name.trim();

    if (cleanEmail.isEmpty || cleanUsername.isEmpty || cleanName.isEmpty || password.isEmpty) {
      return 'Vui lòng điền đầy đủ tất cả các trường thông tin.';
    }

    if (cleanUsername.length < 3) {
      return 'Tên đăng nhập (Username) phải có ít nhất 3 ký tự.';
    }

    if (password.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }

    try {
      if (SupabaseService.isConfigured) {
        final res = await SupabaseService.signUp(
          email: cleanEmail,
          username: cleanUsername,
          password: password,
          name: cleanName,
          role: role,
        );

        if (res?.user != null) {
          final newUser = AppUser(
            id: res!.user!.id,
            name: cleanName,
            username: cleanUsername,
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
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('unique') || errStr.contains('already exists')) {
        return 'Email hoặc Tên đăng nhập này đã được sử dụng!';
      }
      return 'Lỗi đăng ký: ${e.toString().replaceAll('Exception:', '').trim()}';
    }

    return 'Không thể kết nối đến máy chủ cơ sở dữ liệu Supabase.';
  }

  /// Đăng nhập (Hỗ trợ nhập Email HOẶC Username)
  Future<String?> login(String identifier, String password, {bool remember = true}) async {
    final cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty || password.isEmpty) {
      return 'Vui lòng nhập Email/Tên đăng nhập và Mật khẩu.';
    }

    // Đăng nhập trực tiếp với Supabase Cloud
    try {
      if (SupabaseService.isConfigured) {
        final res = await SupabaseService.signIn(identifier: cleanIdentifier, password: password);
        final u = res?.user;
        if (u != null) {
          final profile = await SupabaseService.fetchProfile(u.id);
          final roleStr = SupabaseService.extractRole(u, profile);
          final displayName = profile?['name'] ?? u.userMetadata?['name'] ?? cleanIdentifier.split('@').first;
          final username = profile?['username'] ?? u.userMetadata?['username'] ?? cleanIdentifier;
          final avatar = profile?['avatar_url'] ?? u.userMetadata?['avatar_url'] ?? '';

          _currentUser = AppUser(
            id: u.id,
            name: displayName,
            username: username,
            email: u.email ?? cleanIdentifier,
            role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
            avatarUrl: avatar,
          );
          await LocalStorageService.saveUserSession(user: _currentUser!, rememberMe: remember, password: password);
          notifyListeners();
          return null;
        }
      }
    } catch (e) {
      debugPrint('Supabase login error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('không tồn tại')) {
        return e.toString().replaceAll('Exception:', '').trim();
      }
      if (errStr.contains('invalid login credentials') || errStr.contains('user not found')) {
        return 'Tên đăng nhập/Email hoặc mật khẩu không chính xác!';
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

  /// Cập nhật Họ tên, Username và Email bền vững
  Future<String?> updateProfile({
    required String newName,
    required String newUsername,
    required String newEmail,
  }) async {
    final cleanName = newName.trim();
    final cleanUsername = newUsername.trim().toLowerCase().replaceAll('@', '');
    final cleanEmail = newEmail.trim().toLowerCase();

    if (cleanName.isEmpty || cleanEmail.isEmpty) {
      return 'Họ tên và Email không được để trống.';
    }

    if (_currentUser == null) return 'Chưa đăng nhập.';

    final updatedUser = AppUser(
      id: _currentUser!.id,
      name: cleanName,
      username: cleanUsername,
      email: cleanEmail,
      role: _currentUser!.role,
      avatarUrl: _currentUser!.avatarUrl,
    );

    if (SupabaseService.isConfigured) {
      await SupabaseService.updateUserProfile(
        name: cleanName,
        username: cleanUsername,
        userId: _currentUser!.id,
      );
    }

    await LocalStorageService.updateSavedProfile(name: cleanName, username: cleanUsername, email: cleanEmail);
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
      username: _currentUser!.username,
      email: _currentUser!.email,
      role: _currentUser!.role,
      avatarUrl: newAvatarUrl,
    );

    if (SupabaseService.isConfigured) {
      SupabaseService.updateUserProfile(avatarUrl: newAvatarUrl, userId: _currentUser!.id);
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
