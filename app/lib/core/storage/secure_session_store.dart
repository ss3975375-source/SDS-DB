import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStore {
  SecureSessionStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _access = 'sds.access_token';
  static const _refresh = 'sds.refresh_token';
  static const _userId = 'sds.user_id';

  Future<void> save({required String accessToken, required String refreshToken, String? userId}) async {
    await _storage.write(key: _access, value: accessToken);
    await _storage.write(key: _refresh, value: refreshToken);
    if (userId != null && userId.isNotEmpty) {
      await _storage.write(key: _userId, value: userId);
    }
  }

  Future<String?> accessToken() => _storage.read(key: _access);
  Future<String?> refreshToken() => _storage.read(key: _refresh);
  Future<String?> userId() => _storage.read(key: _userId);

  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
    await _storage.delete(key: _userId);
  }
}
