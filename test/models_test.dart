import 'package:flutter_test/flutter_test.dart';
import 'package:ruhul_netcare/models/network_profile.dart';
import 'package:ruhul_netcare/models/speed_test_result.dart';

void main() {
  test('speed result survives JSON round trip', () {
    final original = SpeedTestResult(
      timestamp: DateTime.utc(2026, 8, 31, 12),
      downloadMbps: 117.4,
      uploadMbps: 19.2,
      pingMs: 8.3,
      jitterMs: 1.1,
      packetLossPercent: 0,
      mode: 'balanced',
      publicIp: '203.0.113.1',
      isp: 'Example ISP',
      server: 'Dhaka',
    );
    final restored = SpeedTestResult.fromJson(original.toJson());
    expect(restored.downloadMbps, original.downloadMbps);
    expect(restored.timestamp, original.timestamp);
    expect(restored.isp, original.isp);
  });

  test('network profile defaults are safe and empty', () {
    const profile = NetworkProfile();
    expect(profile.gateway, isEmpty);
    expect(profile.switchIp, isEmpty);
    expect(profile.serverIp, isEmpty);
    expect(profile.remotePort, 3389);
  });
}
