import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Dịch vụ thông báo trực tiếp thời gian thực khi chạy ngầm / tắt màn hình (Live Workout Widget)
class LiveWorkoutNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static const int _notificationId = 888;
  static const String _channelId = 'live_workout_tracking_channel';
  static const String _channelName = 'Theo dõi chạy bộ trực tiếp';

  /// Khởi tạo kênh thông báo hệ thống
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initSettings);

      // Tạo Channel trên Android với cờ chạy ngầm mượt mà không rung chuông liên tục
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Hiển thị quãng đường, pace và thời gian trực tiếp khi chạy ngầm',
            importance: Importance.low, // Không phát tiếng bíp khi nhảy số mỗi giây
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
      }

      // Yêu cầu quyền thông báo trên iOS / Android 13+
      if (!kIsWeb) {
        await _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: false);
      }

      _isInitialized = true;
      debugPrint('✅ Khởi tạo LiveWorkoutNotificationService thành công!');
    } catch (e) {
      debugPrint('Lỗi khởi tạo LiveWorkoutNotificationService: $e');
    }
  }

  /// Cập nhật thông số trực tiếp lên Trung tâm thông báo & Màn hình khóa
  static Future<void> updateWorkoutNotification({
    required double distanceKm,
    required int durationSeconds,
    required String pace,
    required int calories,
    required bool isPaused,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      final int min = durationSeconds ~/ 60;
      final int sec = durationSeconds % 60;
      final String timeStr = '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
      final String kmStr = distanceKm.toStringAsFixed(2);

      final String title = isPaused
          ? 'TẠM DỪNG: $kmStr km'
          : 'ĐANG CHẠY: $kmStr km';

      final String body = '$timeStr  •  $pace /km  •  $calories kcal';

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Hiển thị thông số chạy bộ thời gian thực',
        importance: Importance.low,
        priority: Priority.high,
        ongoing: true, // Ghim trên thanh thông báo không bị vuốt mất khi đang chạy
        autoCancel: false,
        onlyAlertOnce: true, // Không rung chuông mỗi giây
        showWhen: true,
        styleInformation: BigTextStyleInformation(
          'Thời gian: $timeStr\nPace: $pace /km\nCalo: $calories kcal',
          contentTitle: title,
          summaryText: isPaused ? 'Tạm dừng buổi chạy' : 'Đang theo dõi',
        ),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: false, // Không nhảy popup che màn hình
        presentBadge: false,
        presentSound: false,
        categoryIdentifier: 'workout_tracking',
        threadIdentifier: 'running_workout',
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _notificationId,
        title,
        body,
        details,
      );
    } catch (e) {
      // Bỏ qua lỗi cập nhật thông báo ngầm
    }
  }

  /// Xóa thông báo khi kết thúc buổi chạy
  static Future<void> cancelWorkoutNotification() async {
    try {
      await _notifications.cancel(_notificationId);
    } catch (e) {
      debugPrint('Lỗi hủy thông báo: $e');
    }
  }
}
