class PublicIpInfo {
  const PublicIpInfo({
    required this.ip,
    this.version,
    this.asn,
    this.isp,
    this.organization,
    this.domain,
    this.city,
    this.region,
    this.country,
    this.countryCode,
    this.timezone,
    this.latitude,
    this.longitude,
    this.edge,
  });

  final String ip;
  final String? version;
  final int? asn;
  final String? isp;
  final String? organization;
  final String? domain;
  final String? city;
  final String? region;
  final String? country;
  final String? countryCode;
  final String? timezone;
  final double? latitude;
  final double? longitude;
  final String? edge;

  String? get providerName => _firstText([isp, organization]);

  String? get locationLabel {
    final parts = <String>[];
    for (final value in [city, region, country]) {
      if (_hasText(value) && !parts.contains(value!.trim())) {
        parts.add(value.trim());
      }
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  PublicIpInfo merge(PublicIpInfo? other) {
    if (other == null) return this;
    return PublicIpInfo(
      ip: _firstText([ip, other.ip]) ?? ip,
      version: _firstText([version, other.version]),
      asn: asn ?? other.asn,
      isp: _firstText([isp, other.isp]),
      organization: _firstText([organization, other.organization]),
      domain: _firstText([domain, other.domain]),
      city: _firstText([city, other.city]),
      region: _firstText([region, other.region]),
      country: _firstText([country, other.country]),
      countryCode: _firstText([countryCode, other.countryCode]),
      timezone: _firstText([timezone, other.timezone]),
      latitude: latitude ?? other.latitude,
      longitude: longitude ?? other.longitude,
      edge: _firstText([edge, other.edge]),
    );
  }

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'version': version,
        'asn': asn,
        'isp': isp,
        'organization': organization,
        'domain': domain,
        'city': city,
        'region': region,
        'country': country,
        'countryCode': countryCode,
        'timezone': timezone,
        'latitude': latitude,
        'longitude': longitude,
        'edge': edge,
      };

  factory PublicIpInfo.fromJson(Map<String, dynamic> json) {
    return PublicIpInfo(
      ip: json['ip']?.toString() ?? '',
      version: json['version']?.toString(),
      asn: (json['asn'] as num?)?.toInt(),
      isp: json['isp']?.toString(),
      organization: json['organization']?.toString(),
      domain: json['domain']?.toString(),
      city: json['city']?.toString(),
      region: json['region']?.toString(),
      country: json['country']?.toString(),
      countryCode: json['countryCode']?.toString(),
      timezone: json['timezone']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      edge: json['edge']?.toString(),
    );
  }

  static String? _firstText(List<String?> values) {
    for (final value in values) {
      if (_hasText(value)) return value!.trim();
    }
    return null;
  }

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

class IpObservation {
  const IpObservation({
    required this.currentIp,
    required this.firstSeen,
    required this.lastSeen,
    required this.observationCount,
    required this.changedSinceLastCheck,
    required this.everChanged,
    this.previousIp,
  });

  final String currentIp;
  final String? previousIp;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int observationCount;
  final bool changedSinceLastCheck;
  final bool everChanged;
}

enum IpAccessType {
  directPublic,
  publicAtRouter,
  cgnatConfirmed,
  sharedLikely,
  upstreamNatOrVpn,
  natUnverified,
  unknown,
}

enum IpStability { firstObservation, stableObserved, dynamicDetected }

bool isCgnatIpv4(String? address) {
  final octets = _ipv4Octets(address);
  return octets != null && octets[0] == 100 && octets[1] >= 64 && octets[1] <= 127;
}

bool isPrivateIpv4(String? address) {
  final octets = _ipv4Octets(address);
  if (octets == null) return false;
  return octets[0] == 10 ||
      (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] == 192 && octets[1] == 168) ||
      (octets[0] == 169 && octets[1] == 254);
}

bool isPublicIpv4(String? address) {
  final octets = _ipv4Octets(address);
  if (octets == null) return false;
  if (isPrivateIpv4(address) || isCgnatIpv4(address)) return false;
  return octets[0] != 0 && octets[0] != 127 && octets[0] < 224;
}

List<int>? _ipv4Octets(String? address) {
  if (address == null) return null;
  final parts = address.trim().split('.');
  if (parts.length != 4) return null;
  final values = parts.map(int.tryParse).toList();
  if (values.any((value) => value == null || value < 0 || value > 255)) {
    return null;
  }
  return values.cast<int>();
}
