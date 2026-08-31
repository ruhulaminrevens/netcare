import 'dart:async';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import '../models/network_profile.dart';

class NetworkDiagnosticService {
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<NetworkSnapshot> inspect({NetworkProfile? profile}) async {
    final addressFuture = _localAddresses();
    final wifiIpFuture = _safe(_networkInfo.getWifiIP);
    final gatewayFuture = _safe(_networkInfo.getWifiGatewayIP);
    final internetFuture = _tcpProbe('1.1.1.1', 443);
    final dnsFuture = _dnsLatency();

    final localAddresses = await addressFuture;
    final wifiIp = await wifiIpFuture;
    final detectedGateway = await gatewayFuture;
    final internet = await internetFuture;
    final dnsLatency = await dnsFuture;
    final checks = <EndpointCheck>[];

    final selectedGateway = _firstNonEmpty([
      profile?.gateway,
      detectedGateway,
    ]);
    if (selectedGateway != null) {
      checks.add(await _probeWithFallback(
        label: 'Gateway / Router',
        host: selectedGateway,
        ports: const [80, 443],
      ));
    }

    if (_hasText(profile?.switchIp)) {
      checks.add(await _probeWithFallback(
        label: 'Managed switch',
        host: profile!.switchIp,
        ports: const [80, 443],
      ));
    }
    if (_hasText(profile?.serverIp)) {
      checks.add(await _probeWithFallback(
        label: 'LAN server',
        host: profile!.serverIp,
        ports: const [445, 3389, 80],
      ));
    }
    if (_hasText(profile?.remoteHost)) {
      checks.add(await _probeWithFallback(
        label: 'Remote / Tailscale host',
        host: profile!.remoteHost,
        ports: [profile.remotePort],
      ));
    }

    return NetworkSnapshot(
      timestamp: DateTime.now(),
      internetAvailable: internet.reachable,
      localAddresses: localAddresses,
      wifiIp: wifiIp,
      gateway: selectedGateway,
      dnsLatencyMs: dnsLatency,
      tailscaleDetected: localAddresses.any(_isTailscaleAddress),
      checks: checks,
    );
  }

  Future<List<String>> _localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      final values = <String>{};
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) values.add(address.address);
        }
      }
      return values.toList()..sort();
    } on SocketException {
      return const [];
    }
  }

  Future<double?> _dnsLatency() async {
    final stopwatch = Stopwatch()..start();
    try {
      final results = await InternetAddress.lookup('cloudflare.com')
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      return results.isEmpty ? null : stopwatch.elapsedMicroseconds / 1000;
    } on Exception {
      return null;
    }
  }

  Future<EndpointCheck> _probeWithFallback({
    required String label,
    required String host,
    required List<int> ports,
  }) async {
    EndpointCheck? last;
    for (final port in ports) {
      final result = await _tcpProbe(host.trim(), port, label: label);
      if (result.reachable) return result;
      last = result;
    }
    return last ??
        EndpointCheck(
          label: label,
          host: host,
          port: ports.first,
          reachable: false,
          latencyMs: 0,
        );
  }

  Future<EndpointCheck> _tcpProbe(
    String host,
    int port, {
    String label = 'Internet',
  }) async {
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      stopwatch.stop();
      return EndpointCheck(
        label: label,
        host: host,
        port: port,
        reachable: true,
        latencyMs: stopwatch.elapsedMicroseconds / 1000,
      );
    } on Exception catch (error) {
      stopwatch.stop();
      return EndpointCheck(
        label: label,
        host: host,
        port: port,
        reachable: false,
        latencyMs: stopwatch.elapsedMicroseconds / 1000,
        note: error.runtimeType.toString(),
      );
    } finally {
      socket?.destroy();
    }
  }

  Future<String?> _safe(Future<String?> Function() action) async {
    try {
      return await action();
    } on Exception {
      return null;
    }
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (_hasText(value)) return value!.trim();
    }
    return null;
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  bool _isTailscaleAddress(String address) {
    final parts = address.split('.');
    if (parts.length != 4 || parts.first != '100') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 64 && second <= 127;
  }
}
