import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/ip_intelligence.dart';
import '../models/speed_test_result.dart';
import 'public_ip_service.dart';

enum SpeedTestMode { quick, balanced, deep }

extension SpeedTestModeDetails on SpeedTestMode {
  String get key => name;

  int get downloadBytesPerStream => switch (this) {
        SpeedTestMode.quick => 3 * 1024 * 1024,
        SpeedTestMode.balanced => 8 * 1024 * 1024,
        SpeedTestMode.deep => 20 * 1024 * 1024,
      };

  int get downloadStreams => switch (this) {
        SpeedTestMode.quick => 3,
        SpeedTestMode.balanced => 4,
        SpeedTestMode.deep => 4,
      };

  int get uploadBytesPerStream => switch (this) {
        SpeedTestMode.quick => 1024 * 1024,
        SpeedTestMode.balanced => 3 * 1024 * 1024,
        SpeedTestMode.deep => 5 * 1024 * 1024,
      };

  int get uploadStreams => switch (this) {
        SpeedTestMode.quick => 2,
        SpeedTestMode.balanced => 3,
        SpeedTestMode.deep => 4,
      };

  int get estimatedMegabytes =>
      ((downloadBytesPerStream * downloadStreams) +
              (uploadBytesPerStream * uploadStreams)) ~/
          (1024 * 1024);
}

class SpeedEndpointConfig {
  const SpeedEndpointConfig({
    required this.downloadBase,
    required this.uploadUrl,
    required this.pingUrl,
    this.serverLabel = 'Cloudflare edge',
  });

  final Uri downloadBase;
  final Uri uploadUrl;
  final Uri pingUrl;
  final String serverLabel;

  factory SpeedEndpointConfig.cloudflare() => SpeedEndpointConfig(
        downloadBase: Uri.https('speed.cloudflare.com', '/__down'),
        uploadUrl: Uri.https('speed.cloudflare.com', '/__up'),
        pingUrl: Uri.https('speed.cloudflare.com', '/__down'),
      );
}

typedef SpeedProgress = void Function(String stage, double fraction);

class SpeedTestCancelled implements Exception {
  const SpeedTestCancelled();
}

class SpeedTestService {
  HttpClient? _activeClient;
  bool _cancelled = false;

  Future<SpeedTestResult> run({
    SpeedTestMode mode = SpeedTestMode.balanced,
    SpeedEndpointConfig? endpoint,
    SpeedProgress? onProgress,
    String? localIp,
    String? gateway,
    PublicIpInfo? publicInfo,
    String? connectionType,
    String? ipAccessType,
    String? ipStability,
  }) async {
    cancel();
    _cancelled = false;
    final config = endpoint ?? SpeedEndpointConfig.cloudflare();
    final client = HttpClient()
      ..autoUncompress = false
      ..maxConnectionsPerHost = 8
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 15)
      ..userAgent = 'RAR-NetCare/1.1.2';
    _activeClient = client;

