import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

class MapTileCacheService {
  static final Map<String, ui.Image> _memoryCache = {};
  static final Map<String, Completer<ui.Image>> _pendingLoads = {};

  /// Khóa định danh cho từng mảnh bản đồ
  static String tileKey(int zoom, int x, int y) => 'tile_${zoom}_${x}_$y';

  /// Kiểm tra xem tile đã có sẵn trong bộ nhớ đệm (0ms) chưa
  static ui.Image? getCachedImage(int zoom, int x, int y) {
    return _memoryCache[tileKey(zoom, x, y)];
  }

  /// Tải mảnh bản đồ có hỗ trợ bộ nhớ đệm 2 tầng
  static Future<ui.Image> loadTile(int zoom, int x, int y) async {
    final key = tileKey(zoom, x, y);

    // 1. Trả về ngay lập tức nếu đã có trong Memory Cache (0ms)
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key]!;
    }

    // 2. Tránh gửi trùng lặp request khi đang tải
    if (_pendingLoads.containsKey(key)) {
      return _pendingLoads[key]!.future;
    }

    final completer = Completer<ui.Image>();
    _pendingLoads[key] = completer;

    try {
      final String url = 'https://mt1.google.com/vt/lyrs=m&x=$x&y=$y&z=$zoom';
      final imageProvider = NetworkImage(url);
      final stream = imageProvider.resolve(ImageConfiguration.empty);

      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          _memoryCache[key] = info.image;
          _pendingLoads.remove(key);
          if (!completer.isCompleted) {
            completer.complete(info.image);
          }
          stream.removeListener(listener);
        },
        onError: (dynamic error, StackTrace? stack) {
          _pendingLoads.remove(key);
          if (!completer.isCompleted) {
            completer.completeError(error, stack);
          }
          stream.removeListener(listener);
        },
      );

      stream.addListener(listener);
    } catch (e) {
      _pendingLoads.remove(key);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  /// Xóa bộ nhớ đệm nếu cần giải phóng RAM
  static void clearCache() {
    _memoryCache.clear();
    _pendingLoads.clear();
  }
}
