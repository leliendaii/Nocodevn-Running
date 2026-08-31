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

  /// 1. Bắt đầu chạy
  static void speakStart() {
    speak('Ba, hai, một... Bắt đầu buổi chạy bộ. Chúc bạn có một buổi chạy thật tuyệt vời!');
  }

  /// 2. Tạm dừng
  static void speakPause() {
    speak('Buổi chạy đã tạm dừng.');
  }

  /// 3. Tiếp tục chạy
  static void speakResume() {
    speak('Tiếp tục chạy bộ.');
  }

  /// 4. Thông báo mốc 1 KM (Giống Strava / Nike Run Club)
  static void speakMilestone(int kmCount, String pace) {
    // Chuyển pace từ dạng "5:20" thành tiếng Việt "5 phút 20 giây"
    String paceSpeech = pace;
    if (pace.contains(':')) {
      final parts = pace.split(':');
      if (parts.length == 2) {
        final min = int.tryParse(parts[0]) ?? 0;
        final sec = int.tryParse(parts[1]) ?? 0;
        paceSpeech = '$min phút $sec giây';
      }
    }

    final message = 'Bạn đã hoàn thành ki-lô-mét thứ $kmCount. Pace trung bình $paceSpeech mỗi ki-lô-mét. Cố lên!';
    speak(message);
  }

  /// 5. Kết thúc buổi chạy
  static void speakFinish(double distanceKm, int durationSeconds) {
    final int min = durationSeconds ~/ 60;
    final int sec = durationSeconds % 60;
    final String kmStr = distanceKm.toStringAsFixed(2);
    final message = 'Chúc mừng bạn đã hoàn thành buổi chạy! Tổng quãng đường $kmStr ki-lô-mét trong $min phút $sec giây. Bạn làm rất tốt!';
    speak(message);
  }
}
