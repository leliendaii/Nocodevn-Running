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
      final profile = await SupabaseService.fetchProfile(
        _currentUser!.id,
        _currentUser!.email,
        _currentUser!.username,
      );
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

  /// Đồng bộ thông tin quyền hạn và dữ liệu mới nhất từ Cloud một cách an toàn
  Future<bool> checkUserStillExistsOnServer() async {
    if (_currentUser == null) return false;
    await refreshProfileFromServer();
    return true;
  }

  /// Bước 1: Gửi yêu cầu đăng ký lên Supabase (Gửi OTP qua Email thực tế)
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
          // Nếu Supabase trả về session ngay (trường hợp confirm email tắt)
          if (res?.session != null) {
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
          }
          return null; // Thành công gửi OTP về Email
        }
      }
    } catch (e) {
      debugPrint('Supabase signup error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('unique') || errStr.contains('already exists') || errStr.contains('already registered')) {
        return 'Email hoặc Tên đăng nhập này đã được sử dụng!';
      }
      return 'Lỗi đăng ký: ${e.toString().replaceAll('Exception:', '').trim()}';
    }

    return 'Không thể kết nối đến máy chủ cơ sở dữ liệu Supabase.';
  }

  /// Bước 2: Xác thực mã OTP gửi về Email để kích hoạt tài khoản
  Future<String?> verifyOtpAndActivate({
    required String email,
    required String token,
    required String name,
    required String username,
    required String password,
    bool remember = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');
    final cleanName = name.trim();

    try {
      final res = await SupabaseService.verifyEmailOtp(
        email: cleanEmail,
        token: token.trim(),
      );

      final user = res.user;
      if (user != null) {
        // Cập nhật bảng profiles
        await SupabaseService.updateProfileTable(
          user.id,
          name: cleanName,
          username: cleanUsername,
          email: cleanEmail,
        );

        final profile = await SupabaseService.fetchProfile(user.id, cleanEmail);
        final roleStr = SupabaseService.extractRole(user, profile);

        final appUser = AppUser(
          id: user.id,
          name: cleanName.isNotEmpty ? cleanName : (profile?['name'] ?? cleanEmail.split('@').first),
          username: cleanUsername.isNotEmpty ? cleanUsername : (profile?['username'] ?? ''),
          email: cleanEmail,
          role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
          avatarUrl: profile?['avatar_url'] ?? '',
        );

        _currentUser = appUser;
        await LocalStorageService.saveUserSession(user: appUser, rememberMe: remember, password: password);
        notifyListeners();
        return null;
      }
    } catch (e) {
      debugPrint('Lỗi verify OTP: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('invalid') || errStr.contains('expired') || errStr.contains('token')) {
        return 'Mã OTP không chính xác hoặc đã hết hạn!';
      }
      return 'Lỗi xác thực: ${e.toString().replaceAll('Exception:', '').trim()}';
    }

    return 'Không thể xác thực mã OTP.';
  }

  /// Gửi lại mã OTP qua Email thực tế
  Future<String?> resendOtp(String email) async {
    try {
      await SupabaseService.resendEmailOtp(email: email);
      return null;
    } catch (e) {
      debugPrint('Lỗi gửi lại OTP: $e');
      return 'Lỗi gửi lại mã: ${e.toString().replaceAll('Exception:', '').trim()}';
    }
  }

  /// Đăng nhập (Hỗ trợ nhập Email HOẶC Username)
  Future<String?> login(String identifier, String password, {bool remember = true}) async {
    final cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty || password.isEmpty) {
      return 'Vui lòng nhập Email/Tên đăng nhập và Mật khẩu.';
    }

    try {
      if (SupabaseService.isConfigured) {
        final res = await SupabaseService.signIn(identifier: cleanIdentifier, password: password);
        final u = res?.user;
        if (u != null) {
          final profile = await SupabaseService.fetchProfile(u.id, u.email, cleanIdentifier);
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
      if (errStr.contains('không tồn tại') || errStr.contains('tên đăng nhập')) {
        return e.toString().replaceAll('Exception:', '').trim();
      }
      if (errStr.contains('email not confirmed')) {
        return 'Tài khoản chưa được kích hoạt qua Email! Vui lòng nhập mã OTP để kích hoạt.';
      }
      if (errStr.contains('invalid login credentials') || errStr.contains('user not found') || errStr.contains('invalid_credentials')) {
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
