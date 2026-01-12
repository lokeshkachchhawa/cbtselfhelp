import 'package:cbt_drktv/services/fcm_token_registry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushService {
  static final _messaging = FirebaseMessaging.instance;
  static final _flnp = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // iOS permission
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Android channel (once)
    const channel = AndroidNotificationChannel(
      'chat_channel',
      'Chat',
      description: 'Doctor approvals and chat updates',
      importance: Importance.high,
    );
    await _flnp
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _flnp.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final route = resp.payload;
        _routeToChat(route);
      },
    );

    // Foreground push -> show local notification
    FirebaseMessaging.onMessage.listen((msg) async {
      final n = msg.notification;
      if (n == null) return;
      await _flnp.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_channel',
            'Chat',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        payload: msg.data['route'], // e.g. /chat?chatId=...&focus=...
      );
    });

    // Tapped from background
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _routeToChat(msg.data['route']);
    });

    // Tapped from terminated
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _routeToChat(initial.data['route']);

    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      await FcmTokenRegistry.registerForUser(u.uid);
    }
    // ✅ Subscribe to daily CBT tips topic
    await FirebaseMessaging.instance.subscribeToTopic('all_users');
  }

  static Future<void> removeTokenOnLogout() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final t = await _messaging.getToken();
    if (t == null) return;
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      'fcmTokens.$t': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // TODO: plug into your app router
  static void _routeToChat(String? route) {
    // e.g., MyRouter.pushNamed(route ?? '/chat');
    // If you use GoRouter or Navigator 2.0, adapt accordingly.
  }
}
