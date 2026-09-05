import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/configuration/app_config.dart';
import 'core/storage/secure_session_store.dart';
import 'features/authentication/google_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final googleAuth = GoogleAuthService(serverClientId: config.googleWebClientId);
  await googleAuth.initialize();
  runApp(SdsDbApp(config: config, googleAuth: googleAuth, sessionStore: SecureSessionStore()));
}
