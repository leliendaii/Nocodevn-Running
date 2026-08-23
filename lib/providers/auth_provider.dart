import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';

class RegisteredAccount {
  final AppUser user;
  String password;

  RegisteredAccount({required this.user, required this.password});
}

class AuthProvider with ChangeNotifier {
  AppUser? _currentUser;
  String _adminPassword = 'admin';
  bool _rememberMe = true; // Mặc định ghi nhớ đăng nhập

  final Map<String, RegisteredAccount> _accounts = {};

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  String get adminPassword => _adminPassword;
  bool get rememberMe => _rememberMe;

  set rememberMe(bool val) {
    _rememberMe = val;
    notifyListeners();
  }

  AuthProvider() {
    _initStorage();
  }

  Future<void> _initStorage() async {
    _adminPassword = await LocalStorageService.loadAdminPassword();

    // Khởi tạo tài khoản Admin mặc định
    _accounts['admin@running.app'] = RegisteredAccount(
      user: const AppUser(
        id: 'admin_01',
        name: 'Ban Quản Trị',
        email: 'admin@running.app',
        role: UserRole.admin,
      ),
      password: _adminPassword,
    );

    // Tải các tài khoản đã lưu cục bộ từ trước
    final savedAccounts = await LocalStorageService.loadSavedAccounts();
    savedAccounts.forEach((email, data) {
      _accounts[email] = RegisteredAccount(
        user: AppUser(
          id: 'user_${email.hashCode}',
          name: data['name'] ?? email.split('@').first,
          email: email,
          role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
        ),
        password: data['password'] ?? '',
      );
    });

    // Tự động khôi phục phiên đăng nhập (nếu đã bật ghi nhớ và trong vòng 30 ngày)
    final savedUser = await LocalStorageService.loadSavedUserSession();
    if (savedUser != null) {
      _currentUser = savedUser;
      notifyListeners();
    } else {
      _checkExistingSession();
    }
  }

  void _checkExistingSession() {
    final supaUser = SupabaseService.currentAuthUser;
    if (supaUser != null) {
      final meta = supaUser.userMetadata ?? {};
      final roleStr = meta['role'] as String? ?? (supaUser.email?.contains('admin') == true ? 'admin' : 'user');
      _currentUser = AppUser(
        id: supaUser.id,
        name: meta['name'] as String? ?? supaUser.email?.split('@').first ?? 'Người dùng',
        email: supaUser.email ?? '',
        role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
        avatarUrl: (meta['avatar_url'] as String?) ?? '',
      );
      notifyListeners();
    }
  }

  /// Đăng ký tài khoản User / Admin mới (Mật khẩu được băm và mã hóa trên Cloud)
  Future<String?> register({
    required String name,
    required String email,
    required String password,
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

    final isUserAdmin = cleanEmail.contains('admin');

    // Đăng ký trực tiếp lên Supabase Cloud với mật khẩu đã mã hóa băm chuẩn
    try {
      if (SupabaseService.isConfigured) {
        final res = await SupabaseService.signUp(
          email: cleanEmail,
          password: password,
          name: cleanName,
          role: isUserAdmin ? 'admin' : 'user',
        );

        if (res?.user != null) {
          final newUser = AppUser(
            id: res!.user!.id,
            name: cleanName,
            email: cleanEmail,
            role: isUserAdmin ? UserRole.admin : UserRole.user,
          );

          _accounts[cleanEmail] = RegisteredAccount(user: newUser, password: password);
          _currentUser = newUser;
          await LocalStorageService.saveUserSession(user: newUser, rememberMe: remember, password: password);
          notifyListeners();
          return null;
        }
      }
    } catch (e) {
      debugPrint('Supabase signup error (fallback to local): $e');
    }

    // Fallback lưu cục bộ nếu offline hoặc Supabase trả về lỗi
    if (_accounts.containsKey(cleanEmail)) {
      return 'Email này đã tồn tại trong hệ thống.';
    }

    final newUser = AppUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      email: cleanEmail,
      role: isUserAdmin ? UserRole.admin : UserRole.user,
    );

    _accounts[cleanEmail] = RegisteredAccount(user: newUser, password: password);
    _currentUser = newUser;
    await LocalStorageService.saveUserSession(user: newUser, rememberMe: remember, password: password);
    notifyListeners();
    return null;
  }

