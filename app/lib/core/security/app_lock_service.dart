import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum AppLockMode { off, passcode, biometrics }

class AppLockService {
  static const _modeKey = 'sds_app_lock_mode';
  static const _passcodeVerifierKey = 'sds_app_lock_passcode_verifier';
  static const _lastBackgroundKey = 'sds_app_lock_last_background_ms';

  final FlutterSecureStorage storage;
  final LocalAuthentication localAuth;

  AppLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : storage = storage ?? const FlutterSecureStorage(),
        localAuth = localAuth ?? LocalAuthentication();

  Future<AppLockMode> mode() async {
    final value = await storage.read(key: _modeKey);
    return switch (value) {
      'passcode' => AppLockMode.passcode,
      'biometrics' => AppLockMode.biometrics,
      _ => AppLockMode.off,
    };
  }

  Future<void> setMode(AppLockMode value) async {
    if (value == AppLockMode.biometrics) {
      final supported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;
      if (!supported || !canCheck) {
        throw PlatformException(
          code: 'biometrics_unavailable',
          message: 'Biometric authentication is not available.',
        );
      }
    }
    await storage.write(
      key: _modeKey,
      value: switch (value) {
        AppLockMode.off => 'off',
        AppLockMode.passcode => 'passcode',
        AppLockMode.biometrics => 'biometrics',
      },
    );
  }

  /// The passcode itself is never stored.
  ///
  /// Production integration should supply a memory-hard password/KDF
  /// implementation backed by a vetted crypto library and store only a
  /// verifier/salt. This foundation intentionally does not invent crypto.
  Future<void> setPasscodeVerifier(String verifier) async {
    if (verifier.trim().isEmpty) {
      throw ArgumentError('Passcode verifier cannot be empty');
    }
    await storage.write(
      key: _passcodeVerifierKey,
      value: verifier,
    );
  }

  Future<bool> hasPasscodeVerifier() async =>
      (await storage.read(key: _passcodeVerifierKey)) != null;

  Future<void> removePasscodeVerifier() =>
      storage.delete(key: _passcodeVerifierKey);

  Future<void> recordBackgrounded() async {
    await storage.write(
      key: _lastBackgroundKey,
      value: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> clearBackgrounded() => storage.delete(key: _lastBackgroundKey);

  Future<bool> shouldLockOnResume({
    Duration gracePeriod = Duration.zero,
  }) async {
    final mode = await this.mode();
    if (mode == AppLockMode.off) return false;

    final raw = await storage.read(key: _lastBackgroundKey);
    if (raw == null) return true;

    final last = int.tryParse(raw);
    if (last == null) return true;

    final elapsed = DateTime.now().toUtc().millisecondsSinceEpoch - last;
    return elapsed >= gracePeriod.inMilliseconds;
  }

  Future<bool> authenticateBiometrically({
    String reason = 'Unlock SDS-DB',
  }) async {
    final supported = await localAuth.isDeviceSupported();
    final canCheck = await localAuth.canCheckBiometrics;
    if (!supported || !canCheck) return false;

    try {
      return await localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
