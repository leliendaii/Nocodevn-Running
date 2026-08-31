import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

FlutterTts? _flutterTts;
bool _ttsInitialized = false;

/// Khởi tạo Text-To-Speech chuẩn VIP cho iPhone (iOS Siri Tiếng Việt) & Android (Google TTS)
Future<void> initSpeechNative() async {
  if (_ttsInitialized) return;
  try {
    _flutterTts = FlutterTts();

    await _flutterTts!.setLanguage('vi-VN');
    await _flutterTts!.setSpeechRate(0.50); // Tốc độ đọc chuẩn tự nhiên, dễ nghe khi chạy
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);

    // Cấu hình âm thanh iOS chuẩn Thể thao (VoicePrompt qua Loa ngoài hoặc Tai nghe Bluetooth)
    if (Platform.isIOS) {
      await _flutterTts!.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }

    _ttsInitialized = true;
    debugPrint('✅ Khởi tạo FlutterTts Tiếng Việt thành công!');
  } catch (e) {
    debugPrint('Lỗi khởi tạo FlutterTts: $e');
  }
}

void playAthleticBeep({double freq = 880.0, double durationSec = 0.15}) {}

/// Phát giọng nói Tiếng Việt chuẩn 100% trên Native App iPhone & Android
void speakTextNative(String text, {double rate = 1.0}) {
  try {
    if (!_ttsInitialized) {
      initSpeechNative().then((_) {
        _flutterTts?.stop();
        _flutterTts?.speak(text);
      });
    } else {
      _flutterTts?.stop();
      _flutterTts?.speak(text);
    }
  } catch (e) {
    debugPrint('Lỗi phát giọng nói native: $e');
  }
}
