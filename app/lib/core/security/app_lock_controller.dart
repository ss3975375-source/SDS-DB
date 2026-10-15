import 'dart:async';
import 'package:flutter/widgets.dart';
import 'app_lock_service.dart';

class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  final AppLockService service;
  bool locked = false;
  bool initializing = true;
  bool authenticating = false;
  bool _started = false;
  int _failedPasscodeAttempts = 0;
  DateTime? _passcodeBlockedUntil;
  AppLockMode currentMode = AppLockMode.off;

  AppLockController({AppLockService? service}) : service = service ?? AppLockService();

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    initializing = true;
    notifyListeners();
    try {
      currentMode = await service.mode();
      locked = currentMode != AppLockMode.off;
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
    currentMode = await service.mode();
    locked = currentMode != AppLockMode.off;
    if (notify) notifyListeners();
  }

  Future<bool> unlock() async {
    currentMode = await service.mode();
    if (currentMode == AppLockMode.off) {
      locked = false;
      notifyListeners();
      return true;
    }
    if (currentMode == AppLockMode.passcode) return false;
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

  Future<bool> unlockWithPasscode(String passcode) async {
    currentMode = await service.mode();
    if (currentMode != AppLockMode.passcode) return false;
    final blockedUntil = _passcodeBlockedUntil;
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) return false;
    authenticating = true;
    notifyListeners();
    try {
      final ok = await service.verifyPasscode(passcode);
      if (ok) {
        _failedPasscodeAttempts = 0;
        _passcodeBlockedUntil = null;
        locked = false;
        await service.clearBackgrounded();
        return true;
      }
      if (++_failedPasscodeAttempts >= 5) {
        _failedPasscodeAttempts = 0;
        _passcodeBlockedUntil = DateTime.now().add(const Duration(seconds: 30));
      }
      return false;
    } finally {
      authenticating = false;
      notifyListeners();
    }
  }

  Future<void> enablePasscode(String passcode) async {
    await service.configurePasscode(passcode);
    currentMode = AppLockMode.passcode;
    locked = true;
    _failedPasscodeAttempts = 0;
    _passcodeBlockedUntil = null;
    await service.clearBackgrounded();
    notifyListeners();
  }

  Future<void> enableBiometrics() async {
    await service.setMode(AppLockMode.biometrics);
    currentMode = AppLockMode.biometrics;
    locked = true;
    await service.clearBackgrounded();
    notifyListeners();
  }

  Future<void> disableLock() async {
    await service.setMode(AppLockMode.off);
    currentMode = AppLockMode.off;
    locked = false;
    _failedPasscodeAttempts = 0;
    _passcodeBlockedUntil = null;
    notifyListeners();
  }

  Future<void> checkOnResume() async {
    if (await service.shouldLockOnResume()) {
      currentMode = await service.mode();
      locked = currentMode != AppLockMode.off;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      unawaited(service.recordBackgrounded());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(checkOnResume());
    }
  }
}
