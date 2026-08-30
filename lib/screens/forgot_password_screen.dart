import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialIdentifier;

  const ForgotPasswordScreen({super.key, this.initialIdentifier});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1; // 1: Nhập email/username, 2: Nhập 6 số OTP & Mật khẩu mới
  bool _isLoading = false;
  String _targetEmail = '';

  // Controllers Step 1
  late final TextEditingController _identifierController;

  // Controllers Step 2
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  // Đếm ngược gửi lại OTP
  int _otpCountdown = 60;
  Timer? _otpTimer;

  @override
  void initState() {
    super.initState();
    _identifierController =
        TextEditingController(text: widget.initialIdentifier ?? '');
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _identifierController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _otpTimer?.cancel();
    setState(() => _otpCountdown = 60);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown > 0) {
        setState(() => _otpCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // BƯỚC 1: Gửi mã OTP 6 số về Email
  Future<void> _handleSendResetOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      TopSyncToast.show(
        context,
        message: 'Vui lòng nhập Email hoặc Tên đăng nhập!',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final result = await auth.sendPasswordReset(identifier);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() {
        _targetEmail = result['email'] ?? identifier;
        _step = 2;
      });
      _startCountdown();
      for (final c in _otpControllers) {
        c.clear();
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
      TopSyncToast.show(
        context,
        message: 'Đã gửi mã OTP 6 số đến email $_targetEmail!',
        isSuccess: true,
      );
    } else {
      TopSyncToast.show(
        context,
        message: result['error'] ?? 'Không tìm thấy tài khoản tương ứng!',
        isSuccess: false,
      );
    }
  }

  // Gửi lại mã OTP
  Future<void> _handleResendOtp() async {
    if (_otpCountdown > 0 || _isLoading) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final result = await auth.sendPasswordReset(_targetEmail);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _startCountdown();
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
      TopSyncToast.show(
        context,
        message: 'Đã gửi lại mã OTP 6 số mới tới email!',
        isSuccess: true,
      );
    } else {
      TopSyncToast.show(
        context,
        message: result['error'] ?? 'Không thể gửi lại mã OTP!',
        isSuccess: false,
      );
    }
  }

  // BƯỚC 2: Xác thực mã OTP và Cập nhật Mật khẩu mới
  Future<void> _handleResetPassword() async {
    final enteredOtp = _otpControllers.map((c) => c.text.trim()).join();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (enteredOtp.length < 6) {
      TopSyncToast.show(
        context,
        message: 'Vui lòng nhập đủ 6 chữ số OTP từ Email!',
        isSuccess: false,
      );
      return;
    }

    if (newPass.length < 6) {
      TopSyncToast.show(
        context,
        message: 'Mật khẩu mới phải có ít nhất 6 ký tự!',
        isSuccess: false,
      );
      return;
    }

    if (newPass != confirmPass) {
      TopSyncToast.show(
        context,
        message: 'Mật khẩu xác nhận không trùng khớp!',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.confirmPasswordReset(
      email: _targetEmail,
      otp: enteredOtp,
      newPassword: newPass,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      _otpTimer?.cancel();
      Navigator.of(context).pop();
      TopSyncToast.show(
        context,
        message: '🎉 Đặt lại mật khẩu thành công! Vui lòng đăng nhập với mật khẩu mới.',
        isSuccess: true,
      );
    } else {
      TopSyncToast.show(context, message: error, isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KHÔI PHỤC MẬT KHẨU'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: _step == 1 ? _buildStep1View() : _buildStep2View(),
        ),
      ),
    );
  }

  // 1. MÀN HÌNH BƯỚC 1: NHẬP EMAIL / TÊN ĐĂNG NHẬP
  Widget _buildStep1View() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _identifierController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Email hoặc Tên đăng nhập',
            hintText: 'Nhập email hoặc username đã đăng ký',
            prefixIcon: Icon(
              Icons.alternate_email_rounded,
              color: AppTheme.primaryNeon,
            ),
          ),
          onSubmitted: (_) => _handleSendResetOtp(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSendResetOtp,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('GỬI MÃ OTP XÁC THỰC'),
        ),
      ],
    );
  }

  // 2. MÀN HÌNH BƯỚC 2: NHẬP MÃ OTP 6 SỐ & MẬT KHẨU MỚI
  Widget _buildStep2View() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              children: [
                const TextSpan(text: 'Mã xác nhận 6 số đã được gửi tới email:\n'),
                TextSpan(
                  text: _targetEmail,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryNeon,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 6 Ô NHẬP MÃ OTP CHUẨN ĐẸP
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 44,
              height: 52,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryNeon,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryNeon, width: 2),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (val.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 10),

        // Hàng điều khiển: Đổi email & Đếm ngược gửi lại
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => setState(() => _step = 1),
              child: const Text(
                '← Đổi email / username',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: _otpCountdown == 0 ? _handleResendOtp : null,
              child: Text(
                _otpCountdown > 0 ? 'Gửi lại mã (${_otpCountdown}s)' : 'Gửi lại mã OTP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _otpCountdown > 0 ? AppTheme.textMuted : AppTheme.secondaryNeon,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Ô nhập Mật khẩu mới
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPass,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Mật khẩu mới (ít nhất 6 ký tự)',
            hintText: 'Nhập mật khẩu mới',
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: AppTheme.primaryNeon,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPass ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textMuted,
              ),
              onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Ô xác nhận Mật khẩu mới
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPass,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Xác nhận lại mật khẩu mới',
            hintText: 'Nhập lại mật khẩu mới',
            prefixIcon: const Icon(
              Icons.lock_reset_rounded,
              color: AppTheme.primaryNeon,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPass ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textMuted,
              ),
              onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Nút đặt lại mật khẩu
        ElevatedButton(
          onPressed: _isLoading ? null : _handleResetPassword,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('ĐẶT LẠI MẬT KHẨU & ĐĂNG NHẬP'),
        ),
      ],
    );
  }
}
