import 'package:flutter_test/flutter_test.dart';
import 'package:ruhul_netcare/models/ip_intelligence.dart';
import 'package:ruhul_netcare/models/network_profile.dart';
import 'package:ruhul_netcare/models/speed_test_result.dart';
import 'package:ruhul_netcare/services/network_diagnostic_service.dart';
import 'package:ruhul_netcare/services/speed_test_service.dart';

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

  test('health score balances throughput, responsiveness, and stability', () {
    final result = SpeedTestResult(
      timestamp: DateTime.utc(2026, 9, 1),
      downloadMbps: 18,
      uploadMbps: 19,
      pingMs: 60,
      jitterMs: 28,
      packetLossPercent: 0,
      mode: 'deep',
    );
    expect(result.healthScore, inInclusiveRange(75, 80));
    expect(result.speedHealthScore, inInclusiveRange(31, 33));
    expect(result.responsivenessHealthScore, inInclusiveRange(24, 25));
    expect(result.stabilityHealthScore, inInclusiveRange(19, 21));
  });

  test('good speed is not scored zero when latency is temporarily poor', () {
    final result = SpeedTestResult(
      timestamp: DateTime.utc(2026, 9, 1),
      downloadMbps: 55,
      uploadMbps: 18,
      pingMs: 705,
      jitterMs: 624,
      packetLossPercent: 0,
      mode: 'balanced',
    );
    expect(result.healthScore, inInclusiveRange(40, 55));
    expect(result.healthGrade, 'Poor');
  });

  test('latency summary uses medians and resists one large outlier', () {
    final summary = summarizeLatencySamples(
      const [20, 22, 21, 23, 400, 24, 22, 21],
    );
    expect(summary.pingMs, closeTo(22, .001));
    expect(summary.jitterMs, closeTo(2, .001));
  });

  test('Windows route output selects the lowest-metric default gateway', () {
    const output = '''
Network Destination        Netmask          Gateway       Interface  Metric
          0.0.0.0          0.0.0.0     192.168.80.1    192.168.80.10     25
          0.0.0.0          0.0.0.0       10.10.10.1      10.10.10.2     75
''';
    expect(parseWindowsDefaultGateway(output), '192.168.80.1');
  });

  test('Linux and Android route table decodes the default gateway', () {
    const output = '''
Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask
wlan0\t00000000\t010AA8C0\t0003\t0\t0\t0\t00000000
''';
    expect(parseProcNetRouteGateway(output), '192.168.10.1');
  });

  test('IP observations are isolated by provider network, not public IP', () {
    NetworkSnapshot snapshot({required int asn, required String publicIp}) {
      return NetworkSnapshot(
        timestamp: DateTime.utc(2026, 9, 1),
        internetAvailable: true,
        localAddresses: const ['192.168.10.15'],
        connectionKinds: const [ConnectionKind.wifi],
        dnsLatencyMs: 10,
        tailscaleDetected: false,
        checks: const [],
        activeLocalIp: '192.168.10.15',
        gateway: '192.168.10.1',
        publicInfo: PublicIpInfo(ip: publicIp, asn: asn),
      );
    }

    final first = networkObservationScope(
      snapshot(asn: 23956, publicIp: '202.4.118.240'),
    );
    final changedIpSameNetwork = networkObservationScope(
      snapshot(asn: 23956, publicIp: '202.4.118.241'),
    );
    final otherProvider = networkObservationScope(
      snapshot(asn: 140085, publicIp: '103.148.94.171'),
    );
    expect(changedIpSameNetwork, first);
    expect(otherProvider, isNot(first));
  });

  test('public IP masking preserves only a useful network prefix', () {
    expect(maskIpAddress('202.4.118.240'), '202.4.•••.•••');
    expect(maskIpAddress('2400:c600:3122::1'), '2400:c600:••••:••••');
  });
}
