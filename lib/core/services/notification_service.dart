import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pasar_malam/core/constants/api_constants.dart';
import 'package:pasar_malam/core/services/dio_client.dart';
import 'package:pasar_malam/core/services/secure_storage.dart';

// Must be top-level — runs in a separate isolate for background messages
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  debugPrint('[FCM] Background: ${message.notification?.title} | ${message.data}');
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'pasar_malam_default',
    'Home Living Notifications',
    description: 'Notifikasi order dan promo',
    importance: Importance.high,
  );

  // Call once at app startup, before runApp
  static Future<void> initialize() async {
    // iOS & Android 13+ permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Auth status: ${settings.authorizationStatus}');

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Create high-importance channel on Android
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Show foreground notifications on iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Init flutter_local_notifications for Android foreground display
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[FCM] Notification tapped: ${details.payload}');
      },
    );

    // Show notification when app is in foreground (Android)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from background via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Opened from background: ${message.notification?.title}');
    });

    // App opened from terminated state via notification tap
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] Opened from terminated: ${initial.notification?.title}');
    }
  }

  // Call after successful login to register / refresh FCM token with backend
  static Future<void> updateFcmToken() async {
    final backendToken = await SecureStorageService.getToken();
    if (backendToken == null) return;

    try {
      final fcmToken = Platform.isIOS
          ? await _fcm.getAPNSToken().then((_) => _fcm.getToken())
          : await _fcm.getToken();

      if (fcmToken == null) {
        debugPrint('[FCM] Token is null, skipping registration');
        return;
      }
      debugPrint('[FCM] Registering token to backend (${fcmToken.substring(0, 20)}...)');

      await DioClient.instance.post(
        ApiConstants.fcmToken,
        data: {'fcm_token': fcmToken},
      );
      debugPrint('[FCM] Token registered');
    } catch (e) {
      debugPrint('[FCM] Failed to register token: $e');
    }

    // Auto-update when token is refreshed by FCM
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed, updating backend...');
      try {
        await DioClient.instance.post(
          ApiConstants.fcmToken,
          data: {'fcm_token': newToken},
        );
        debugPrint('[FCM] Refreshed token updated');
      } catch (e) {
        debugPrint('[FCM] Failed to update refreshed token: $e');
      }
    });
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    final notif = message.notification;
    if (notif == null) return;

    _localNotif.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }
}
