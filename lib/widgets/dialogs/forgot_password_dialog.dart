import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../top_sync_toast.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final String? initialIdentifier;
  final Function(String emailOrUser)? onSuccess;

  const ForgotPasswordDialog({
    super.key,
    this.initialIdentifier,
    this.onSuccess,
  });

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  int _step = 1; // 1: Nhập identifier, 2: Nhập OTP & Mật khẩu mới
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
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(text: widget.initialIdentifier ?? '');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // Bước 1: Gửi mã OTP xác thực khôi phục mật khẩu
  Future<void> _handleSendResetOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      TopSyncToast.show(context, message: 'Vui lòng nhập Email hoặc Tên đăng nhập!', isSuccess: false);
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
      TopSyncToast.show(
        context,
        message: 'Đã gửi mã xác nhận 6 số đến email $_targetEmail!',
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
    if (_resendCountdown > 0) return;
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
        message: 'Đã gửi lại mã OTP mới đến email!',
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

  // Bước 2: Xác thực mã OTP và cập nhật mật khẩu mới
  Future<void> _handleResetPassword() async {
    final otp = _otpControllers.map((c) => c.text).join();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (otp.length < 6) {
      TopSyncToast.show(context, message: 'Vui lòng nhập đủ 6 chữ số mã OTP!', isSuccess: false);
      return;
    }

    if (newPass.length < 6) {
      TopSyncToast.show(context, message: 'Mật khẩu mới phải có ít nhất 6 ký tự!', isSuccess: false);
      return;
    }

    if (newPass != confirmPass) {
      TopSyncToast.show(context, message: 'Mật khẩu xác nhận không trùng khớp!', isSuccess: false);
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.confirmPasswordReset(
      email: _targetEmail,
      otp: otp,
      newPassword: newPass,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      Navigator.of(context).pop();
      widget.onSuccess?.call(_identifierController.text.trim());
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
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.primaryNeon, width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryNeon.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryNeon, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'QUÊN MẬT KHẨU',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step == 1) ...[
              const Text(
                'Nhập Email hoặc Tên đăng nhập của tài khoản bạn muốn khôi phục:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _identifierController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Email hoặc Username',
                  hintText: 'VD: runner123 hoặc user@gmail.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded, color: AppTheme.primaryNeon, size: 20),
                ),
                onSubmitted: (_) => _handleSendResetOtp(),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // BƯỚC 2: NHẬP OTP & ĐẶT LẠI MẬT KHẨU
              Text(
                'Mã OTP 6 số đã được gửi đến: $_targetEmail',
                style: const TextStyle(fontSize: 12, color: AppTheme.secondaryNeon, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // 6 Ô NHẬP MÃ OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 40,
                    height: 46,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNeon,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primaryNeon, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (index < 5) {
                            _otpFocusNodes[index + 1].requestFocus();
                          } else {
                            _otpFocusNodes[index].unfocus();
                          }
                        } else {
                          if (index > 0) {
                            _otpFocusNodes[index - 1].requestFocus();
                          }
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),

              // Nút Gửi lại mã
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('← Đổi email/username', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: _resendCountdown == 0 ? _handleResendOtp : null,
                    child: Text(
                      _resendCountdown > 0 ? 'Gửi lại mã (${_resendCountdown}s)' : 'Gửi lại mã OTP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _resendCountdown > 0 ? AppTheme.textMuted : AppTheme.secondaryNeon,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Mật khẩu mới
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNewPass,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới (ít nhất 6 ký tự)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryNeon, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPass ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textMuted,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Xác nhận mật khẩu mới
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPass,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Xác nhận lại mật khẩu mới',
                  prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryNeon, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPass ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textMuted,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('HỦY', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryNeon,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _isLoading
              ? null
              : (_step == 1 ? _handleSendResetOtp : _handleResetPassword),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  _step == 1 ? 'GỬI MÃ XÁC THỰC' : 'ĐẶT LẠI MẬT KHẨU',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
