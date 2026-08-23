import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;

  // Controllers cho Đăng nhập
  final _loginEmailController = TextEditingController(text: 'admin@running.app');
  final _loginPasswordController = TextEditingController(text: 'admin');

  // Controllers cho Đăng ký
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    final error = context.read<AuthProvider>().login(email, password);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(error),
        ),
      );
    }
  }

  void _handleRegister() {
    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final pass = _regPasswordController.text.trim();
    final confirmPass = _regConfirmPasswordController.text.trim();

    if (pass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Mật khẩu xác nhận không trùng khớp!'),
        ),
      );
      return;
    }

    final error = context.read<AuthProvider>().register(
      name: name,
      email: email,
      password: pass,
    );

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(error),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('🎉 Đăng ký tài khoản thành công! Đang đăng nhập...'),
        ),
      );
    }
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
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryNeon.withValues(alpha: 0.2),
                          blurRadius: 25,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_run_rounded,
                      size: 48,
                      color: AppTheme.primaryNeon,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'RUN TRACKER PRO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: AppTheme.textPrimary,
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
                                color: !_isRegisterMode ? Colors.black : AppTheme.textSecondary,
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
                                color: _isRegisterMode ? Colors.black : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // FORM ĐĂNG NHẬP
                if (!_isRegisterMode) ...[
                  TextField(
                    controller: _loginEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'admin@running.app hoặc email của bạn',
                      prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryNeon),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _loginPasswordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _handleLogin,
                    child: const Text('ĐĂNG NHẬP'),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.secondaryNeon, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tài khoản Admin mặc định: admin@running.app\nMật khẩu mặc định: admin',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]

                // FORM ĐĂNG KÝ
                else ...[
                  TextField(
                    controller: _regNameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên người dùng',
                      hintText: 'Nguyễn Văn A',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryNeon),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _regEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Email đăng ký',
                      hintText: 'user@gmail.com',
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
                      prefixIcon: Icon(Icons.lock_reset_rounded, color: AppTheme.primaryNeon),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _handleRegister,
                    child: const Text('TẠO TÀI KHOẢN VÀ BẮT ĐẦU'),
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
