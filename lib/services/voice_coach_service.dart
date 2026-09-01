import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_coach_stub.dart'
    if (dart.library.html) 'voice_coach_web.dart';

/// Huấn luyện viên giọng nói tiếng Việt chuyên nghiệp (Voice Coach)
class VoiceCoachService {
  static const String _prefKey = 'voice_coach_enabled';
  static bool _isEnabled = true;
  static bool _isInitialized = false;

  static bool get isEnabled => _isEnabled;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefKey) ?? true;
      _isInitialized = true;
      await initSpeechNative();
    } catch (_) {
      _isEnabled = true;
    }
  }

  static Future<void> toggleVoiceCoach(bool enabled) async {
    _isEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  /// Phát âm thanh trực tiếp
  static void speak(String text, {double rate = 1.05}) {
    if (!_isEnabled) return;
    try {
      speakTextNative(text, rate: rate);
    } catch (e) {
      debugPrint('Lỗi Voice Coach: $e');
    }
  }

  static String formatDurationSpeech(int durationSeconds) {
    final int hours = durationSeconds ~/ 3600;
    final int min = (durationSeconds % 3600) ~/ 60;
    final int sec = durationSeconds % 60;

    if (hours > 0) {
      if (min > 0 && sec > 0) {
        return '$hours giờ $min phút $sec giây';
      } else if (min > 0) {
        return '$hours giờ $min phút';
      } else {
        return '$hours giờ';
      }
    } else if (min > 0) {
      if (sec > 0) {
        return '$min phút $sec giây';
      } else {
        return '$min phút';
      }
    } else {
      return '$sec giây';
    }
  }

  static String formatPaceSpeech(String pace) {
    if (pace.contains(':')) {
      final parts = pace.split(':');
      if (parts.length == 2) {
        final min = int.tryParse(parts[0]) ?? 0;
        final sec = int.tryParse(parts[1]) ?? 0;
        if (sec > 0) {
          return '$min phút $sec giây';
        } else {
          return '$min phút';
        }
      }
    }
    return pace;
  }

  /// 1. Bắt đầu chạy (Đọc ngắn gọn)
  static void speakStart() {
    speak('Bắt đầu.');
  }

  /// 2. Tạm dừng
  static void speakPause() {
    speak('Tạm dừng.');
  }

  /// 3. Tiếp tục chạy
  static void speakResume() {
    speak('Tiếp tục.');
  }

  /// 4. Thông báo qua từng KM: "Bạn đã chạy được X km trong vòng Y giờ"
  static void speakMilestone(int kmCount, int durationSeconds) {
    final timeStr = formatDurationSpeech(durationSeconds);
    final message = 'Bạn đã chạy được $kmCount ki-lô-mét trong vòng $timeStr.';
    speak(message);
  }

  /// 5. Kết thúc buổi chạy: "Kết thúc. Bạn đã chạy tổng X km trong vòng Y giờ, tiêu hao Z calo, pace P"
  static void speakFinish(double distanceKm, int durationSeconds, int calories, String pace) {
    final timeStr = formatDurationSpeech(durationSeconds);
    final paceStr = formatPaceSpeech(pace);
    final String kmStr = distanceKm.toStringAsFixed(1).replaceAll('.0', '');
    final message = 'Kết thúc. Bạn đã chạy tổng $kmStr ki-lô-mét trong vòng $timeStr, tiêu hao $calories calo, pace $paceStr mỗi ki-lô-mét.';
    speak(message);
  }

  /// 6. Nhắc nhở giờ chạy bộ: "Chào [tên], đã đến giờ chạy rồi. Cùng xỏ giày và bứt phá hôm nay nhé!"
  static void speakReminder([String? userName]) {
    final name = (userName != null && userName.trim().isNotEmpty) ? userName.trim() : 'bạn';
    speak('Chào $name, đã đến giờ chạy rồi. Cùng xỏ giày và bứt phá hôm nay nhé!');
  }
}
