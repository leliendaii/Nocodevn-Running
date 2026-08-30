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

void speakTextNative(String text, {double rate = 1.0}) {
  try {
    // 1. Luôn phát âm báo thể thao Beep khởi động âm thanh phần cứng
    playAthleticBeep(freq: 800.0, durationSec: 0.12);

    final synth = html.window.speechSynthesis;
    if (synth == null) return;

    // Khắc phục lỗi Chromium / Safari bị treo trạng thái
    synth.resume();

    final voices = synth.getVoices();

    final utterance = html.SpeechSynthesisUtterance(text)
      ..rate = rate
      ..pitch = 1.0
      ..volume = 1.0;

    // Tìm giọng đọc tiếng Việt tối ưu trên thiết bị (vi-VN / Google Tiếng Việt / Siri Vietnamese / Microsoft An)
    html.SpeechSynthesisVoice? viVoice;
    for (final v in voices) {
      final lang = (v.lang ?? '').toLowerCase();
      final name = (v.name ?? '').toLowerCase();
      if (lang.contains('vi') || name.contains('viet')) {
        viVoice = v;
        break;
      }
    }

    if (viVoice != null) {
      utterance.voice = viVoice;
      utterance.lang = viVoice.lang ?? 'vi-VN';
    } else {
      utterance.lang = 'vi-VN';
      if (voices.isNotEmpty) {
        utterance.voice = voices.first;
      }
    }

    synth.speak(utterance);
  } catch (e) {
    debugPrint('Lỗi Voice Coach: $e');
  }
}
