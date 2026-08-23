import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../top_sync_toast.dart';

class OtpVerificationDialog extends StatefulWidget {
  final String name;
  final String username;
  final String email;
  final String password;
  final int initialAttempts;
  final VoidCallback onAttemptIncrement;
  final Function(DateTime) onLock;

  const OtpVerificationDialog({
    super.key,
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    required this.initialAttempts,
    required this.onAttemptIncrement,
    required this.onLock,
  });

  @override
  State<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<OtpVerificationDialog> {
  int _otpCountdown = 60;
  Timer? _otpTimer;
  late int _resendAttempts;
  bool _isSubmitting = false;

  // Hỗ trợ 6 ô nhập mã OTP (chuẩn quốc tế của Supabase)
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _resendAttempts = widget.initialAttempts;
    _startCountdown();
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _otpTimer?.cancel();
    setState(() {
      _otpCountdown = 60;
    });

    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown > 0) {
        setState(() => _otpCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // Gửi lại mã OTP qua Email thực tế
  Future<void> _resendOtp() async {
    if (_resendAttempts >= 5) {
      final lockUntil = DateTime.now().add(const Duration(hours: 1));
      widget.onLock(lockUntil);
      Navigator.of(context).pop();
      TopSyncToast.show(
        context,
        message: '⛔ Đã gửi quá 5 lần! Tạm khóa gửi OTP trong 1 tiếng.',
        isSuccess: false,
      );
      return;
    }

    _resendAttempts++;
    widget.onAttemptIncrement();

    for (var c in _otpControllers) {
      c.clear();
    }

    final error = await context.read<AuthProvider>().resendOtp(widget.email);
    if (!mounted) return;

    if (error != null) {
      TopSyncToast.show(context, message: error, isSuccess: false);
    } else {
      _startCountdown();
      TopSyncToast.show(
        context,
        message: 'Đã gửi mã OTP mới tới email: ${widget.email}',
        isSuccess: true,
      );
    }
  }

  // Xác thực mã OTP và kích hoạt tài khoản
  Future<void> _verifyOtpAndRegister() async {
    final enteredOtp = _otpControllers.map((c) => c.text.trim()).join();

    if (enteredOtp.length < 6) {
      TopSyncToast.show(
        context,
        message: 'Vui lòng nhập đủ 6 chữ số OTP từ Email!',
        isSuccess: false,
      );
      return;
    }

    if (_otpCountdown <= 0) {
      TopSyncToast.show(
        context,
        message: '⏱️ Mã OTP đã hết hạn! Vui lòng bấm gửi lại mã mới.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final error = await context.read<AuthProvider>().verifyOtpAndActivate(
      email: widget.email,
      token: enteredOtp,
      name: widget.name,
      username: widget.username,
      password: widget.password,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      TopSyncToast.show(
        context,
        message: error,
        isSuccess: false,
      );
    } else {
      _otpTimer?.cancel();
      Navigator.of(context).pop();
      TopSyncToast.show(
        context,
        message: '🎉 Xác thực Email thành công! Đã kích hoạt tài khoản.',
        isSuccess: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppTheme.secondaryNeon, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 26,
                      color: AppTheme.secondaryNeon,
                    ),
                  ),
                  const Text(
                    'XÁC THỰC EMAIL OTP',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppTheme.secondaryNeon,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Mã xác nhận 6 số đã được gửi tới hộp thư Email:\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),

              // 6 Ô NHẬP MÃ OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 42,
                    height: 52,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.secondaryNeon,
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
                          borderSide: const BorderSide(color: AppTheme.secondaryNeon, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else if (val.isEmpty && index > 0) {
                          _otpFocusNodes[index - 1].requestFocus();
                        }
                        if (_otpControllers.every((c) => c.text.isNotEmpty)) {
                          _verifyOtpAndRegister();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // ĐỒNG HỒ ĐẾM NGƯỢC 60 GIÂY
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _otpCountdown > 0
                      ? AppTheme.secondaryNeon.withValues(alpha: 0.12)
                      : AppTheme.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
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
                      size: 14,
                      color: _otpCountdown > 0 ? AppTheme.secondaryNeon : AppTheme.danger,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _otpCountdown > 0
                          ? 'Mã hết hạn sau: ${_otpCountdown.toString().padLeft(2, '0')}s'
                          : 'Mã OTP đã hết hạn!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _otpCountdown > 0 ? AppTheme.secondaryNeon : AppTheme.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // NÚT XÁC THỰC & KÍCH HOẠT
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryNeon,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSubmitting ? null : _verifyOtpAndRegister,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Text(
                          'XÁC THỰC & KÍCH HOẠT TÀI KHOẢN',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // NÚT GỬI LẠI MÃ (RESEND)
              TextButton(
                onPressed: _otpCountdown <= 0 ? _resendOtp : null,
                child: Text(
                  _otpCountdown <= 0
                      ? '🔄 GỬI LẠI MÃ VỀ EMAIL (${5 - _resendAttempts} lần còn lại)'
                      : 'Chờ 60s để gửi lại mã (${_otpCountdown}s)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _otpCountdown <= 0 ? AppTheme.secondaryNeon : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
