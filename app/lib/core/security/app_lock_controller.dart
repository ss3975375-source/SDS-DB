import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'app_lock_service.dart';

/// Coordinates the app-lock state with the Flutter lifecycle.
///
/// The controller never stores a passcode or biometric secret. The operating
/// system performs biometric verification through local_auth.
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  final AppLockService service;
  bool locked = false;
  bool initializing = true;
  bool authenticating = false;
  bool _started = false;

  AppLockController({AppLockService? service})
      : service = service ?? AppLockService();

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    initializing = true;
    notifyListeners();
    try {
      final mode = await service.mode();
      locked = mode != AppLockMode.off;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    super.dispose();
  }

  Future<void> lock({bool notify = true}) async {
    if (await service.mode() == AppLockMode.off) {
      locked = false;
    } else {
      locked = true;
    }
    if (notify) notifyListeners();
  }

  Future<bool> unlock() async {
    if (await service.mode() == AppLockMode.off) {
      locked = false;
      notifyListeners();
      return true;
    }

    final mode = await service.mode();
    if (mode == AppLockMode.passcode) {
      // Passcode verification is deliberately not guessed or implemented with
      // custom cryptography. Until a vetted verifier is configured, the app
      // remains locked rather than silently downgrading security.
      return false;
    }

    authenticating = true;
    notifyListeners();
    try {
      final ok = await service.authenticateBiometrically();
      if (ok) {
        locked = false;
        await service.clearBackgrounded();
      }
      return ok;
    } finally {
      authenticating = false;
      notifyListeners();
    }
  }

  Future<void> checkOnResume() async {
    if (await service.shouldLockOnResume()) {
      locked = true;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      service.recordBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      checkOnResume();
    }
  }
}
