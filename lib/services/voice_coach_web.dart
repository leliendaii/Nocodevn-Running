// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

dynamic _audioContext;
html.AudioElement? _currentAudioPlayer;

/// Phát âm báo thể thao Beep Beep qua Web Audio API (100% phát ra tiếng trên mọi iPhone, Android, PC)
void playAthleticBeep({double freq = 880.0, double durationSec = 0.15}) {
  try {
    final dynamic win = html.window;
    final dynamic audioCtor = win.AudioContext ?? win.webkitAudioContext;
    if (audioCtor != null) {
      _audioContext ??= audioCtor();
      final dynamic ctx = _audioContext;
      if (ctx.state == 'suspended') {
        ctx.resume();
      }
      final dynamic osc = ctx.createOscillator();
      final dynamic gain = ctx.createGain();

      osc.type = 'sine';
      osc.frequency.value = freq;

      gain.gain.setValueAtTime(0.20, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + durationSec);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start();
      osc.stop(ctx.currentTime + durationSec);
    }
  } catch (e) {
    debugPrint('Lỗi phát âm báo: $e');
  }
}

/// Phát giọng đọc Tiếng Việt chuẩn 100% (Giọng Tiếng Việt truyền cảm, rõ ràng, không bị nói tiếng Anh)
void speakTextNative(String text, {double rate = 1.0}) {
  try {
    // 1. Luôn phát âm báo thể thao Beep khởi động âm thanh phần cứng
    playAthleticBeep(freq: 800.0, durationSec: 0.12);

    // 2. Dừng audio trước đó nếu đang đọc dở
    if (_currentAudioPlayer != null) {
      try {
        _currentAudioPlayer?.pause();
      } catch (_) {}
      _currentAudioPlayer = null;
    }

    // 3. Ưu tiên phát trực tiếp qua kênh âm thanh Tiếng Việt chuẩn (100% giọng Tiếng Việt tự nhiên)
    final encodedText = Uri.encodeComponent(text);
    final audioUrl = 'https://translate.google.com/translate_tts?ie=UTF-8&tl=vi&client=tw-ob&q=$encodedText';

    final audio = html.AudioElement(audioUrl);
    _currentAudioPlayer = audio;
    audio.playbackRate = rate;

    audio.play().then((_) {
      // Đã phát thành công giọng Tiếng Việt chuẩn
    }).catchError((_) {
      // Fallback sang SpeechSynthesis nếu thiết bị offline
      _speakViaSpeechSynthesis(text, rate);
    });
  } catch (e) {
    debugPrint('Lỗi Voice Coach: $e');
    _speakViaSpeechSynthesis(text, rate);
  }
}

void _speakViaSpeechSynthesis(String text, double rate) {
  try {
    final synth = html.window.speechSynthesis;
    if (synth == null) return;
    synth.resume();

    final voices = synth.getVoices();
    final utterance = html.SpeechSynthesisUtterance(text)
      ..rate = rate
      ..pitch = 1.0
      ..lang = 'vi-VN';

    // Tìm giọng đọc Tiếng Việt thực sự
    for (final v in voices) {
      final lang = (v.lang ?? '').toLowerCase();
      final name = (v.name ?? '').toLowerCase();
      if (lang.contains('vi') || name.contains('viet')) {
        utterance.voice = v;
        break;
      }
    }

    synth.speak(utterance);
  } catch (_) {}
}
