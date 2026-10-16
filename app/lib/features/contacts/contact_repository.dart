import '../../core/network/api_client.dart';

class ContactRepository {
  ContactRepository(this.api);
  final ApiClient api;

  Future<List<Map<String, dynamic>>> listContacts() async {
    final data = await api.get('/api/v1/contacts', authenticated: true);
    return (data['contacts'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listRequests() async {
    final data = await api.get('/api/v1/contacts/requests', authenticated: true);
    return (data['requests'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> sendRequest(String userId) async {
    await api.post('/api/v1/contacts/requests', authenticated: true, body: {'userId': userId.trim()});
  }

  Future<void> acceptRequest(String requestId) async {
    await api.post('/api/v1/contacts/requests/$requestId/accept', authenticated: true);
  }

  Future<void> declineRequest(String requestId) async {
    await api.post('/api/v1/contacts/requests/$requestId/decline', authenticated: true);
  }

  Future<void> cancelRequest(String requestId) async {
    await api.post('/api/v1/contacts/requests/$requestId/cancel', authenticated: true);
  }

  Future<void> removeContact(String userId) async {
    await api.delete('/api/v1/contacts/$userId', authenticated: true);
  }

  Future<Map<String, dynamic>> createQr({int expiresInSeconds = 600, int maxUses = 1}) =>
      api.post('/api/v1/contacts/qr', authenticated: true, body: {
        'expiresInSeconds': expiresInSeconds,
        'maxUses': maxUses,
      });

  Future<Map<String, dynamic>> consumeQr(String token) =>
      api.post('/api/v1/contacts/qr/consume', authenticated: true, body: {'token': token});

  Future<Map<String, dynamic>> openConversation(String userId) =>
      api.post('/api/v1/conversations/direct', authenticated: true, body: {'userId': userId});

  Future<Map<String, dynamic>> discover(String userId) =>
      api.get('/api/v1/users/discover?userId=${Uri.encodeQueryComponent(userId.trim())}', authenticated: true);
}
