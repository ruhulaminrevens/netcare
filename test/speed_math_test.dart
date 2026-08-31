import 'package:flutter_test/flutter_test.dart';
import 'package:ruhul_netcare/services/speed_test_service.dart';

void main() {
  group('megabitsPerSecond', () {
    test('converts one megabyte transferred in one second', () {
      expect(megabitsPerSecond(1000000, 1000000), closeTo(8, .001));
    });

    test('handles invalid measurements', () {
      expect(megabitsPerSecond(0, 1000000), 0);
      expect(megabitsPerSecond(1000, 0), 0);
    });
  });

  test('mode estimates include upload and download payloads', () {
    expect(SpeedTestMode.quick.estimatedMegabytes, 11);
    expect(SpeedTestMode.balanced.estimatedMegabytes, 41);
    expect(SpeedTestMode.deep.estimatedMegabytes, 100);
  });
}
