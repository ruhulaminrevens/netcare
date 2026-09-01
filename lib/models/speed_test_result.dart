import 'dart:convert';
import 'dart:math';

import 'ip_intelligence.dart';

class SpeedTestResult {
  const SpeedTestResult({
    required this.timestamp,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.pingMs,
    required this.jitterMs,
    required this.mode,
    this.packetLossPercent,
    this.publicInfo,
    this.server,
    this.localIp,
    this.gateway,
    this.connectionType,
    this.ipAccessType,
    this.ipStability,
    this.downloadBytes = 0,
    this.uploadBytes = 0,
    this.downloadDurationMs = 0,
    this.uploadDurationMs = 0,
  });

  final DateTime timestamp;
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;
  final double jitterMs;
  final double? packetLossPercent;
  final String mode;
  final PublicIpInfo? publicInfo;
  final String? server;
  final String? localIp;
  final String? gateway;
  final String? connectionType;
  final String? ipAccessType;
  final String? ipStability;
  final int downloadBytes;
  final int uploadBytes;
  final int downloadDurationMs;
  final int uploadDurationMs;

  String? get publicIp => publicInfo?.ip;
  String? get isp => publicInfo?.providerName;
  String? get location => publicInfo?.locationLabel;

  double get transferredMegabytes =>
      (downloadBytes + uploadBytes) / (1024 * 1024);

  double get testDurationSeconds =>
      (downloadDurationMs + uploadDurationMs) / 1000;

  int get healthScore {
    var score = 100.0;
    score -= max(0, pingMs - 20) * .35;
    score -= max(0, jitterMs - 3) * 1.2;
    score -= (packetLossPercent ?? 0) * 12;
    if (downloadMbps < 5) score -= (5 - downloadMbps) * 5;
    if (uploadMbps < 2) score -= (2 - uploadMbps) * 8;
    return score.round().clamp(0, 100).toInt();
  }

  String get healthGrade => switch (healthScore) {
        >= 90 => 'Excellent',
        >= 75 => 'Good',
        >= 55 => 'Fair',
        _ => 'Poor',
      };

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'downloadMbps': downloadMbps,
        'uploadMbps': uploadMbps,
        'pingMs': pingMs,
        'jitterMs': jitterMs,
        'packetLossPercent': packetLossPercent,
        'mode': mode,
        'publicInfo': publicInfo?.toJson(),
        'publicIp': publicIp,
        'isp': isp,
        'server': server,
        'localIp': localIp,
        'gateway': gateway,
        'connectionType': connectionType,
        'ipAccessType': ipAccessType,
        'ipStability': ipStability,
        'downloadBytes': downloadBytes,
        'uploadBytes': uploadBytes,
        'downloadDurationMs': downloadDurationMs,
        'uploadDurationMs': uploadDurationMs,
        'healthScore': healthScore,
      };

  factory SpeedTestResult.fromJson(Map<String, dynamic> json) {
    double readNumber(String key) => (json[key] as num?)?.toDouble() ?? 0;
    final nested = json['publicInfo'];
    PublicIpInfo? publicInfo;
    if (nested is Map) {
      final decoded = PublicIpInfo.fromJson(Map<String, dynamic>.from(nested));
      if (decoded.ip.isNotEmpty) publicInfo = decoded;
    } else {
      final publicIp = json['publicIp']?.toString();
      if (publicIp != null && publicIp.isNotEmpty) {
        publicInfo = PublicIpInfo(
          ip: publicIp,
          isp: json['isp']?.toString(),
          organization: json['isp']?.toString(),
        );
      }
    }
    return SpeedTestResult(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      downloadMbps: readNumber('downloadMbps'),
      uploadMbps: readNumber('uploadMbps'),
      pingMs: readNumber('pingMs'),
      jitterMs: readNumber('jitterMs'),
      packetLossPercent: (json['packetLossPercent'] as num?)?.toDouble(),
      mode: json['mode']?.toString() ?? 'balanced',
      publicInfo: publicInfo,
      server: json['server']?.toString(),
      localIp: json['localIp']?.toString(),
      gateway: json['gateway']?.toString(),
      connectionType: json['connectionType']?.toString(),
      ipAccessType: json['ipAccessType']?.toString(),
      ipStability: json['ipStability']?.toString(),
      downloadBytes: (json['downloadBytes'] as num?)?.toInt() ?? 0,
      uploadBytes: (json['uploadBytes'] as num?)?.toInt() ?? 0,
      downloadDurationMs: (json['downloadDurationMs'] as num?)?.toInt() ?? 0,
      uploadDurationMs: (json['uploadDurationMs'] as num?)?.toInt() ?? 0,
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
