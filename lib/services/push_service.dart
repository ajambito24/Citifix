import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/resident/notifications_screen.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const String announcementsTopic = 'announcements';
  static const String _channelId = 'citifix_high';
  static const String _channelName = 'CitiFix notifications';
  static const String _channelDescription =
      'Announcements and report status updates';

  /// Last tapped push. ResidentHome consumes it and resets it to null.
  final ValueNotifier<NotificationTarget?> tap =
      ValueNotifier<NotificationTarget?>(null);

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _localReady = false;

  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenSub;

  // ===================== INIT (after login / app start) =====================
  Future<void> init() async {
    if (FirebaseAuth.instance.currentUser == null) return;

    final messaging = FirebaseMessaging.instance;

    // The channel has to exist before a push arrives while the app is closed.
    await _quiet(_initLocalNotifications);

    _openedSub ??= FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    _messageSub ??= FirebaseMessaging.onMessage.listen(_onMessage);
    _tokenSub ??= messaging.onTokenRefresh.listen(_saveToken);

    // App was closed and opened by tapping a push.
    await _quiet(() async {
      final initial = await messaging.getInitialMessage();
      if (initial != null) _onOpened(initial);
    });

    // Android 13+ shows the permission prompt; older versions return at once.
    await _quiet(() => messaging.requestPermission());

    await _quiet(() async {
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
    });

    await _quiet(() => messaging.subscribeToTopic(announcementsTopic));
  }

  // ===================== CLEAR (before sign out) =====================
  Future<void> clear() async {
    await _openedSub?.cancel();
    await _messageSub?.cancel();
    await _tokenSub?.cancel();
    _openedSub = null;
    _messageSub = null;
    _tokenSub = null;
    tap.value = null;

    final user = FirebaseAuth.instance.currentUser;
    final messaging = FirebaseMessaging.instance;

    // Independent steps: one failing (e.g. offline) must not block the rest.
    await Future.wait([
      _quiet(() async {
        if (user == null) return;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': FieldValue.delete()});
      }),
      _quiet(() => messaging.unsubscribeFromTopic(announcementsTopic)),
      _quiet(() => messaging.deleteToken()),
    ]);
  }

  // ===================== LOCAL NOTIFICATIONS =====================
  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high, // sound + heads-up popup
      ),
    );

    _localReady = true;
  }

  // A local (foreground) notification was tapped.
  void _onLocalTap(NotificationResponse response) {
    if (FirebaseAuth.instance.currentUser == null) return;

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final target = _targetFrom(map['type'], map['id']);
      if (target != null) tap.value = target;
    } catch (e) {
      debugPrint('PushService: bad notification payload: $e');
    }
  }

  // ===================== INTERNALS =====================
  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _quiet(() {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
    });
  }

  // Push tapped (app was closed or in the background).
  void _onOpened(RemoteMessage message) {
    if (FirebaseAuth.instance.currentUser == null) return;
    final target = _targetFrom(message.data['type'], message.data['id']);
    if (target != null) tap.value = target;
  }

  // Push received while the app is open: show a heads-up popup ourselves.
  Future<void> _onMessage(RemoteMessage message) async {
    if (!_localReady) return;

    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;

    await _quiet(() {
      return _local.show(
        DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
        title.isEmpty ? null : title,
        body.isEmpty ? null : body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode({
          'type': message.data['type'],
          'id': message.data['id'],
        }),
      );
    });
  }

  NotificationTarget? _targetFrom(dynamic typeValue, dynamic idValue) {
    final type = (typeValue ?? '').toString();
    final id = (idValue ?? '').toString();
    if (id.isEmpty) return null;

    switch (type) {
      case 'announcement':
        return NotificationTarget(NotificationType.announcement, id);
      case 'report':
        return NotificationTarget(NotificationType.report, id);
      default:
        return null;
    }
  }

  Future<void> _quiet(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('PushService: $e');
    }
  }
}