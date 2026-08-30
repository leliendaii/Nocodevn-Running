import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/dialogs/otp_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;
  bool _isLoading = false;

  // Controllers cho Đăng nhập (Hỗ trợ cả Email & Username)
  final _loginIdentifierController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Controllers cho Đăng ký
  final _regNameController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  bool _obscurePassword = true;

  // Quản lý trạng thái OTP & Rate limiting
  int _resendAttempts = 0;
  DateTime? _lockUntil;

  @override
  void dispose() {
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _loginIdentifierController.text.trim();
    final password = _loginPasswordController.text.trim();

    setState(() => _isLoading = true);
    final error = await context.read<AuthProvider>().login(identifier, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      TopSyncToast.show(
        context,
        message: error,
        isSuccess: false,
      );
    }
  }

  Future<void> _onRegisterSubmit() async {
    final name = _regNameController.text.trim();
    final username = _regUsernameController.text.trim();
    final email = _regEmailController.text.trim();
    final pass = _regPasswordController.text.trim();
    final confirmPass = _regConfirmPasswordController.text.trim();

    if (name.isEmpty || username.isEmpty || email.isEmpty || pass.isEmpty) {
      TopSyncToast.show(
        context,
        message: 'Vui lòng điền đầy đủ tất cả các trường!',
        isSuccess: false,
      );
      return;
    }

    if (username.length < 3) {
      TopSyncToast.show(
        context,
        message: 'Tên đăng nhập phải có ít nhất 3 ký tự!',
        isSuccess: false,
      );
      return;
    }

    if (pass.length < 6) {
      TopSyncToast.show(
        context,
        message: 'Mật khẩu phải có ít nhất 6 ký tự!',
        isSuccess: false,
      );
      return;
    }

    if (pass != confirmPass) {
      TopSyncToast.show(
        context,
        message: 'Mật khẩu xác nhận không trùng khớp!',
        isSuccess: false,
      );
      return;
    }

    // Kiểm tra khóa chống spam 1 tiếng
    if (_lockUntil != null) {
      if (DateTime.now().isBefore(_lockUntil!)) {
        final remainingMinutes = _lockUntil!.difference(DateTime.now()).inMinutes + 1;
        TopSyncToast.show(
          context,
          message: '⚠️ Quá 5 lần gửi! Vui lòng thử lại sau $remainingMinutes phút.',
          isSuccess: false,
        );
        return;
      } else {
        _lockUntil = null;
        _resendAttempts = 0;
      }
    }

    if (_resendAttempts >= 5) {
      _lockUntil = DateTime.now().add(const Duration(hours: 1));
      TopSyncToast.show(
        context,
        message: '⛔ Đã gửi quá 5 lần! Tạm khóa gửi OTP trong 1 tiếng.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    // Gửi yêu cầu đăng ký lên Supabase và gửi OTP về Email
    final error = await context.read<AuthProvider>().register(
      name: name,
      username: username,
      email: email,
      password: pass,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      TopSyncToast.show(context, message: error, isSuccess: false);
      return;
    }

    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      TopSyncToast.show(context, message: '🎉 Đăng ký thành công! Đang vào ứng dụng...', isSuccess: true);
      return;
    }

    // Mở popup nhập mã OTP gửi về Email
    _resendAttempts++;
    _showOtpModalPopup();
  }

  // Hiển thị Popup xác thực mã OTP & Resend
  void _showOtpModalPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => OtpVerificationDialog(
        name: _regNameController.text.trim(),
        username: _regUsernameController.text.trim(),
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text.trim(),
        initialAttempts: _resendAttempts,
        onAttemptIncrement: () => _resendAttempts++,
        onLock: (lockTime) => _lockUntil = lockTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Tiêu đề ứng dụng
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryNeon.withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.directions_run_rounded,
                            size: 48,
                            color: AppTheme.primaryNeon,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'NOCODE RUNNING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: AppTheme.primaryNeon,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegisterMode ? 'Tạo tài khoản người dùng mới' : 'Đăng nhập hệ thống theo dõi chạy bộ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // Tab chuyển đổi: ĐĂNG NHẬP / ĐĂNG KÝ
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegisterMode = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isRegisterMode ? AppTheme.primaryNeon : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ĐĂNG NHẬP',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !_isRegisterMode ? Colors.white : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegisterMode = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isRegisterMode ? AppTheme.primaryNeon : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ĐĂNG KÝ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isRegisterMode ? Colors.white : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // FORM ĐĂNG NHẬP (Hỗ trợ nhập Email HOẶC Username)
                if (!_isRegisterMode) ...[
                  TextField(
                    controller: _loginIdentifierController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Email hoặc Tên đăng nhập (Username)',
                      hintText: 'Nhập username (ví dụ: admin, liendai) hoặc email',
                      prefixIcon: Icon(Icons.alternate_email_rounded, color: AppTheme.primaryNeon),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _loginPasswordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      hintText: 'Nhập mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryNeon),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: context.watch<AuthProvider>().rememberMe,
                        activeColor: AppTheme.primaryNeon,
                        onChanged: (val) {
                          context.read<AuthProvider>().rememberMe = val ?? true;
                        },
                      ),
                      const Text(
                        'Ghi nhớ đăng nhập (30 ngày)',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('ĐĂNG NHẬP'),
                  ),
                ]

                // FORM ĐĂNG KÝ
                else ...[
                  TextField(
                    controller: _regNameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên người dùng',
                      hintText: 'Nhập họ và tên',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryNeon),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _regUsernameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập (Username)',
                      hintText: 'Ví dụ: liendai, runner01, admin...',
                      prefixIcon: Icon(Icons.alternate_email_rounded, color: AppTheme.secondaryNeon),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _regEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Email đăng ký (Nhận mã OTP)',
                      hintText: 'Nhập email để nhận mã OTP xác thực',
                      prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryNeon),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _regPasswordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu (ít nhất 6 ký tự)',
                      hintText: 'Nhập mật khẩu mới',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryNeon),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _regConfirmPasswordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận lại mật khẩu',
                      hintText: 'Nhập lại mật khẩu',
                      prefixIcon: Icon(Icons.lock_reset_rounded, color: AppTheme.primaryNeon),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _onRegisterSubmit,
                    child: _isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('ĐĂNG KÝ'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
