import 'package:flutter_test/flutter_test.dart';
import 'package:sds_db/core/security/app_lock_controller.dart';
import 'package:sds_db/core/security/app_lock_service.dart';

class _FakeLockService extends AppLockService {
  AppLockMode current = AppLockMode.biometrics;
  bool authenticated = false;
  bool passcodeMatches = false;

  @override
  Future<AppLockMode> mode() async => current;

  @override
  Future<bool> authenticateBiometrically({String reason = 'Unlock SDS-DB'}) async => authenticated;

  @override
  Future<bool> verifyPasscode(String passcode) async => passcodeMatches && passcode == '123456';

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

test('passcode unlock only succeeds after verifier accepts it', () async {
  final service = _FakeLockService()..current = AppLockMode.passcode;
  final controller = AppLockController(service: service);
  await controller.start();
  expect(controller.locked, isTrue);

  expect(await controller.unlockWithPasscode('000000'), isFalse);
  expect(controller.locked, isTrue);

  service.passcodeMatches = true;
  expect(await controller.unlockWithPasscode('123456'), isTrue);
  expect(controller.locked, isFalse);
  controller.dispose();
});

test('passcode mode cannot be unlocked by biometric-only entry point', () async {
  final service = _FakeLockService()..current = AppLockMode.passcode;
  final controller = AppLockController(service: service);
  await controller.start();
  service.authenticated = true;

  expect(await controller.unlock(), isFalse);
  expect(controller.locked, isTrue);
  controller.dispose();
});

}
