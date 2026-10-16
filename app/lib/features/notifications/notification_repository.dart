import '../../core/network/api_client.dart';
import 'notification_preferences.dart';

class NotificationRepository {
  NotificationRepository(this.api);
  final ApiClient api;

  Future<NotificationPreferences> getPreferences() async {
    final data = await api.get('/api/v1/notifications/preferences', authenticated: true);
    return NotificationPreferences.fromApiJson(data);
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    await api.put('/api/v1/notifications/preferences', authenticated: true, body: preferences.toApiJson());
  }

  Future<void> registerDevice({
    required String pushToken,
    required String platform,
    String? appVersion,
  }) async {
    await api.post('/api/v1/notifications/devices', authenticated: true, body: {
      'token': pushToken,
      'platform': platform,
      if (appVersion != null) 'appVersion': appVersion,
    });
  }

  Future<void> unregisterDevice(String deviceId) async {
    await api.delete('/api/v1/notifications/devices/$deviceId', authenticated: true);
  }
}
