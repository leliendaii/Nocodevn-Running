import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Dịch vụ Cache Map Tiles Đa Tầng (RAM Memory Cache + Persistent Disk Cache)
/// Hỗ trợ 2 chế độ chính: [🗺️ ĐỊA HÌNH] và [🛰️ VỆ TINH] chuẩn Google Maps + Esri 4K
class MapTileCacheService {
  static final Map<String, ui.Image> _memoryCache = {};
  static final Set<String> _pendingFetches = {};
  static final http.Client _client = http.Client();
  static final ValueNotifier<int> tileNotifier = ValueNotifier<int>(0);
  static Directory? _diskCacheDir;
  static bool _isDiskDirInitialized = false;

  /// Lấy ảnh tile từ RAM cache (nếu đã có)
  static ui.Image? getFromMemory(String key) => _memoryCache[key];

  /// Khởi tạo thư mục cache trên ổ đĩa
  static Future<void> _initDiskDirectory() async {
    if (_isDiskDirInitialized) return;
    if (!kIsWeb) {
      try {
        final cacheDir = await getTemporaryDirectory();
        final tileDir = Directory('${cacheDir.path}/map_tiles_cache');
        if (!await tileDir.exists()) {
          await tileDir.create(recursive: true);
        }
        _diskCacheDir = tileDir;
      } catch (e) {
        debugPrint('Lỗi khởi tạo disk cache map tiles: $e');
      }
    }
    _isDiskDirInitialized = true;
  }

  /// Tải Map Tile với cơ chế 3 tầng: RAM ➔ Ổ đĩa Disk ➔ Mạng Network (Google Maps + Esri Fallback)
  static Future<ui.Image?> getTile(int z, int x, int y, {String mapType = 'terrain'}) async {
    final normalizedType = (mapType == 'satellite') ? 'satellite' : 'terrain';
    final key = '$normalizedType/$z/$x/$y';

    // 1. Kiểm tra RAM Cache (0ms - Phản hồi tức thì)
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    if (_pendingFetches.contains(key)) return null;
    _pendingFetches.add(key);

    try {
      await _initDiskDirectory();

      // 2. Kiểm tra Disk Cache trên thiết bị (< 2ms)
      if (!kIsWeb && _diskCacheDir != null) {
        final diskFile = File('${_diskCacheDir!.path}/tile_${normalizedType}_${z}_${x}_$y.png');
        if (await diskFile.exists()) {
          final bytes = await diskFile.readAsBytes();
          final image = await _decodeImageFromBytes(bytes);
          if (image != null) {
            _memoryCache[key] = image;
            _pendingFetches.remove(key);
            tileNotifier.value++;
            return image;
          }
        }
      }

      // 3. Danh sách URL tải theo thứ tự ưu tiên (Google Maps ➔ Esri Satellite Fallback)
      final int serverId = (x.abs() + y.abs()) % 4;
      final List<String> candidateUrls = [];

      if (normalizedType == 'satellite') {
        // Vệ tinh: Google Hybrid (ảnh vệ tinh kèm tên đường) ➔ Esri World Imagery
        candidateUrls.add('https://mt$serverId.google.com/vt/lyrs=y&hl=vi&x=$x&y=$y&z=$z');
        candidateUrls.add('https://mt$serverId.google.com/vt/lyrs=s,h&hl=vi&x=$x&y=$y&z=$z');
        candidateUrls.add('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$z/$y/$x');
      } else {
        // Địa hình / Đường phố: Google Maps Vector HD
        candidateUrls.add('https://mt$serverId.google.com/vt/lyrs=m&hl=vi&x=$x&y=$y&z=$z');
        candidateUrls.add('https://mt$serverId.google.com/vt/lyrs=p&hl=vi&x=$x&y=$y&z=$z');
      }

      Uint8List? downloadedBytes;
      for (final url in candidateUrls) {
        try {
          final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200 && response.bodyBytes.length > 200) {
            downloadedBytes = response.bodyBytes;
            break;
          }
        } catch (_) {}
      }

      if (downloadedBytes != null) {
        // Lưu ngầm vào Disk Cache không chặn UI
        if (!kIsWeb && _diskCacheDir != null) {
          final diskFile = File('${_diskCacheDir!.path}/tile_${normalizedType}_${z}_${x}_$y.png');
          diskFile.writeAsBytes(downloadedBytes).catchError((_) => diskFile);
        }

        // Decode nhanh bằng phần cứng GPU
        final image = await _decodeImageFromBytes(downloadedBytes);
        if (image != null) {
          _memoryCache[key] = image;
          _pendingFetches.remove(key);
          tileNotifier.value++;
          return image;
        }
      }
    } catch (_) {
      // Bỏ qua lỗi mạng
    } finally {
      _pendingFetches.remove(key);
    }

    return null;
  }

  /// Decode Uint8List thành ui.Image siêu tốc bằng instantiateImageCodec (GPU Accelerated)
  static Future<ui.Image?> _decodeImageFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  /// Tiền tải trước toàn bộ Tiles cho một khu vực (Ưu tiên các tile trung tâm trước)
  static Future<void> preloadBoundingBox({
    required int zoom,
    required int minX,
    required int maxX,
    required int minY,
    required int maxY,
    String mapType = 'terrain',
    VoidCallback? onTileLoaded,
  }) async {
    final double centerX = (minX + maxX) / 2;
    final double centerY = (minY + maxY) / 2;

    final normalizedType = (mapType == 'satellite') ? 'satellite' : 'terrain';

    // 1. Tạo danh sách tọa độ tile
    final List<PointTile> tilesToLoad = [];
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        final key = '$normalizedType/$zoom/$x/$y';
        if (!_memoryCache.containsKey(key)) {
          final distSq = (x - centerX) * (x - centerX) + (y - centerY) * (y - centerY);
          tilesToLoad.add(PointTile(x, y, distSq));
        }
      }
    }

    // 2. Sắp xếp ưu tiên các tile ở trung tâm đường chạy tải TRƯỚC TIÊN
    tilesToLoad.sort((a, b) => a.distanceSq.compareTo(b.distanceSq));

    // 3. Tải song song theo từng đợt (Batch of 10)
    const int batchSize = 10;
    for (int i = 0; i < tilesToLoad.length; i += batchSize) {
      final end = (i + batchSize < tilesToLoad.length) ? i + batchSize : tilesToLoad.length;
      final batch = tilesToLoad.sublist(i, end);

      await Future.wait(batch.map((t) => getTile(zoom, t.x, t.y, mapType: normalizedType).then((img) {
        if (img != null) {
          onTileLoaded?.call();
        }
      })));
    }
  }

  static Map<String, ui.Image> get memoryCache => _memoryCache;
}

class PointTile {
  final int x;
  final int y;
  final double distanceSq;
  PointTile(this.x, this.y, this.distanceSq);
}
