import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_repository.dart';

@pragma('vm:entry-point')
Future<void> sdsFirebaseBackgroundHandler(RemoteMessage message) async {
  // Do not log message contents. Navigation is handled when the app resumes.
  await Firebase.initializeApp();
}

class PushNotificationService {
  final NotificationRepository repository;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  PushNotificationService({required this.repository});

  Future<void> initialize({Future<void> Function(String category, String? eventId)? onTap}) async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(sdsFirebaseBackgroundHandler);
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);
    final token = await messaging.getToken();
    if (token != null) await repository.registerDevice(pushToken: token, platform: 'android');
    await _tokenSubscription?.cancel();
    _tokenSubscription = messaging.onTokenRefresh.listen((value) async {
      await repository.registerDevice(pushToken: value, platform: 'android');
    });
    await _messageSubscription?.cancel();
    _messageSubscription = FirebaseMessaging.onMessage.listen((_) {
      // Foreground presentation is intentionally delegated to platform/UI policy.
    });
    await _openedSubscription?.cancel();
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      if (onTap != null) await onTap(message.data['category']?.toString() ?? '', message.data['eventId']?.toString());
    });
    final initial = await messaging.getInitialMessage();
    if (initial != null && onTap != null) await onTap(initial.data['category']?.toString() ?? '', initial.data['eventId']?.toString());
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
