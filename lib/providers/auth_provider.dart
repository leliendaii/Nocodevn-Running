import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class RegisteredAccount {
  final AppUser user;
  String password;

  RegisteredAccount({required this.user, required this.password});
}

class AuthProvider with ChangeNotifier {
  AppUser? _currentUser;
  String _adminPassword = 'admin'; // Mật khẩu mặc định của Admin

  // Danh sách tài khoản đã đăng ký trong hệ thống
  final Map<String, RegisteredAccount> _accounts = {};

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  String get adminPassword => _adminPassword;

  AuthProvider() {
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
  }

  void loginAsRunner() {
    _currentUser = const AppUser(
      id: 'runner_01',
      name: 'Vận Động Viên',
      email: 'runner@running.app',
      role: UserRole.user,
    );
    notifyListeners();
  }

  void loginAsAdmin() {
    _currentUser = _accounts['admin@running.app']?.user ??
        const AppUser(
          id: 'admin_01',
          name: 'Ban Quản Trị',
          email: 'admin@running.app',
          role: UserRole.admin,
        );
    notifyListeners();
  }

  /// Đăng ký tài khoản User mới
  String? register({
    required String name,
    required String email,
    required String password,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || name.trim().isEmpty || password.isEmpty) {
      return 'Vui lòng điền đầy đủ tất cả các trường thông tin.';
    }

    if (password.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }

    if (_accounts.containsKey(cleanEmail)) {
      return 'Email này đã được đăng ký trong hệ thống.';
    }

    final newUser = AppUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: cleanEmail,
      role: cleanEmail.contains('admin') ? UserRole.admin : UserRole.user,
    );

    _accounts[cleanEmail] = RegisteredAccount(
      user: newUser,
      password: password,
    );

    _currentUser = newUser;
    notifyListeners();
    return null; // Thành công (không có lỗi)
  }

  /// Đăng nhập
  String? login(String email, String password) {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || password.isEmpty) {
      return 'Vui lòng nhập đầy đủ Email và Mật khẩu.';
    }

    // Đăng nhập Admin nhanh với tài khoản admin@running.app hoặc email chứa chữ admin
    if (cleanEmail == 'admin@running.app' || cleanEmail == 'admin') {
      if (password == _adminPassword) {
        _currentUser = _accounts['admin@running.app']?.user ??
            const AppUser(
              id: 'admin_01',
              name: 'Ban Quản Trị',
              email: 'admin@running.app',
              role: UserRole.admin,
            );
        notifyListeners();
        return null;
      } else {
        return 'Mật khẩu Admin không chính xác!';
      }
    }

    if (!_accounts.containsKey(cleanEmail)) {
      return 'Tài khoản chưa tồn tại. Vui lòng chuyển sang tab Đăng ký!';
    }

    final account = _accounts[cleanEmail]!;
    if (account.password != password) {
      return 'Mật khẩu không chính xác. Vui lòng thử lại!';
    }

    _currentUser = account.user;
    notifyListeners();
    return null;
  }

  /// Đổi mật khẩu cho Admin hoặc User hiện tại
  String? changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    if (newPassword.length < 6) {
      return 'Mật khẩu mới phải có ít nhất 6 ký tự.';
    }

    if (_currentUser == null) return 'Chưa đăng nhập.';

    if (_currentUser!.isAdmin) {
      if (currentPassword != _adminPassword) {
        return 'Mật khẩu hiện tại không đúng.';
      }
      _adminPassword = newPassword;
      if (_accounts.containsKey('admin@running.app')) {
        _accounts['admin@running.app']!.password = newPassword;
      }
      notifyListeners();
      return null;
    } else {
      final email = _currentUser!.email.toLowerCase();
      if (_accounts.containsKey(email)) {
        if (_accounts[email]!.password != currentPassword) {
          return 'Mật khẩu hiện tại không đúng.';
        }
        _accounts[email]!.password = newPassword;
        notifyListeners();
        return null;
      }
    }
    return 'Lỗi không xác định.';
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
