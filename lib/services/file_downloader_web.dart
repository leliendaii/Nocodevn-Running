// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> downloadFileBytes(List<int> bytes, String filename, String mimeType) async {
  final blob = html.Blob([bytes], mimeType);

  // 1. Thử dùng Web Share API trên thiết bị di động (iPhone Safari / Android)
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  final isMobile = userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('mobile');

  if (isMobile) {
    try {
      final file = html.File([blob], filename, {'type': mimeType});
      await html.window.navigator.share({
        'files': [file],
        'title': 'Lộ trình 3D Flyover Chạy Bộ',
        'text': 'Lộ trình 3D Flyover buổi chạy bộ của tôi',
      });
      return;
    } catch (_) {
      // Fallback nếu người dùng hủy hoặc trình duyệt không hỗ trợ share file
    }
  }

  // 2. Tải trực tiếp file về máy / trình duyệt qua thẻ <a download>
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
