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
  late final TextEditingController _identifierController;
  bool _isLoading = false;
  bool _emailSent = false;
  String _targetEmail = '';

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

  Future<void> _handleSendResetLink() async {
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
        _emailSent = true;
      });
      _startCountdown();
      TopSyncToast.show(
        context,
        message: 'Đã gửi email khôi phục mật khẩu đến $_targetEmail!',
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

  Future<void> _handleResendLink() async {
    if (_resendCountdown > 0 || _isLoading) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final result = await auth.sendPasswordReset(_targetEmail);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _startCountdown();
      TopSyncToast.show(
        context,
        message: 'Đã gửi lại email khôi phục mới!',
        isSuccess: true,
      );
    } else {
      TopSyncToast.show(
        context,
        message: result['error'] ?? 'Không thể gửi lại email!',
        isSuccess: false,
      );
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: _emailSent ? _buildSuccessView() : _buildInputFormView(),
        ),
      ),
    );
  }

  // 1. MÀN HÌNH NHẬP EMAIL HOẶC USERNAME (GỌN GÀNG NHẤT)
  Widget _buildInputFormView() {
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
          onSubmitted: (_) => _handleSendResetLink(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSendResetLink,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('GỬI LIÊN KẾT ĐẶT LẠI MẬT KHẨU'),
        ),
      ],
    );
  }

  // 2. MÀN HÌNH THÀNH CÔNG (HƯỚNG DẪN MỞ EMAIL)
  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        // Biểu tượng thư gửi thành công
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryNeon.withValues(alpha: 0.15),
            border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryNeon.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.mark_email_read_rounded, color: AppTheme.primaryNeon, size: 40),
        ),
        const SizedBox(height: 18),

        const Text(
          'ĐÃ GỬI THƯ KHÔI PHỤC!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        const Text(
          'Liên kết đặt lại mật khẩu đã được gửi đến địa chỉ:',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Hộp hiển thị Email
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined, size: 18, color: AppTheme.primaryNeon),
              const SizedBox(width: 8),
              Text(
                _targetEmail,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryNeon),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Hướng dẫn các bước tiếp theo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CÁC BƯỚC TIẾP THEO:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.6),
              ),
              const SizedBox(height: 10),
              _buildStepItem(1, 'Mở ứng dụng Gmail hoặc Hộp thư của bạn.'),
              _buildStepItem(2, 'Tìm thư mới từ hệ thống với tiêu đề "Reset your password".'),
              _buildStepItem(3, 'Bấm vào liên kết "Reset password" trong email để nhập mật khẩu mới.'),
              _buildStepItem(4, 'Quay lại ứng dụng và đăng nhập bằng mật khẩu mới vừa tạo.'),
              const Divider(color: AppTheme.divider, height: 20),
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.accentOrange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nếu không thấy thư, vui lòng kiểm tra thêm mục Thư rác (Spam) hoặc Quảng cáo.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Nút quay lại đăng nhập
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNeon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'HOÀN TẤT & QUAY LẠI ĐĂNG NHẬP',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Nút gửi lại
        TextButton(
          onPressed: _resendCountdown == 0 ? _handleResendLink : null,
          child: Text(
            _resendCountdown > 0
                ? 'Chưa nhận được email? Gửi lại (${_resendCountdown}s)'
                : 'Chưa nhận được email? Bấm để gửi lại',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _resendCountdown > 0 ? AppTheme.textMuted : AppTheme.secondaryNeon,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(int stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.divider),
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNeon),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
