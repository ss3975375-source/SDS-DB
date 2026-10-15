import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum AppLockMode { off, passcode, biometrics }

class AppLockService {
  static const _modeKey = 'sds_app_lock_mode';
  static const _passcodeVerifierKey = 'sds_app_lock_passcode_verifier';
  static const _lastBackgroundKey = 'sds_app_lock_last_background_ms';
  static const _iterations = 120000;
  final FlutterSecureStorage storage;
  final LocalAuthentication localAuth;

  AppLockService({FlutterSecureStorage? storage, LocalAuthentication? localAuth})
      : storage = storage ?? const FlutterSecureStorage(),
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
    if (value == AppLockMode.passcode && !await hasPasscodeVerifier()) {
      throw StateError('Set a passcode before enabling passcode lock.');
    }
    if (value == AppLockMode.biometrics) {
      final supported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;
      if (!supported || !canCheck) {
        throw PlatformException(code: 'biometrics_unavailable', message: 'Biometric authentication is not available.');
      }
    }
    await storage.write(key: _modeKey, value: switch (value) {
      AppLockMode.off => 'off',
      AppLockMode.passcode => 'passcode',
      AppLockMode.biometrics => 'biometrics',
    });
    if (value == AppLockMode.off) {
      await removePasscodeVerifier();
      await clearBackgrounded();
    }
  }

  /// Stores a salted PBKDF2-HMAC-SHA256 verifier, never the passcode itself.
  Future<void> configurePasscode(String passcode) async {
    if (!RegExp(r'^\d{6,12}$').hasMatch(passcode)) {
      throw ArgumentError('Use a passcode containing 6 to 12 digits.');
    }
    final salt = await Cryptography.instance.newRandomBytes(16);
    final algorithm = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _iterations, bits: 256);
    final key = await algorithm.deriveKey(secretKey: SecretKey(utf8.encode(passcode)), nonce: salt);
    final digest = await key.extractBytes();
    final verifier = 'pbkdf2-sha256:$_iterations:${base64.encode(salt)}:${base64.encode(digest)}';
    await storage.write(key: _passcodeVerifierKey, value: verifier);
    await storage.write(key: _modeKey, value: 'passcode');
  }

  Future<bool> verifyPasscode(String passcode) async {
    final stored = await storage.read(key: _passcodeVerifierKey);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 100000 || iterations > 1000000) return false;
    if (!RegExp(r'^\d{6,12}$').hasMatch(passcode)) return false;
    try {
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      if (salt.length != 16 || expected.length != 32) return false;
      final algorithm = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
      final key = await algorithm.deriveKey(secretKey: SecretKey(utf8.encode(passcode)), nonce: salt);
      final actual = await key.extractBytes();
      var difference = 0;
      for (var i = 0; i < expected.length; i++) {
        difference |= expected[i] ^ actual[i];
      }
      return difference == 0;
    } on FormatException {
      return false;
    }
  }

  Future<bool> hasPasscodeVerifier() async => (await storage.read(key: _passcodeVerifierKey)) != null;
  Future<void> removePasscodeVerifier() => storage.delete(key: _passcodeVerifierKey);
  Future<void> recordBackgrounded() async => storage.write(key: _lastBackgroundKey, value: DateTime.now().toUtc().millisecondsSinceEpoch.toString());
  Future<void> clearBackgrounded() => storage.delete(key: _lastBackgroundKey);

  Future<bool> shouldLockOnResume({Duration gracePeriod = Duration.zero}) async {
    if (await mode() == AppLockMode.off) return false;
    final raw = await storage.read(key: _lastBackgroundKey);
    if (raw == null) return true;
    final last = int.tryParse(raw);
    if (last == null) return true;
    final elapsed = DateTime.now().toUtc().millisecondsSinceEpoch - last;
    return elapsed >= gracePeriod.inMilliseconds;
  }

  Future<bool> authenticateBiometrically({String reason = 'Unlock SDS-DB'}) async {
    final supported = await localAuth.isDeviceSupported();
    final canCheck = await localAuth.canCheckBiometrics;
    if (!supported || !canCheck) return false;
    try {
      return await localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException {
      return false;
    }
  }
}