    try {
      onProgress?.call('Network information', 0.02);
      final resolvedPublicInfo = publicInfo ?? await PublicIpService().lookup();
      _throwIfCancelled();

      onProgress?.call('Warm-up', 0.05);
      await _warmUp(client, config.downloadBase);
      _throwIfCancelled();

      onProgress?.call('Ping & jitter', 0.08);
      final latency = await _latency(client, config.pingUrl, onProgress);
      _throwIfCancelled();

      onProgress?.call('Real download', 0.25);
      final download = await _download(client, config, mode, onProgress);
      _throwIfCancelled();

      onProgress?.call('Real upload', 0.72);
      final upload = await _upload(client, config, mode, onProgress);
      _throwIfCancelled();

      onProgress?.call('Complete', 1);
      return SpeedTestResult(
        timestamp: DateTime.now(),
        downloadMbps: download.mbps,
        uploadMbps: upload.mbps,
        pingMs: latency.$1,
        jitterMs: latency.$2,
        packetLossPercent: latency.$3,
        mode: mode.key,
        publicInfo: resolvedPublicInfo,
        server: _serverName(resolvedPublicInfo, config.serverLabel),
        localIp: localIp,
        gateway: gateway,
        connectionType: connectionType,
        ipAccessType: ipAccessType,
        ipStability: ipStability,
        downloadBytes: download.bytes,
        uploadBytes: upload.bytes,
        downloadDurationMs: download.durationMs,
        uploadDurationMs: upload.durationMs,
      );
    } on Exception {
      if (_cancelled) throw const SpeedTestCancelled();
      rethrow;
    } finally {
      client.close(force: true);
      if (identical(_activeClient, client)) _activeClient = null;
    }
  }

  void cancel() {
    _cancelled = true;
    _activeClient?.close(force: true);
    _activeClient = null;
  }

  Future<void> _warmUp(HttpClient client, Uri base) async {
    try {
      final uri = base.replace(queryParameters: {
        ...base.queryParameters,
        'bytes': '${128 * 1024}',
        'r': '${DateTime.now().microsecondsSinceEpoch}-warmup',
      });
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
    } on Exception {
      // The measured requests still provide a clear error if the endpoint is down.
    }
  }

  Future<(double, double, double)> _latency(
    HttpClient client,
    Uri base,
    SpeedProgress? onProgress,
  ) async {
    final samples = <double>[];
    var failures = 0;
    const warmupAttempts = 2;
    const measuredAttempts = 12;
    const totalAttempts = warmupAttempts + measuredAttempts;
    for (var index = 0; index < totalAttempts; index++) {
      _throwIfCancelled();
      final uri = base.replace(queryParameters: {
        ...base.queryParameters,
        'bytes': '1',
        'r': '${DateTime.now().microsecondsSinceEpoch}-$index',
      });
      final stopwatch = Stopwatch()..start();
      try {
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 3));
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        final response = await request.close().timeout(const Duration(seconds: 3));
        await response.drain<void>();
        stopwatch.stop();
        if (index < warmupAttempts) {
          // Ignore connection setup and TLS reuse effects in the final sample set.
        } else if (response.statusCode >= 200 && response.statusCode < 400) {
          samples.add(stopwatch.elapsedMicroseconds / 1000);
        } else {
          failures++;
        }
      } on Exception {
        if (index >= warmupAttempts) failures++;
      }
      onProgress?.call(
        'Ping & jitter',
        0.08 + ((index + 1) / totalAttempts) * 0.14,
      );
    }
    if (samples.isEmpty) {
      throw const SocketException('Latency server is unreachable');
    }
    final summary = summarizeLatencySamples(samples);
    return (
      summary.pingMs,
      summary.jitterMs,
      failures * 100 / measuredAttempts,
    );
  }

  Future<_TransferMeasurement> _download(
    HttpClient client,
    SpeedEndpointConfig config,
    SpeedTestMode mode,
    SpeedProgress? onProgress,
  ) async {
    var received = 0;
    final expected = mode.downloadBytesPerStream * mode.downloadStreams;
    final stopwatch = Stopwatch()..start();
    final tasks = List.generate(mode.downloadStreams, (index) async {
      final uri = config.downloadBase.replace(queryParameters: {
        ...config.downloadBase.queryParameters,
        'bytes': '${mode.downloadBytesPerStream}',
        'r': '${DateTime.now().microsecondsSinceEpoch}-$index',
      });
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException('Download returned ${response.statusCode}', uri: uri);
      }
      await for (final chunk in response) {
        _throwIfCancelled();
        received += chunk.length;
        final ratio = min(1.0, received / expected);
        onProgress?.call('Real download', 0.25 + ratio * 0.42);
      }
    });
    await Future.wait(tasks).timeout(const Duration(seconds: 60));
    stopwatch.stop();
    return _TransferMeasurement(
      mbps: megabitsPerSecond(received, stopwatch.elapsedMicroseconds),
      bytes: received,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<_TransferMeasurement> _upload(
    HttpClient client,
    SpeedEndpointConfig config,
    SpeedTestMode mode,
    SpeedProgress? onProgress,
  ) async {
    final payload = Uint8List(mode.uploadBytesPerStream);
    for (var index = 0; index < payload.length; index += 4096) {
      payload[index] = index % 251;
    }
    var sent = 0;
    final expected = mode.uploadBytesPerStream * mode.uploadStreams;
    final stopwatch = Stopwatch()..start();
    final tasks = List.generate(mode.uploadStreams, (index) async {
      final uri = config.uploadUrl.replace(queryParameters: {
        ...config.uploadUrl.queryParameters,
        'r': '${DateTime.now().microsecondsSinceEpoch}-$index',
      });
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.binary;
      request.contentLength = payload.length;
      const chunkSize = 128 * 1024;
      for (var offset = 0; offset < payload.length; offset += chunkSize) {
        _throwIfCancelled();
        final end = min(offset + chunkSize, payload.length);
        request.add(Uint8List.sublistView(payload, offset, end));
        sent += end - offset;
        if (offset % (1024 * 1024) == 0) await request.flush();
        final ratio = min(1.0, sent / expected);
        onProgress?.call('Real upload', 0.72 + ratio * 0.25);
      }
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException('Upload returned ${response.statusCode}', uri: uri);
      }
    });
    await Future.wait(tasks).timeout(const Duration(seconds: 90));
    stopwatch.stop();
    return _TransferMeasurement(
      mbps: megabitsPerSecond(sent, stopwatch.elapsedMicroseconds),
      bytes: sent,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  void _throwIfCancelled() {
    if (_cancelled) throw const SpeedTestCancelled();
  }

  String _serverName(PublicIpInfo? info, String fallback) {
    final edge = info?.edge?.trim();
    return edge == null || edge.isEmpty ? fallback : '$fallback · $edge';
  }
}

typedef LatencySummary = ({double pingMs, double jitterMs});

LatencySummary summarizeLatencySamples(List<double> chronologicalSamples) {
  if (chronologicalSamples.isEmpty) {
    return (pingMs: 0, jitterMs: 0);
  }
  final ping = _median(chronologicalSamples);
  if (chronologicalSamples.length == 1) {
    return (pingMs: ping, jitterMs: 0);
  }
  final deltas = <double>[];
  for (var index = 1; index < chronologicalSamples.length; index++) {
    deltas.add(
      (chronologicalSamples[index] - chronologicalSamples[index - 1]).abs(),
    );
  }
  return (pingMs: ping, jitterMs: _median(deltas));
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

class _TransferMeasurement {
  const _TransferMeasurement({
    required this.mbps,
    required this.bytes,
    required this.durationMs,
  });

  final double mbps;
  final int bytes;
  final int durationMs;
}

double megabitsPerSecond(int bytes, int elapsedMicroseconds) {
  if (bytes <= 0 || elapsedMicroseconds <= 0) return 0;
  return (bytes * 8) / (elapsedMicroseconds / 1000000) / 1000000;
}
