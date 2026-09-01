import 'ip_intelligence.dart';

class NetworkProfile {
  const NetworkProfile({
    this.name = '',
    this.gateway = '',
    this.routerWanIp = '',
    this.switchIp = '',
    this.serverIp = '',
    this.remoteHost = '',
    this.remotePort = 3389,
  });

  final String name;
  final String gateway;
  final String routerWanIp;
  final String switchIp;
  final String serverIp;
  final String remoteHost;
  final int remotePort;

  Map<String, dynamic> toJson() => {
        'name': name,
        'gateway': gateway,
        'routerWanIp': routerWanIp,
        'switchIp': switchIp,
        'serverIp': serverIp,
        'remoteHost': remoteHost,
        'remotePort': remotePort,
      };

  factory NetworkProfile.fromJson(Map<String, dynamic> json) => NetworkProfile(
        name: json['name']?.toString() ?? '',
        gateway: json['gateway']?.toString() ?? '',
        routerWanIp: json['routerWanIp']?.toString() ?? '',
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

enum ConnectionKind { wifi, mobile, ethernet, vpn, bluetooth, other, none }

class NetworkSnapshot {
  const NetworkSnapshot({
    required this.timestamp,
    required this.internetAvailable,
    required this.localAddresses,
    required this.connectionKinds,
    required this.dnsLatencyMs,
    required this.tailscaleDetected,
    required this.checks,
    this.activeLocalIp,
    this.wifiIp,
    this.gateway,
    this.routerWanIp,
    this.publicInfo,
    this.ipObservation,
  });

  final DateTime timestamp;
  final bool internetAvailable;
  final List<String> localAddresses;
  final List<ConnectionKind> connectionKinds;
  final double? dnsLatencyMs;
  final bool tailscaleDetected;
  final List<EndpointCheck> checks;
  final String? activeLocalIp;
  final String? wifiIp;
  final String? gateway;
  final String? routerWanIp;
  final PublicIpInfo? publicInfo;
  final IpObservation? ipObservation;

  bool get isMobile => connectionKinds.contains(ConnectionKind.mobile);
  bool get isWifi => connectionKinds.contains(ConnectionKind.wifi);
  bool get hasVpn => connectionKinds.contains(ConnectionKind.vpn);

  IpAccessType get ipAccessType {
    final publicIp = publicInfo?.ip.trim();
    if (publicIp == null || publicIp.isEmpty) return IpAccessType.unknown;
    if (localAddresses.any((address) => address.trim() == publicIp)) {
      return IpAccessType.directPublic;
    }

    final wan = routerWanIp?.trim();
    if (wan != null && wan.isNotEmpty) {
      if (isCgnatIpv4(wan)) {
        return IpAccessType.cgnatConfirmed;
      }
      if (isPrivateIpv4(wan)) return IpAccessType.upstreamNatOrVpn;
      if (isPublicIpv4(wan)) {
        return wan == publicIp
            ? IpAccessType.publicAtRouter
            : IpAccessType.upstreamNatOrVpn;
      }
    }

    if (isMobile &&
        (isPrivateIpv4(activeLocalIp) || isCgnatIpv4(activeLocalIp))) {
      return IpAccessType.sharedLikely;
    }
    if (isPrivateIpv4(activeLocalIp) || isCgnatIpv4(activeLocalIp)) {
      return IpAccessType.natUnverified;
    }
    return IpAccessType.unknown;
  }

  IpStability get ipStability {
    final observation = ipObservation;
    if (observation == null || observation.observationCount <= 1) {
      return observation?.everChanged == true
          ? IpStability.dynamicDetected
          : IpStability.firstObservation;
    }
    return observation.everChanged
        ? IpStability.dynamicDetected
        : IpStability.stableObserved;
  }

  NetworkSnapshot withIpObservation(IpObservation? observation) {
    return NetworkSnapshot(
      timestamp: timestamp,
      internetAvailable: internetAvailable,
      localAddresses: localAddresses,
      connectionKinds: connectionKinds,
      dnsLatencyMs: dnsLatencyMs,
      tailscaleDetected: tailscaleDetected,
      checks: checks,
      activeLocalIp: activeLocalIp,
      wifiIp: wifiIp,
      gateway: gateway,
      routerWanIp: routerWanIp,
      publicInfo: publicInfo,
      ipObservation: observation,
    );
  }
}

String networkObservationScope(
  NetworkSnapshot snapshot, {
  String profileName = '',
}) {
  final kinds = snapshot.connectionKinds.map((kind) => kind.name).toList()
    ..sort();
  final parts = <String>['v2', kinds.join('+')];
  final trimmedProfile = profileName.trim();
  if (trimmedProfile.isNotEmpty) {
    parts.add('profile:$trimmedProfile');
  }
  final asn = snapshot.publicInfo?.asn;
  if (asn != null) {
    parts.add('asn:$asn');
  } else {
    final provider = snapshot.publicInfo?.providerName?.trim();
    if (provider != null && provider.isNotEmpty) {
      parts.add('provider:$provider');
    }
  }
  final gateway = snapshot.gateway?.trim();
  if (!snapshot.isMobile && gateway != null && gateway.isNotEmpty) {
    parts.add('gateway:$gateway');
  }
  return parts.join('|');
}
