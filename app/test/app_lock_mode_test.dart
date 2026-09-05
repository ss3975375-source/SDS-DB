import 'package:flutter_test/flutter_test.dart';
import 'package:sds_db/core/security/app_lock_service.dart';

void main() {
  test('app lock modes are explicit', () {
    expect(AppLockMode.values, contains(AppLockMode.off));
    expect(AppLockMode.values, contains(AppLockMode.passcode));
    expect(AppLockMode.values, contains(AppLockMode.biometrics));
  });
}
