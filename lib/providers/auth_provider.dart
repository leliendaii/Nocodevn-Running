import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // Khởi tạo người dùng mặc định cho phiên trải nghiệm
  AuthProvider() {
    loginAsRunner(); // Mặc định đăng nhập Runner để test ngay
  }

  void loginAsRunner() {
    _currentUser = const AppUser(
      id: 'runner_01',
      name: 'Nguyễn Văn Chạy',
      email: 'runner@running.app',
      role: UserRole.user,
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    );
    notifyListeners();
  }

  void loginAsAdmin() {
    _currentUser = const AppUser(
      id: 'admin_01',
      name: 'Ban Quản Trị',
      email: 'admin@running.app',
      role: UserRole.admin,
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    );
    notifyListeners();
  }

  bool login(String email, String password) {
    if (email.toLowerCase().contains('admin')) {
      loginAsAdmin();
      return true;
    } else if (email.isNotEmpty) {
      _currentUser = AppUser(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: email.split('@').first,
        email: email,
        role: UserRole.user,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
