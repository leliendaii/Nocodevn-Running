import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification_web.dart';

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
      if (kIsWeb) {
        await requestPlatformNotificationPermission();
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initSettings);

      // Tạo các Channel trên Android với cấu hình chuẩn
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Channel 1: Live Workout Tracking
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

        // Channel 2: Nhắc nhở luyện tập hàng ngày
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'running_daily_reminder_channel',
            'Nhắc nhở luyện tập hàng ngày',
            description: 'Thông báo nhắc nhở chạy bộ buổi sáng và duy trì mục tiêu',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

        // Channel 3: Tự động kết thúc phiên chạy
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'running_auto_end_channel',
            'Tự động kết thúc phiên chạy',
            description: 'Thông báo khi phiên chạy tự động chốt và lưu kết quả',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

        await androidImplementation.requestNotificationsPermission();
      }

      // Yêu cầu quyền thông báo trên iOS / iPhone
      if (!kIsWeb) {
        final iosPlugin = _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      }

      _isInitialized = true;
      debugPrint('Khởi tạo LiveWorkoutNotificationService thành công');
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
        icon: '@mipmap/launcher_icon',
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
        presentAlert: false, // Không nhảy popup che màn hình khi đang chạy
        presentBanner: false,
        presentBadge: false,
        presentSound: false,
        presentList: true,
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

  /// Bắn thông báo nhắc nhở ra màn hình khóa & trung tâm thông báo (Hỗ trợ iPhone / iOS & Android)
  static Future<void> showMorningReminderNotification({
    required String title,
    required String body,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      if (kIsWeb) {
        showPlatformBrowserNotification(title: title, body: body, tag: 'morning_reminder');
      }

      const androidDetails = AndroidNotificationDetails(
        'running_daily_reminder_channel',
        'Nhắc nhở luyện tập hàng ngày',
        channelDescription: 'Thông báo nhắc nhở chạy bộ buổi sáng và duy trì mục tiêu',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentBadge: true,
        presentSound: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        999,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('Lỗi hiển thị thông báo nhắc nhở: $e');
    }
  }

  /// Thông báo khi hệ thống tự động kết thúc phiên chạy đúng giờ đã cài
  static Future<void> showAutoEndNotification({
    required double distanceKm,
    required String durationStr,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      final body = 'Đã hoàn thành ${distanceKm.toStringAsFixed(2)} km trong $durationStr. Thành tích đã được lưu.';

      if (kIsWeb) {
        showPlatformBrowserNotification(title: 'Tự động kết thúc phiên chạy', body: body, tag: 'auto_end');
      }

      const androidDetails = AndroidNotificationDetails(
        'running_auto_end_channel',
        'Tự động kết thúc phiên chạy',
        channelDescription: 'Thông báo khi phiên chạy tự động chốt và lưu kết quả',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentBadge: true,
        presentSound: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        889,
        'Tự động kết thúc phiên chạy',
        body,
        details,
      );
    } catch (e) {
      debugPrint('Lỗi hiển thị thông báo tự động kết thúc: $e');
    }
  }
}
