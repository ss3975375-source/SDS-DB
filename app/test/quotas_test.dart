import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SDS-DB quota constants are documented correctly', () {
    const oneToOne = 12 * 1000 * 1000 * 1000;
    const group = 24 * 1000 * 1000 * 1000;
    expect(oneToOne, 12000000000);
    expect(group, 24000000000);
  });
}
