import '../../core/network/api_client.dart';
import 'session_models.dart';

class SessionRepository {
  SessionRepository(this.api);
  final ApiClient api;

  Future<List<DeviceSession>> list() async {
    final data = await api.get('/api/v1/sessions', authenticated: true);
    return (data['items'] as List<dynamic>? ?? const [])
        .map((e) => DeviceSession.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> revoke(String sessionId) async {
    await api.post('/api/v1/sessions/$sessionId/revoke', authenticated: true);
  }

  Future<void> revokeOthers() async {
    await api.post('/api/v1/sessions/revoke-others', authenticated: true);
  }

  Future<void> revokeAll() async {
    await api.post('/api/v1/sessions/revoke-all', authenticated: true);
  }
}
