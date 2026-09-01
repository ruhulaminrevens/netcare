import 'dart:convert';

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

  double get _downloadHealthScore => switch (downloadMbps) {
        <= 0 => 0,
        < 5 => downloadMbps / 5 * 8,
        < 10 => 8 + (downloadMbps - 5) / 5 * 5,
        < 25 => 13 + (downloadMbps - 10) / 15 * 8,
        < 50 => 21 + (downloadMbps - 25) / 25 * 4,
        _ => 25,
      };

  double get _uploadHealthScore => switch (uploadMbps) {
        <= 0 => 0,
        < 2 => uploadMbps / 2 * 4,
        < 5 => 4 + (uploadMbps - 2) / 3 * 4,
        < 10 => 8 + (uploadMbps - 5) / 5 * 4,
        < 20 => 12 + (uploadMbps - 10) / 10 * 3,
        _ => 15,
      };

  double get _latencyHealthScore => switch (pingMs) {
        <= 20 => 30,
        < 50 => 30 - (pingMs - 20) / 30 * 4,
        < 100 => 26 - (pingMs - 50) / 50 * 6,
        < 200 => 20 - (pingMs - 100) / 100 * 10,
        < 400 => 10 - (pingMs - 200) / 200 * 8,
        < 1000 => 2 - (pingMs - 400) / 600 * 2,
        _ => 0,
      };

  double get _jitterHealthScore => switch (jitterMs) {
        <= 3 => 20,
        < 10 => 20 - (jitterMs - 3) / 7 * 4,
        < 20 => 16 - (jitterMs - 10) / 10 * 4,
        < 40 => 12 - (jitterMs - 20) / 20 * 6,
        < 80 => 6 - (jitterMs - 40) / 40 * 5,
        < 200 => 1 - (jitterMs - 80) / 120,
        _ => 0,
      };

  double get _lossHealthScore {
    final loss = packetLossPercent ?? 0;
    return switch (loss) {
      <= 0 => 10,
      < 1 => 10 - loss * 2,
      < 3 => 8 - (loss - 1) / 2 * 3,
      < 5 => 5 - (loss - 3) / 2 * 3,
      < 10 => 2 - (loss - 5) / 5 * 2,
      _ => 0,
    };
  }

  int get speedHealthScore =>
      (_downloadHealthScore + _uploadHealthScore).round().clamp(0, 40).toInt();

  int get responsivenessHealthScore =>
      _latencyHealthScore.round().clamp(0, 30).toInt();

  int get stabilityHealthScore =>
      (_jitterHealthScore + _lossHealthScore).round().clamp(0, 30).toInt();

  int get healthScore => (_downloadHealthScore +
          _uploadHealthScore +
          _latencyHealthScore +
          _jitterHealthScore +
          _lossHealthScore)
      .round()
      .clamp(0, 100)
      .toInt();

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
