class NetworkProfile {
  const NetworkProfile({
    this.name = '',
    this.gateway = '',
    this.switchIp = '',
    this.serverIp = '',
    this.remoteHost = '',
    this.remotePort = 3389,
  });

  final String name;
  final String gateway;
  final String switchIp;
  final String serverIp;
  final String remoteHost;
  final int remotePort;

  Map<String, dynamic> toJson() => {
        'name': name,
        'gateway': gateway,
        'switchIp': switchIp,
        'serverIp': serverIp,
        'remoteHost': remoteHost,
        'remotePort': remotePort,
      };

  factory NetworkProfile.fromJson(Map<String, dynamic> json) => NetworkProfile(
        name: json['name']?.toString() ?? '',
        gateway: json['gateway']?.toString() ?? '',
        switchIp: json['switchIp']?.toString() ?? '',
        serverIp: json['serverIp']?.toString() ?? '',
        remoteHost: json['remoteHost']?.toString() ?? '',
        remotePort: (json['remotePort'] as num?)?.toInt() ?? 3389,
      );
}

class EndpointCheck {
  const EndpointCheck({
    required this.label,
    required this.host,
    required this.port,
    required this.reachable,
    required this.latencyMs,
    this.note,
  });

  final String label;
  final String host;
  final int port;
  final bool reachable;
  final double latencyMs;
  final String? note;
}

class NetworkSnapshot {
  const NetworkSnapshot({
    required this.timestamp,
    required this.internetAvailable,
    required this.localAddresses,
    required this.dnsLatencyMs,
    required this.tailscaleDetected,
    required this.checks,
    this.wifiIp,
    this.gateway,
  });

  final DateTime timestamp;
  final bool internetAvailable;
  final List<String> localAddresses;
  final double? dnsLatencyMs;
  final bool tailscaleDetected;
  final List<EndpointCheck> checks;
  final String? wifiIp;
  final String? gateway;
}
