import 'package:flutter_test/flutter_test.dart';
import 'package:ruhul_netcare/models/ip_intelligence.dart';
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
      publicInfo: const PublicIpInfo(
        ip: '203.0.113.1',
        isp: 'Example ISP',
        city: 'Dhaka',
        country: 'Bangladesh',
      ),
      server: 'Dhaka',
      connectionType: 'Wi-Fi',
      downloadBytes: 1048576,
      uploadBytes: 524288,
      downloadDurationMs: 1000,
      uploadDurationMs: 500,
    );
    final restored = SpeedTestResult.fromJson(original.toJson());
    expect(restored.downloadMbps, original.downloadMbps);
    expect(restored.timestamp, original.timestamp);
    expect(restored.isp, original.isp);
    expect(restored.location, 'Dhaka, Bangladesh');
    expect(restored.transferredMegabytes, closeTo(1.5, .001));
  });

  test('network profile defaults are safe and empty', () {
    const profile = NetworkProfile();
    expect(profile.gateway, isEmpty);
    expect(profile.switchIp, isEmpty);
    expect(profile.serverIp, isEmpty);
    expect(profile.routerWanIp, isEmpty);
    expect(profile.remotePort, 3389);
  });

  test('router WAN CGNAT range is classified as shared IP', () {
    final snapshot = NetworkSnapshot(
      timestamp: DateTime.now(),
      internetAvailable: true,
      localAddresses: const ['192.168.0.10'],
      connectionKinds: const [ConnectionKind.wifi],
      dnsLatencyMs: 10,
      tailscaleDetected: false,
      checks: const [],
      activeLocalIp: '192.168.0.10',
      routerWanIp: '100.64.1.20',
      publicInfo: const PublicIpInfo(ip: '203.0.113.5'),
    );
    expect(snapshot.ipAccessType, IpAccessType.cgnatConfirmed);
  });
}