  /// Đăng nhập (Kiểm tra trên Supabase Cloud hoặc tài khoản hệ thống)
  Future<String?> login(String email, String password, {bool remember = true}) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || password.isEmpty) {
      return 'Vui lòng nhập đầy đủ Email và Mật khẩu.';
    }

    // Kiểm tra tài khoản Admin mặc định
    if ((cleanEmail == 'admin@running.app' || cleanEmail == 'admin') && password == _adminPassword) {
      _currentUser = _accounts['admin@running.app']?.user ??
          const AppUser(
            id: 'admin_01',
            name: 'Ban Quản Trị',
            email: 'admin@running.app',
            role: UserRole.admin,
          );
      await LocalStorageService.saveUserSession(user: _currentUser!, rememberMe: remember, password: password);
      notifyListeners();
      return null;
    }

    // Đăng nhập qua Supabase Cloud
    try {
      if (SupabaseService.isConfigured) {
        final res = await SupabaseService.signIn(email: cleanEmail, password: password);
        if (res?.user != null) {
          final meta = res!.user!.userMetadata ?? {};
          final roleStr = meta['role'] as String? ?? (cleanEmail.contains('admin') ? 'admin' : 'user');

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
      debugPrint('Supabase login error (fallback to local): $e');
    }

    // Fallback kiểm tra tài khoản cục bộ
    if (!_accounts.containsKey(cleanEmail)) {
      return 'Tài khoản hoặc mật khẩu không chính xác!';
    }

    final account = _accounts[cleanEmail]!;
    if (account.password != password) {
      return 'Mật khẩu không chính xác!';
    }

    _currentUser = account.user;
    await LocalStorageService.saveUserSession(user: _currentUser!, rememberMe: remember, password: password);
    notifyListeners();
    return null;
  }

  /// Đổi mật khẩu bền vững (Lưu trên cả Cloud và Máy)
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      return 'Mật khẩu mới phải có ít nhất 6 ký tự.';
    }

    if (_currentUser == null) return 'Chưa đăng nhập.';

    // Đổi mật khẩu trên Cloud
    if (SupabaseService.isConfigured) {
      await SupabaseService.changePassword(newPassword);
    }

    if (_currentUser!.isAdmin) {
      if (currentPassword != _adminPassword) {
        return 'Mật khẩu hiện tại không đúng.';
      }
      _adminPassword = newPassword;
      await LocalStorageService.saveAdminPassword(newPassword);
      if (_accounts.containsKey('admin@running.app')) {
        _accounts['admin@running.app']!.password = newPassword;
      }
      await LocalStorageService.saveAccountCredentials('admin@running.app', newPassword, _currentUser!.name, true);
      notifyListeners();
      return null;
    } else {
      final email = _currentUser!.email.toLowerCase();
      if (_accounts.containsKey(email)) {
        if (_accounts[email]!.password != currentPassword) {
          return 'Mật khẩu hiện tại không đúng.';
        }
        _accounts[email]!.password = newPassword;
        await LocalStorageService.saveAccountCredentials(email, newPassword, _currentUser!.name, false);
        notifyListeners();
        return null;
      }
    }
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
      SupabaseService.updateUserProfile(name: cleanName);
    }

    await LocalStorageService.updateSavedProfile(name: cleanName, email: cleanEmail);

    final oldEmail = _currentUser!.email.toLowerCase();
    if (_accounts.containsKey(oldEmail)) {
      final acc = _accounts.remove(oldEmail)!;
      _accounts[cleanEmail] = RegisteredAccount(user: updatedUser, password: acc.password);
      await LocalStorageService.saveAccountCredentials(cleanEmail, acc.password, cleanName, updatedUser.isAdmin);
    }

    _currentUser = updatedUser;
    notifyListeners();
    return null;
  }

  /// Cập nhật ảnh đại diện bền vững (Hỗ trợ Base64 từ điện thoại)
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

    final email = _currentUser!.email.toLowerCase();
    if (_accounts.containsKey(email)) {
      _accounts[email] = RegisteredAccount(
        user: updatedUser,
        password: _accounts[email]!.password,
      );
    }

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
