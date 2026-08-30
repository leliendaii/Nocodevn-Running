import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart';

class FileDownloader {
  static void download(List<int> bytes, String filename, {String mimeType = 'video/mp4'}) {
    downloadFileBytes(bytes, filename, mimeType);
  }
}
