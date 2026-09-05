import 'package:flutter_test/flutter_test.dart';
import 'package:sds_db/core/security/app_lock_controller.dart';
import 'package:sds_db/core/security/app_lock_service.dart';

class _FakeLockService extends AppLockService {
  AppLockMode current = AppLockMode.biometrics;
  bool authenticated = false;

  @override
  Future<AppLockMode> mode() async => current;

  @override
  Future<bool> authenticateBiometrically({String reason = 'Unlock SDS-DB'}) async => authenticated;

  @override
  Future<void> clearBackgrounded() async {}
}

void main() {
  test('explicit lock and biometric unlock update state', () async {
    final service = _FakeLockService();
    final controller = AppLockController(service: service);
    await controller.start();
    expect(controller.locked, isTrue);

    service.authenticated = true;
    expect(await controller.unlock(), isTrue);
    expect(controller.locked, isFalse);

    await controller.lock();
    expect(controller.locked, isTrue);
    controller.dispose();
  });
}
