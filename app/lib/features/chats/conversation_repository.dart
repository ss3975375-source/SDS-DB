import '../../core/network/api_client.dart';

class ConversationRepository {
  ConversationRepository(this.api);
  final ApiClient api;

  Future<List<Map<String, dynamic>>> list() async {
    final data = await api.get('/api/v1/conversations', authenticated: true);
    return (data['conversations'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<String> openDirect(String userId) async {
    final data = await api.post('/api/v1/conversations/direct', authenticated: true, body: {'userId': userId});
    return data['conversationId'] as String;
  }
}
