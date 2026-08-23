import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;

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

  // ==========================================
  // LOGIC XÁC THỰC MÃ OTP 4 SỐ (RATE LIMITING)
  // ==========================================
  bool _isVerifyingOtp = false;
  String _generatedOtp = '';
  int _otpCountdown = 60; // Sống trong 1 phút
  Timer? _otpTimer;
  int _resendAttempts = 0; // Đếm số lần gửi
  DateTime? _lockUntil; // Thời gian mở khóa nếu quá 5 lần (1 tiếng)

  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    _otpTimer?.cancel();
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // Khởi tạo và gửi mã OTP 4 số
  void _startOtpVerification() {
    // Kiểm tra xem có đang bị khóa 1 tiếng do gửi quá 5 lần không
    if (_lockUntil != null) {
      if (DateTime.now().isBefore(_lockUntil!)) {
        final remainingMinutes = _lockUntil!.difference(DateTime.now()).inMinutes + 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('⚠️ Bạn đã yêu cầu gửi mã quá 5 lần! Vui lòng thử lại sau $remainingMinutes phút.'),
          ),
        );
        return;
      } else {
        // Hết thời gian phạt 1 tiếng -> Reset lại số lần đếm
        _lockUntil = null;
        _resendAttempts = 0;
      }
    }

    if (_resendAttempts >= 5) {
      _lockUntil = DateTime.now().add(const Duration(hours: 1));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('⛔ Bạn đã gửi mã quá 5 lần! Hệ thống tạm khóa gửi OTP trong 1 tiếng.'),
        ),
      );
      return;
    }

    _resendAttempts++;

    // Tạo mã OTP 4 chữ số ngẫu nhiên (1000 - 9999)
    final random = Random();
    _generatedOtp = (1000 + random.nextInt(9000)).toString();

    for (var c in _otpControllers) {
      c.clear();
    }

    setState(() {
      _isVerifyingOtp = true;
      _otpCountdown = 60;
    });

    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown > 0) {
        setState(() => _otpCountdown--);
      } else {
        timer.cancel();
      }
    });

    // Thông báo mã OTP gửi về Email
    TopSyncToast.show(
      context,
      message: 'Mã OTP của bạn: $_generatedOtp (Hết hạn sau 60s)',
      duration: const Duration(seconds: 10),
    );
  }

  // Xác thực mã OTP và kích hoạt tài khoản
  Future<void> _verifyOtpAndActivate() async {
    final enteredOtp = _otpControllers.map((c) => c.text.trim()).join();

    if (enteredOtp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Vui lòng nhập đủ 4 chữ số mã OTP!'),
        ),
      );
      return;
    }

    if (_otpCountdown <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('⏱️ Mã OTP đã hết hạn 1 phút! Vui lòng bấm "Gửi lại mã mới".'),
        ),
      );
      return;
    }

    if (enteredOtp != _generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('❌ Mã OTP không chính xác! Vui lòng kiểm tra lại.'),
        ),
      );
      return;
    }

    // Mã OTP chính xác -> Tiến hành kích hoạt và tạo tài khoản chính thức
    final name = _regNameController.text.trim();
    final username = _regUsernameController.text.trim();
    final email = _regEmailController.text.trim();
    final pass = _regPasswordController.text.trim();

    final error = await context.read<AuthProvider>().register(
      name: name,
      username: username,
      email: email,
      password: pass,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(error),
        ),
      );
    } else {
      _otpTimer?.cancel();
      setState(() => _isVerifyingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('🎉 Xác thực OTP thành công! Tài khoản đã được kích hoạt.'),
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    final identifier = _loginIdentifierController.text.trim();
    final password = _loginPasswordController.text.trim();

    final error = await context.read<AuthProvider>().login(identifier, password);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(error),
        ),
      );
    }
  }

  void _onRegisterSubmit() {
    final name = _regNameController.text.trim();
    final username = _regUsernameController.text.trim();
    final email = _regEmailController.text.trim();
    final pass = _regPasswordController.text.trim();
    final confirmPass = _regConfirmPasswordController.text.trim();

    if (name.isEmpty || username.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Vui lòng điền đầy đủ tất cả các trường!'),
        ),
      );
      return;
    }

    if (username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Tên đăng nhập phải có ít nhất 3 ký tự!'),
        ),
      );
      return;
    }

    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Mật khẩu phải có ít nhất 6 ký tự!'),
        ),
      );
      return;
    }

    if (pass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Mật khẩu xác nhận không trùng khớp!'),
        ),
      );
      return;
    }

    // Bắt đầu bước xác thực mã OTP 4 số
    _startOtpVerification();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: _isVerifyingOtp ? _buildOtpVerificationView() : _buildMainAuthView(),
          ),
        ),
      ),
    );
  }

  // GIAO DIỆN XÁC THỰC MÃ OTP 4 SỐ
  Widget _buildOtpVerificationView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.secondaryNeon, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 48,
              color: AppTheme.secondaryNeon,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'XÁC THỰC MÃ OTP',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppTheme.secondaryNeon,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mã xác nhận 4 số đã được gửi tới email:\n${_regEmailController.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 28),

        // 4 Ô NHẬP MÃ OTP
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 56,
              height: 64,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.secondaryNeon,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.divider, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.secondaryNeon, width: 2),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && index < 3) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (val.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                  if (_otpControllers.every((c) => c.text.isNotEmpty)) {
                    _verifyOtpAndActivate();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // ĐỒNG HỒ ĐẾM NGƯỢC 60 GIÂY
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _otpCountdown > 0
                  ? AppTheme.secondaryNeon.withValues(alpha: 0.12)
                  : AppTheme.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _otpCountdown > 0 ? AppTheme.secondaryNeon : AppTheme.danger,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: _otpCountdown > 0 ? AppTheme.secondaryNeon : AppTheme.danger,
                ),
                const SizedBox(width: 8),
                Text(
                  _otpCountdown > 0
                      ? 'Mã hết hạn sau: ${_otpCountdown.toString().padLeft(2, '0')}s'
                      : 'Mã OTP đã hết hạn!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _otpCountdown > 0 ? AppTheme.secondaryNeon : AppTheme.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // NÚT XÁC THỰC
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryNeon,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _verifyOtpAndActivate,
          child: const Text(
            'XÁC THỰC & KÍCH HOẠT TÀI KHOẢN',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 14),

        // NÚT GỬI LẠI MÃ (Chỉ bấm được sau 1 phút)
        TextButton(
          onPressed: _otpCountdown <= 0 ? _startOtpVerification : null,
          child: Text(
            _otpCountdown <= 0
                ? '🔄 GỬI LẠI MÃ OTP MỚI (${5 - _resendAttempts} lần còn lại)'
                : 'Chờ hết 60s để gửi lại mã (${_otpCountdown}s)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _otpCountdown <= 0 ? AppTheme.secondaryNeon : AppTheme.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // QUAY LẠI
        TextButton(
          onPressed: () {
            _otpTimer?.cancel();
            setState(() => _isVerifyingOtp = false);
          },
          child: const Text('Quay lại chỉnh sửa thông tin', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ),
      ],
    );
  }

  // GIAO DIỆN ĐĂNG NHẬP / ĐĂNG KÝ CHÍNH
  Widget _buildMainAuthView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo & Tiêu đề ứng dụng
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryNeon.withValues(alpha: 0.25),
                  blurRadius: 30,
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
            onPressed: _handleLogin,
            child: const Text('ĐĂNG NHẬP'),
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
            onPressed: _onRegisterSubmit,
            child: const Text('TIẾP TỤC ĐỂ NHẬN MÃ OTP (4 SỐ)'),
          ),
        ],
      ],
    );
  }
}
