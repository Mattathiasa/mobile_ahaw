import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../screens/dashboard_items/announcements_page.dart';
import '../screens/dashboard_items/meetings_page.dart';
import '../screens/dashboard_items/reports_page.dart';
import '../screens/dashboard_items/notifications_page.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Global navigator key so notification taps can route without a BuildContext.
  /// Wired to `MaterialApp(navigatorKey: NotificationService.navigatorKey)`.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    // 1. Request permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('[FCM] Permission: ${settings.authorizationStatus}');
    }

    // 2. Initialize local notifications for foreground display
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    // 3. Create Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'announcements_channel',
        'Announcements',
        description: 'Notifications for new church announcements',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 4. Subscribe to topics
    await _messaging.subscribeToTopic('announcements');
    await _messaging.subscribeToTopic('meetings');

    // 5. Save FCM token to Firestore for direct notifications
    await _saveFcmToken();

    // Refresh token when it rotates
    _messaging.onTokenRefresh.listen(_updateFcmToken);

    // 6. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;

      if (notification != null && !kIsWeb) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'announcements_channel',
              'Announcements',
              channelDescription:
                  'Notifications for new church announcements',
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    });

    // 7. Handle notification tap when app is opened from the background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

    // 8. Handle the notification that cold-started the app (terminated state).
    //    Delayed so the navigator + auth state have time to restore.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 1500),
          () => _handleMessageNavigation(initialMessage));
    }
  }

  /// Routes a tapped notification to the relevant screen based on
  /// `message.data['type']`, matching the types emitted by the web's Cloud
  /// Functions (announcement / meeting / report_comment). No-op when signed out.
  static void _handleMessageNavigation(RemoteMessage message) {
    if (kDebugMode) {
      print('[FCM] Notification tapped: ${message.data}');
    }
    if (FirebaseAuth.instance.currentUser == null) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final type = message.data['type'] as String?;
    late final Widget page;
    switch (type) {
      case 'announcement':
        page = const AnnouncementsPage();
        break;
      case 'meeting':
        page = const MeetingsPage();
        break;
      case 'report_comment':
      case 'report':
        page = const ReportsPage();
        break;
      default:
        page = const NotificationsPage();
    }
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  /// Save the device FCM token to the current user's Firestore document.
  /// This enables the Cloud Function to send direct notifications.
  static Future<void> _saveFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _updateFcmToken(token);
    } catch (e) {
      if (kDebugMode) print('[FCM] Error saving token: $e');
    }
  }

  static Future<void> _updateFcmToken(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
      if (kDebugMode) print('[FCM] Token saved for user $uid');
    } catch (e) {
      if (kDebugMode) print('[FCM] Error updating token: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    if (kDebugMode) {
      print('[FCM] Background message: ${message.messageId}');
    }
  }
}
