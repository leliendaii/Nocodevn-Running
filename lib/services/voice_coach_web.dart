// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void speakTextNative(String text, {double rate = 1.0}) {
  try {
    final synth = html.window.speechSynthesis;
    if (synth == null) return;

    // Hủy các câu nói trước đó đang đọc dở
    synth.cancel();

    final utterance = html.SpeechSynthesisUtterance(text)
      ..lang = 'vi-VN'
      ..rate = rate
      ..pitch = 1.0;

    synth.speak(utterance);
  } catch (_) {}
}
