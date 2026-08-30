import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_coach_stub.dart'
    if (dart.library.html) 'voice_coach_web.dart';

class VoiceCoachService {
  static bool _isEnabled = true;
  static const double _volume = 1.0;
  static const double _speechRate = 1.0;
  static const String _prefKey = 'voice_coach_enabled';

  static bool get isEnabled => _isEnabled;
  static double get volume => _volume;
  static double get speechRate => _speechRate;

  /// Khởi tạo trạng thái Voice Coach từ bộ nhớ máy
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {
      _isEnabled = true;
    }
  }

  /// Bật / Tắt Voice Coach
  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  /// Phát giọng đọc tiếng Việt bất kỳ
  static void speak(String text) {
    if (!_isEnabled) return;
    try {
      platformSpeak(text, rate: _speechRate, volume: _volume);
    } catch (e) {
      debugPrint('Lỗi Voice Coach: $e');
    }
  }

  /// 🚀 Khi bắt đầu chạy
  static void speakStart() {
    speak('Buổi chạy bắt đầu. Chúc bạn có một buổi tập tràn đầy năng lượng!');
  }

  /// 📍 Khi đạt mốc Kilomet (1.0km, 2.0km, 3.0km...)
  static void speakMilestone(int km, String duration, String pace) {
    speak('Bạn vừa hoàn thành Kilomet số $km. Thời gian: $duration. Tốc độ: $pace mỗi kilomet. Hãy tiếp tục duy trì nhé!');
  }

  /// ⏸️ Khi tạm dừng
  static void speakPause() {
    speak('Đã tạm dừng buổi chạy.');
  }

  /// ▶️ Khi tiếp tục
  static void speakResume() {
    speak('Tiếp tục buổi chạy.');
  }

  /// 🏆 Khi hoàn thành buổi chạy
  static void speakFinish({
    required double distanceKm,
    required String duration,
    required int calories,
  }) {
    final kmStr = distanceKm.toStringAsFixed(1);
    speak('Chúc mừng bạn đã hoàn thành buổi chạy! Tổng quãng đường: $kmStr kilomet. Thời gian: $duration. Tiêu hao: $calories calo. Bạn làm rất tuyệt vời!');
  }
}
