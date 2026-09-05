import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService({required this.serverClientId});
  final String serverClientId;
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _signIn.initialize(serverClientId: serverClientId.isEmpty ? null : serverClientId);
    _subscription = _signIn.authenticationEvents.listen((_) {});
    _initialized = true;
    try { await _signIn.attemptLightweightAuthentication(); } catch (_) {}
  }

  Future<String> signInAndGetIdentityToken() async {
    if (!_initialized) await initialize();
    final account = await _signIn.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) throw StateError('Google did not return an identity token');
    return token;
  }

  Future<void> signOut() => _signIn.signOut();

  Future<void> dispose() async => _subscription?.cancel();
}
