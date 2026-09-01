import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../models/network_profile.dart';
import 'public_ip_service.dart';

class NetworkDiagnosticService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final Connectivity _connectivity = Connectivity();
  final PublicIpService _publicIpService = PublicIpService();

  Future<NetworkSnapshot> inspect({NetworkProfile? profile}) async {
    final localFuture = _localNetworkData();
    final wifiIpFuture = _safe(_networkInfo.getWifiIP);
    final gatewayFuture = _safe(_networkInfo.getWifiGatewayIP);
    final connectionFuture = _connectionKinds();
    final internetFuture = _tcpProbe('1.1.1.1', 443);
    final dnsFuture = _dnsLatency();
    final publicInfoFuture = _publicIpService.lookup();

    final local = await localFuture;
    final wifiIp = await wifiIpFuture;
    final detectedGateway = await gatewayFuture;
    final connectionKinds = await connectionFuture;
    final systemGateway = await _systemDefaultGateway(connectionKinds);
    final internet = await internetFuture;
    final dnsLatency = await dnsFuture;
    final publicInfo = await publicInfoFuture;
    final checks = <EndpointCheck>[];

    final selectedGateway = _firstNonEmpty([
      profile?.gateway,
      detectedGateway,
      systemGateway,
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
      internetAvailable: internet.reachable || publicInfo != null,
      localAddresses: local.addresses,
      connectionKinds: connectionKinds,
      activeLocalIp: _activeLocalIp(
        local.interfaces,
        connectionKinds,
        wifiIp,
      ),
      wifiIp: wifiIp,
      gateway: selectedGateway,
      routerWanIp: _firstNonEmpty([profile?.routerWanIp]),
      publicInfo: publicInfo,
      dnsLatencyMs: dnsLatency,
      tailscaleDetected: _tailscaleDetected(local, connectionKinds),
      checks: checks,
    );
  }

  Future<_LocalNetworkData> _localNetworkData() async {
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
      return _LocalNetworkData(
        addresses: values.toList()..sort(),
        interfaces: interfaces,
      );
    } on SocketException {
      return const _LocalNetworkData(addresses: [], interfaces: []);
    }
  }

  Future<List<ConnectionKind>> _connectionKinds() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final kinds = <ConnectionKind>{};
      for (final result in results) {
        kinds.add(switch (result) {
          ConnectivityResult.wifi => ConnectionKind.wifi,
          ConnectivityResult.mobile => ConnectionKind.mobile,
          ConnectivityResult.ethernet => ConnectionKind.ethernet,
          ConnectivityResult.vpn => ConnectionKind.vpn,
          ConnectivityResult.bluetooth => ConnectionKind.bluetooth,
          ConnectivityResult.none => ConnectionKind.none,
          _ => ConnectionKind.other,
        });
      }
      return kinds.isEmpty ? const [ConnectionKind.none] : kinds.toList();
    } on Exception {
      return const [ConnectionKind.other];
    }
  }

  String? _activeLocalIp(
    List<NetworkInterface> interfaces,
    List<ConnectionKind> kinds,
    String? wifiIp,
  ) {
    if (kinds.contains(ConnectionKind.wifi) && _hasText(wifiIp)) {
      return wifiIp!.trim();
    }

    final preferredPattern = kinds.contains(ConnectionKind.mobile)
        ? RegExp(r'rmnet|ccmni|pdp|wwan|cell', caseSensitive: false)
        : kinds.contains(ConnectionKind.ethernet)
            ? RegExp(r'ethernet|^eth|^en', caseSensitive: false)
            : RegExp(r'wlan|wifi|ethernet|^eth|^en|rmnet|wwan', caseSensitive: false);
    for (final interface in interfaces) {
      if (!preferredPattern.hasMatch(interface.name)) continue;
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4 &&
            !_isTailscaleAddress(address.address)) {
          return address.address;
        }
      }
    }
    for (final interface in interfaces) {
      final virtual = RegExp(
        r'tailscale|tun|docker|veth|virtual|loopback',
        caseSensitive: false,
      ).hasMatch(interface.name);
      if (virtual) continue;
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4) return address.address;
      }
    }
    return null;
  }

  Future<double?> _dnsLatency() async {
    final samples = <double>[];
    for (final host in const ['one.one.one.one', 'example.com', 'github.com']) {
      final stopwatch = Stopwatch()..start();
      try {
        final results = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 4));
        stopwatch.stop();
        if (results.isNotEmpty) {
          samples.add(stopwatch.elapsedMicroseconds / 1000);
        }
      } on Exception {
        // Keep successful samples; one failed lookup should not hide DNS health.
      }
    }
    if (samples.isEmpty) return null;
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  Future<String?> _systemDefaultGateway(List<ConnectionKind> kinds) async {
    final localRouterConnection = kinds.contains(ConnectionKind.wifi) ||
        kinds.contains(ConnectionKind.ethernet);
    if (!localRouterConnection) return null;
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'route',
          const ['print', '-4'],
          runInShell: false,
        ).timeout(const Duration(seconds: 3));
        return result.exitCode == 0
            ? parseWindowsDefaultGateway(result.stdout.toString())
            : null;
      }
      if (Platform.isAndroid || Platform.isLinux) {
        final content = await File('/proc/net/route')
            .readAsString()
            .timeout(const Duration(seconds: 2));
        return parseProcNetRouteGateway(content);
      }
    } on Exception {
      return null;
    }
    return null;
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

  bool _tailscaleDetected(
    _LocalNetworkData local,
    List<ConnectionKind> connectionKinds,
  ) {
    final namedInterface = local.interfaces.any(
      (interface) => interface.name.toLowerCase().contains('tailscale'),
    );
    final tailscaleIpv6 = local.addresses.any(
      (address) => address.toLowerCase().startsWith('fd7a:115c:a1e0:'),
    );
    final vpnRange = connectionKinds.contains(ConnectionKind.vpn) &&
        local.addresses.any(_isTailscaleAddress);
    return namedInterface || tailscaleIpv6 || vpnRange;
  }
}

