// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'package:flutter/foundation.dart';

Future<void> requestPlatformNotificationPermission() async {
  try {
    if (html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }
  } catch (e) {
    debugPrint('Web notification permission error: $e');
  }
}

void showPlatformBrowserNotification({
  required String title,
  required String body,
  String? tag,
}) {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(
        title,
        body: body,
        icon: 'icons/Icon-192.png',
        tag: tag ?? 'nocodevn_running_notification',
      );
    } else {
      html.Notification.requestPermission().then((perm) {
        if (perm == 'granted') {
          html.Notification(
            title,
            body: body,
            icon: 'icons/Icon-192.png',
            tag: tag ?? 'nocodevn_running_notification',
          );
        }
      });
    }
  } catch (e) {
    debugPrint('Web notification error: $e');
  }
}
