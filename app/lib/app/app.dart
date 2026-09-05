import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/network/api_client.dart';
import '../core/security/app_lock_controller.dart';
import '../core/security/app_lock_gate.dart';
import '../core/storage/secure_session_store.dart';
import '../features/authentication/auth_repository.dart';
import '../features/authentication/google_auth_service.dart';
import '../features/authentication/login_page.dart';
import '../features/home/home_page.dart';
import 'configuration/app_config.dart';
import 'theme/app_theme.dart';

class SdsDbApp extends StatefulWidget {
  const SdsDbApp({super.key, required this.config, required this.googleAuth, required this.sessionStore});
  final AppConfig config;
  final GoogleAuthService googleAuth;
  final SecureSessionStore sessionStore;

  @override
  State<SdsDbApp> createState() => _SdsDbAppState();
}

class _SdsDbAppState extends State<SdsDbApp> {
  late final ApiClient api;
  late final AuthRepository auth;
  late final AppLockController lockController;

  @override
  void initState() {
    super.initState();
    api = ApiClient(baseUrl: widget.config.apiBaseUrl, sessionStore: widget.sessionStore);
    auth = AuthRepository(google: widget.googleAuth, api: api, store: widget.sessionStore);
    lockController = AppLockController();
  }

  @override
  void dispose() {
    lockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(routes: [
      GoRoute(path: '/login', builder: (_, __) => LoginPage(auth: auth)),
      GoRoute(
        path: '/',
        builder: (_, __) => _AuthGate(
          auth: auth,
          googleAuth: widget.googleAuth,
          api: api,
          lockController: lockController,
        ),
      ),
    ]);
    return MaterialApp.router(
      title: 'SDS-DB',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.auth, required this.googleAuth, required this.api, required this.lockController});
  final AuthRepository auth;
  final GoogleAuthService googleAuth;
  final ApiClient api;
  final AppLockController lockController;

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: auth.store.accessToken(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if ((snapshot.data ?? '').isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/login');
        });
        return const Scaffold(body: SizedBox.shrink());
      }
      return AppLockGate(
        controller: lockController,
        child: HomePage(
          googleAuth: googleAuth,
          auth: auth,
          api: api,
          lockController: lockController,
        ),
      );
    },
  );
}
