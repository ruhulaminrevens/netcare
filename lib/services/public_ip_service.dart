import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/ip_intelligence.dart';

class PublicIpService {
  Future<PublicIpInfo?> lookup() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..idleTimeout = const Duration(seconds: 6)
      ..userAgent = 'RAR-NetCare/1.1.0';
    try {
      final results = await Future.wait<PublicIpInfo?>([
        _cloudflare(client),
        _ipWhoIs(client),
      ]);
      final cloudflare = results[0];
      final ipWhoIs = results[1];
      if (cloudflare == null) return ipWhoIs;
      return cloudflare.merge(ipWhoIs);
    } finally {
      client.close(force: true);
    }
  }

  Future<PublicIpInfo?> _cloudflare(HttpClient client) async {
    final json = await _readJson(
      client,
      Uri.https('speed.cloudflare.com', '/meta'),
    );
    if (json == null) return null;
    final ip = _text(json['clientIp']) ?? _text(json['ip']);
    if (ip == null) return null;
    return PublicIpInfo(
      ip: ip,
      version: ip.contains(':') ? 'IPv6' : 'IPv4',
      asn: _integer(json['asn']),
      isp: _text(json['asOrganization']),
      organization: _text(json['asOrganization']),
      city: _text(json['city']),
      region: _text(json['region']),
      country: _text(json['country']),
      countryCode: _text(json['countryCode']) ?? _text(json['country']),
      edge: _text(json['colo']),
    );
  }

  Future<PublicIpInfo?> _ipWhoIs(HttpClient client) async {
    final json = await _readJson(client, Uri.https('ipwho.is', '/'));
    if (json == null || json['success'] == false) return null;
    final ip = _text(json['ip']);
    if (ip == null) return null;
    final connection = json['connection'] is Map
        ? Map<String, dynamic>.from(json['connection'] as Map)
        : const <String, dynamic>{};
    final timezone = json['timezone'] is Map
        ? Map<String, dynamic>.from(json['timezone'] as Map)
        : const <String, dynamic>{};
    return PublicIpInfo(
      ip: ip,
      version: _text(json['type']),
      asn: _integer(connection['asn']),
      isp: _text(connection['isp']),
      organization: _text(connection['org']),
      domain: _text(connection['domain']),
      city: _text(json['city']),
      region: _text(json['region']),
      country: _text(json['country']),
      countryCode: _text(json['country_code']),
      timezone: _text(timezone['id']),
      latitude: _number(json['latitude']),
      longitude: _number(json['longitude']),
    );
  }

  Future<Map<String, dynamic>?> _readJson(HttpClient client, Uri uri) async {
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close().timeout(const Duration(seconds: 6));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : null;
    } on Exception {
      return null;
    }
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _integer(Object? value) => value is num ? value.toInt() : int.tryParse('$value');

  double? _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
}
