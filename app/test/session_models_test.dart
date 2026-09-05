import 'package:flutter_test/flutter_test.dart';
import 'package:sds_db/features/sessions/session_models.dart';

void main() {
  test('parses current session metadata without sensitive identifiers', () {
    final session = DeviceSession.fromJson({
      'id': 'session-1',
      'deviceName': 'Android phone',
      'platform': 'Android',
      'appVersion': '1.0.0',
      'createdAt': '2026-09-04T00:00:00Z',
      'lastSeenAt': '2026-09-04T01:00:00Z',
      'current': true,
      'revokedAt': null,
    });

    expect(session.current, isTrue);
    expect(session.revoked, isFalse);
    expect(session.platform, 'Android');
  });
}
