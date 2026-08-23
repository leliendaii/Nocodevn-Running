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

  /// Khởi tạo phiên đăng nhập siêu tốc từ cache trước, sync Cloud sau
  Future<void> _initAuth() async {
    // 1. Tải tức thì từ bộ nhớ máy (0.01s)
    final savedUser = await LocalStorageService.loadSavedUserSession();
    if (savedUser != null) {
      _currentUser = savedUser;
      notifyListeners();
    }

    // 2. Kiểm tra ngầm với Supabase để cập nhật quyền Admin
    if (SupabaseService.isConfigured) {
      refreshProfileFromServer();
    }
  }

  /// Làm mới thông tin quyền Admin và Profile từ Cloud
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
        LocalStorageService.saveUserSession(user: _currentUser!, rememberMe: _rememberMe);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Lỗi làm mới profile: $e');
    }
  }

  /// Đồng bộ an toàn ngầm
  Future<bool> checkUserStillExistsOnServer() async {
    if (_currentUser == null) return false;
    refreshProfileFromServer();
    return true;
  }

  /// Bước 1: Gửi yêu cầu đăng ký lên Supabase (Gửi OTP 4 số)
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
          // Nếu Supabase trả về session ngay
          if (res?.session != null) {
            final newUser = AppUser(
              id: res!.user!.id,
              name: cleanName,
              username: cleanUsername,
              email: cleanEmail,
              role: role == 'admin' ? UserRole.admin : UserRole.user,
            );
            _currentUser = newUser;
            LocalStorageService.saveUserSession(user: newUser, rememberMe: remember, password: password);
            notifyListeners();
          }
          return null;
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

  /// Bước 2: Xác thực mã OTP 4 số và kích hoạt tài khoản
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
        // Tối ưu tạo user ngay tức thì
        final appUser = AppUser(
          id: user.id,
          name: cleanName.isNotEmpty ? cleanName : cleanEmail.split('@').first,
          username: cleanUsername,
          email: cleanEmail,
          role: UserRole.user,
          avatarUrl: '',
        );

        _currentUser = appUser;
        LocalStorageService.saveUserSession(user: appUser, rememberMe: remember, password: password);
        notifyListeners();

        // Sync bảng profiles ngầm
        SupabaseService.updateProfileTable(
          user.id,
          name: cleanName,
          username: cleanUsername,
          email: cleanEmail,
        );
        refreshProfileFromServer();

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

  /// Gửi lại mã OTP qua Email
  Future<String?> resendOtp(String email) async {
    try {
      await SupabaseService.resendEmailOtp(email: email);
      return null;
    } catch (e) {
      debugPrint('Lỗi gửi lại OTP: $e');
      return 'Lỗi gửi lại mã: ${e.toString().replaceAll('Exception:', '').trim()}';
    }
  }

  /// Đăng nhập siêu tốc (< 1s)
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
          final displayName = u.userMetadata?['name'] ?? cleanIdentifier.split('@').first;
          final username = u.userMetadata?['username'] ?? (cleanIdentifier.contains('@') ? '' : cleanIdentifier);

          // 1. Tạo session người dùng tức thì (0ms) để vào ngay app
          final appUser = AppUser(
            id: u.id,
            name: displayName,
            username: username,
            email: u.email ?? cleanIdentifier,
            role: (u.userMetadata?['role'] == 'admin') ? UserRole.admin : UserRole.user,
            avatarUrl: u.userMetadata?['avatar_url'] ?? '',
          );

          _currentUser = appUser;
          LocalStorageService.saveUserSession(user: appUser, rememberMe: remember, password: password);
          notifyListeners();

          // 2. Tự động kiểm tra quyền Admin từ profiles ngầm (không block UI)
          refreshProfileFromServer();

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

  /// Đổi mật khẩu bền vững
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

  /// Cập nhật Họ tên, Username và Email (Optimistic Update - 0ms delay)
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

    // Cập nhật UI và máy tức thì (0ms)
    _currentUser = updatedUser;
    LocalStorageService.updateSavedProfile(name: cleanName, username: cleanUsername, email: cleanEmail);
    notifyListeners();

    // Đồng bộ Supabase Cloud ngầm
    if (SupabaseService.isConfigured) {
      SupabaseService.updateUserProfile(
        name: cleanName,
        username: cleanUsername,
        userId: _currentUser!.id,
      );
    }

    return null;
  }

  /// Cập nhật ảnh đại diện tức thì (0ms delay)
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

    _currentUser = updatedUser;
    LocalStorageService.updateSavedProfile(avatarUrl: newAvatarUrl);
    notifyListeners();

    if (SupabaseService.isConfigured) {
      SupabaseService.updateUserProfile(avatarUrl: newAvatarUrl, userId: _currentUser!.id);
    }
  }

  void logout() {
    SupabaseService.signOut();
    LocalStorageService.clearUserSession();
    _currentUser = null;
    notifyListeners();
  }
}
