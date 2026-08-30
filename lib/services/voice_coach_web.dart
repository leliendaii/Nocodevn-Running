// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void platformSpeak(String text, {double rate = 1.0, double volume = 1.0}) {
  try {
    final synth = html.window.speechSynthesis;
    if (synth != null) {
      synth.cancel(); // Hủy các câu đọc dở trước đó
      final utterance = html.SpeechSynthesisUtterance(text)
        ..lang = 'vi-VN' // Chuẩn giọng đọc Tiếng Việt
        ..rate = rate
        ..volume = volume;

      // Ưu tiên chọn giọng đọc tiếng Việt nếu có trong danh sách giọng của trình duyệt
      final voices = synth.getVoices();
      for (final v in voices) {
        final lang = v.lang;
        if (lang != null && (lang.startsWith('vi') || lang.contains('VN'))) {
          utterance.voice = v;
          break;
        }
      }

      synth.speak(utterance);
    }
  } catch (_) {
    // Tránh lỗi trên trình duyệt không hỗ trợ Web Speech API
  }
}
