import 'dart:convert';

class SpeedTestResult {
  const SpeedTestResult({
    required this.timestamp,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.pingMs,
    required this.jitterMs,
    required this.mode,
    this.packetLossPercent,
    this.publicIp,
    this.isp,
    this.server,
    this.localIp,
    this.gateway,
  });

  final DateTime timestamp;
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;
  final double jitterMs;
  final double? packetLossPercent;
  final String mode;
  final String? publicIp;
  final String? isp;
  final String? server;
  final String? localIp;
  final String? gateway;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'downloadMbps': downloadMbps,
        'uploadMbps': uploadMbps,
        'pingMs': pingMs,
        'jitterMs': jitterMs,
        'packetLossPercent': packetLossPercent,
        'mode': mode,
        'publicIp': publicIp,
        'isp': isp,
        'server': server,
        'localIp': localIp,
        'gateway': gateway,
      };

  factory SpeedTestResult.fromJson(Map<String, dynamic> json) {
    double readNumber(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return SpeedTestResult(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      downloadMbps: readNumber('downloadMbps'),
      uploadMbps: readNumber('uploadMbps'),
      pingMs: readNumber('pingMs'),
      jitterMs: readNumber('jitterMs'),
      packetLossPercent: (json['packetLossPercent'] as num?)?.toDouble(),
      mode: json['mode']?.toString() ?? 'balanced',
      publicIp: json['publicIp']?.toString(),
      isp: json['isp']?.toString(),
      server: json['server']?.toString(),
      localIp: json['localIp']?.toString(),
      gateway: json['gateway']?.toString(),
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
