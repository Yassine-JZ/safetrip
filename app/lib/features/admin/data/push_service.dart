import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../trips/data/activity.dart';
import '../../trips/data/trip_repository.dart';
import 'admin_repository.dart';

/// Registers the FCM token and shows a local banner when a new in-app
/// notification arrives while the app is open.
///
/// Push when the app is killed still needs a Cloud Function (Blaze) that
/// reads `fcm_tokens/{uid}` and calls the FCM HTTP API.
class PushService {
  PushService({
    required this.admin,
    required this.trips,
  });

  final AdminRepository admin;
  final TripRepository trips;

  final _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<List<AppNotification>>? _notes;
  final _seen = <String>{};
  var _seeded = false;
  var _ready = false;

  Future<void> start(String uid) async {
    await stop();
    _seeded = false;
    _seen.clear();
    await _ensureLocal();
    await _registerToken(uid);
    _notes = trips.watchNotifications(uid).listen((list) {
      if (!_seeded) {
        for (final note in list) {
          _seen.add(note.id);
        }
        _seeded = true;
        return;
      }
      for (final note in list) {
        if (note.read || _seen.contains(note.id)) {
          _seen.add(note.id);
          continue;
        }
        _seen.add(note.id);
        unawaited(_show(note.title, note.body));
      }
    });
  }

  Future<void> stop() async {
    await _notes?.cancel();
    _notes = null;
  }

  Future<void> _ensureLocal() async {
    if (_ready || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    const channel = AndroidNotificationChannel(
      'safetrip_alerts',
      'Alertes SafeTrip',
      description: 'Notifications de réservation et de messages',
      importance: Importance.defaultImportance,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _ready = true;
  }

  Future<void> _registerToken(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await admin.saveFcmToken(
        uid: uid,
        token: token,
        platform: _platform,
      );
    } catch (_) {
      // Token optional on Spark / incomplete Firebase config.
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  Future<void> _show(String title, String body) async {
    if (kIsWeb) return;
    await _ensureLocal();
    await _local.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safetrip_alerts',
          'Alertes SafeTrip',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
