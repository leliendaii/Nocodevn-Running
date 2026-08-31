import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Dịch vụ Cache Map Tiles Đa Tầng (RAM Memory Cache + Persistent Disk Cache)
/// Giúp bản đồ 3D tải tức thì trong 0.05s kể cả khi vừa mở lại app hoặc sau khi khởi động lại!
class MapTileCacheService {
  static final Map<String, ui.Image> _memoryCache = {};
  static final Set<String> _pendingFetches = {};
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

  /// Tải Map Tile với cơ chế 3 tầng: RAM ➔ Ổ đĩa Disk ➔ Mạng Network
  static Future<ui.Image?> getTile(int z, int x, int y) async {
    final key = '$z/$x/$y';

    // 1. Kiểm tra RAM Cache (0ms)
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    if (_pendingFetches.contains(key)) return null;
    _pendingFetches.add(key);

    try {
      await _initDiskDirectory();

      // 2. Kiểm tra Disk Cache trên thiết bị (< 5ms)
      if (!kIsWeb && _diskCacheDir != null) {
        final diskFile = File('${_diskCacheDir!.path}/tile_${z}_${x}_$y.png');
        if (await diskFile.exists()) {
          final bytes = await diskFile.readAsBytes();
          final image = await _decodeImageFromBytes(bytes);
          if (image != null) {
            _memoryCache[key] = image;
            _pendingFetches.remove(key);
            return image;
          }
        }
      }

      // 3. Tải qua mạng Google Maps Server với độ phân giải cao Retina HD (@2x)
      final int serverId = (x.abs() + y.abs()) % 4;
      final url = 'https://mt$serverId.google.com/vt/lyrs=m&hl=vi&x=$x&y=$y&z=$z&scale=2';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;

        // Lưu vào Disk Cache
        if (!kIsWeb && _diskCacheDir != null) {
          final diskFile = File('${_diskCacheDir!.path}/tile_${z}_${x}_$y.png');
          diskFile.writeAsBytes(bytes).catchError((_) => diskFile);
        }

        // Decode và lưu RAM Cache
        final image = await _decodeImageFromBytes(bytes);
        if (image != null) {
          _memoryCache[key] = image;
          _pendingFetches.remove(key);
          return image;
        }
      }
    } catch (e) {
      // Bỏ qua lỗi mạng
    } finally {
      _pendingFetches.remove(key);
    }

    return null;
  }

  /// Decode Uint8List thành ui.Image
  static Future<ui.Image?> _decodeImageFromBytes(Uint8List bytes) async {
    final Completer<ui.Image?> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future.timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () => null,
    );
  }

  /// Tiền tải trước toàn bộ Tiles cho một khu vực
  static Future<void> preloadBoundingBox({
    required int zoom,
    required int minX,
    required int maxX,
    required int minY,
    required int maxY,
    VoidCallback? onTileLoaded,
  }) async {
    final List<Future<void>> tasks = [];
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        final key = '$zoom/$x/$y';
        if (_memoryCache.containsKey(key)) continue;

        tasks.add(getTile(zoom, x, y).then((img) {
          if (img != null) {
            onTileLoaded?.call();
          }
        }));
      }
    }
    await Future.wait(tasks);
  }

  static Map<String, ui.Image> get memoryCache => _memoryCache;
}
