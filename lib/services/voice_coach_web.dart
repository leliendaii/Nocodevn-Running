// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

dynamic _audioContext;
html.AudioElement? _currentAudio;

Future<void> initSpeechNative() async {}

/// Phát âm thanh hiệu ứng thể thao năng động (Beep / Fanfare)
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

      gain.gain.setValueAtTime(0.25, ctx.currentTime);
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

/// Phát giọng đọc Tiếng Việt chuẩn 100% trên iPhone / Android / Web
void speakTextNative(String text, {double rate = 1.0}) {
  try {
    // 1. Luôn phát âm báo thể thao mở luồng Audio
    playAthleticBeep(freq: 880.0, durationSec: 0.10);

    // 2. Cách 1: Web Speech Synthesis API
    bool synthSuccess = false;
    final synth = html.window.speechSynthesis;
    if (synth != null) {
      try {
        if (synth.paused == true) synth.resume();
        final utterance = html.SpeechSynthesisUtterance(text)
          ..lang = 'vi-VN'
          ..rate = rate
          ..pitch = 1.0;

        final voices = synth.getVoices();
        for (final v in voices) {
          final l = (v.lang ?? '').toLowerCase();
          final n = (v.name ?? '').toLowerCase();
          if (l.contains('vi') || n.contains('viet') || n.contains('việt') || n.contains('linh') || n.contains('an')) {
            utterance.voice = v;
            break;
          }
        }

        synth.speak(utterance);
        synthSuccess = true;
      } catch (synthErr) {
        debugPrint('Web Speech Synthesis error: $synthErr');
      }
    }

    // 3. Cách 2: Google TTS Audio Streaming (Phát giọng Nữ Tiếng Việt tự nhiên)
    if (!synthSuccess || html.window.navigator.userAgent.toLowerCase().contains('iphone')) {
      try {
        final safeText = Uri.encodeComponent(text);
        final ttsUrl = 'https://translate.google.com/translate_tts?ie=UTF-8&tl=vi&client=tw-ob&q=$safeText';
        _currentAudio?.pause();
        _currentAudio = html.AudioElement(ttsUrl)..volume = 1.0;
        _currentAudio?.play().catchError((err) {
          debugPrint('Google TTS Audio error: $err');
        });
      } catch (_) {}
    }
  } catch (e) {
    debugPrint('Lỗi Voice Coach: $e');
  }
}
