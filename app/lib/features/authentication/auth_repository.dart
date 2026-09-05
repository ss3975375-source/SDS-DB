import '../../core/network/api_client.dart';
import '../../core/storage/secure_session_store.dart';
import 'google_auth_service.dart';

class AuthRepository {
  AuthRepository({required this.google, required this.api, required this.store});
  final GoogleAuthService google;
  final ApiClient api;
  final SecureSessionStore store;

  Future<Map<String, dynamic>> signIn() async {
    final identityToken = await google.signInAndGetIdentityToken();
    final response = await api.post('/api/v1/auth/google', body: {
      'identityToken': identityToken,
      'platform': 'android',
    });
    await store.save(accessToken: response['accessToken'] as String, refreshToken: response['refreshToken'] as String);
    return response['user'] as Map<String, dynamic>;
  }

  Future<void> signOut() async {
    try { await api.post('/api/v1/auth/logout', authenticated: true); } catch (_) {}
    await store.clear();
    await google.signOut();
  }
}
