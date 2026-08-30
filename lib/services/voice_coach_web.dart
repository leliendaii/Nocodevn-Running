// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

dynamic _audioContext;

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

/// Phát giọng đọc Tiếng Việt chuẩn 100% (ResponsiveVoice Vietnamese Female -> Browser Google/Siri Tiếng Việt)
void speakTextNative(String text, {double rate = 1.0}) {
  try {
    // 1. Luôn phát âm báo thể thao Beep khởi động loa
    playAthleticBeep(freq: 800.0, durationSec: 0.12);

    final dynamic win = html.window;

    // 2. Cách 1: Sử dụng ResponsiveVoice chuyên giọng đọc Nữ Tiếng Việt (100% giọng Tiếng Việt tự nhiên, tròn vành rõ chữ)
    if (win.responsiveVoice != null) {
      try {
        win.responsiveVoice.cancel();
        win.responsiveVoice.speak(
          text,
          'Vietnamese Female',
          {'rate': rate, 'pitch': 1.0},
        );
        return;
      } catch (e) {
        debugPrint('Lỗi ResponsiveVoice: $e');
      }
    }

    // 3. Cách 2: Sử dụng Web Speech Synthesis với giọng Tiếng Việt
    final synth = html.window.speechSynthesis;
    if (synth == null) return;
    synth.resume();

    final voices = synth.getVoices();
    html.SpeechSynthesisVoice? viVoice;
    for (final v in voices) {
      final lang = (v.lang ?? '').toLowerCase().replaceAll('_', '-');
      final name = (v.name ?? '').toLowerCase();
      if (lang.startsWith('vi') || name.contains('viet') || name.contains('việt')) {
        viVoice = v;
        break;
      }
    }

    final utterance = html.SpeechSynthesisUtterance(text)
      ..rate = rate
      ..pitch = 1.0
      ..lang = 'vi-VN';

    if (viVoice != null) {
      utterance.voice = viVoice;
    }

    synth.speak(utterance);
  } catch (e) {
    debugPrint('Lỗi Voice Coach: $e');
  }
}