class _LocalNetworkData {
  const _LocalNetworkData({required this.addresses, required this.interfaces});

  final List<String> addresses;
  final List<NetworkInterface> interfaces;
}

String? parseWindowsDefaultGateway(String routeOutput) {
  final candidates = <({String gateway, int metric})>[];
  final routePattern = RegExp(
    r'^\s*0\.0\.0\.0\s+0\.0\.0\.0\s+(\d{1,3}(?:\.\d{1,3}){3})\s+'
    r'\d{1,3}(?:\.\d{1,3}){3}\s+(\d+)\s*$',
    multiLine: true,
  );
  for (final match in routePattern.allMatches(routeOutput)) {
    final gateway = match.group(1);
    final metric = int.tryParse(match.group(2) ?? '');
    if (gateway != null && metric != null) {
      candidates.add((gateway: gateway, metric: metric));
    }
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => a.metric.compareTo(b.metric));
  return candidates.first.gateway;
}

String? parseProcNetRouteGateway(String routeTable) {
  for (final line in routeTable.split('\n').skip(1)) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length < 4 || fields[1] != '00000000') continue;
    final flags = int.tryParse(fields[3], radix: 16) ?? 0;
    if ((flags & 0x2) == 0) continue;
    final hex = fields[2];
    if (hex.length != 8) continue;
    final octets = <int>[];
    for (var index = 6; index >= 0; index -= 2) {
      final value = int.tryParse(hex.substring(index, index + 2), radix: 16);
      if (value == null) {
        octets.clear();
        break;
      }
      octets.add(value);
    }
    if (octets.length == 4 && octets.any((value) => value != 0)) {
      return octets.join('.');
    }
  }
  return null;
}
