import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart';

class FileDownloader {
  static Future<void> download(List<int> bytes, String filename, {String mimeType = 'image/png'}) async {
    await downloadFileBytes(bytes, filename, mimeType);
  }
}
