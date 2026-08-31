import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/speed_test_result.dart';

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
    this.metadataUrl,
    this.serverLabel = 'Cloudflare edge',
  });

  final Uri downloadBase;
  final Uri uploadUrl;
  final Uri pingUrl;
  final Uri? metadataUrl;
  final String serverLabel;

  factory SpeedEndpointConfig.cloudflare() => SpeedEndpointConfig(
        downloadBase: Uri.https('speed.cloudflare.com', '/__down'),
        uploadUrl: Uri.https('speed.cloudflare.com', '/__up'),
        pingUrl: Uri.https('speed.cloudflare.com', '/__down'),
        metadataUrl: Uri.https('speed.cloudflare.com', '/meta'),
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
  }) async {
    cancel();
    _cancelled = false;
    final config = endpoint ?? SpeedEndpointConfig.cloudflare();
    final client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10)
      ..userAgent = 'Ruhul-NetCare/1.0.0';
    _activeClient = client;

    try {
      onProgress?.call('Metadata', 0.03);
      final metadata = await _metadata(client, config.metadataUrl);
      _throwIfCancelled();

      onProgress?.call('Ping & jitter', 0.08);
      final latency = await _latency(client, config.pingUrl, onProgress);
      _throwIfCancelled();

      onProgress?.call('Download', 0.25);
      final download = await _download(client, config, mode, onProgress);
      _throwIfCancelled();

      onProgress?.call('Upload', 0.72);
      final upload = await _upload(client, config, mode, onProgress);
      _throwIfCancelled();

      onProgress?.call('Complete', 1);
      return SpeedTestResult(
        timestamp: DateTime.now(),
        downloadMbps: download,
        uploadMbps: upload,
        pingMs: latency.$1,
        jitterMs: latency.$2,
        packetLossPercent: latency.$3,
        mode: mode.key,
        publicIp: metadata['clientIp']?.toString(),
        isp: metadata['asOrganization']?.toString(),
        server: _serverName(metadata, config.serverLabel),
        localIp: localIp,
        gateway: gateway,
      );
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

  Future<Map<String, dynamic>> _metadata(
    HttpClient client,
    Uri? uri,
  ) async {
    if (uri == null) return const {};
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(const Duration(seconds: 5));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const {};
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } on Exception {
      return const {};
    }
  }

  Future<(double, double, double)> _latency(
    HttpClient client,
    Uri base,
    SpeedProgress? onProgress,
  ) async {
    final samples = <double>[];
    var failures = 0;
    const attempts = 8;
    for (var index = 0; index < attempts; index++) {
      _throwIfCancelled();
      final uri = base.replace(queryParameters: {
        ...base.queryParameters,
        'bytes': '0',
        'r': '${DateTime.now().microsecondsSinceEpoch}-$index',
      });
      final stopwatch = Stopwatch()..start();
      try {
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 3));
        request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        final response = await request.close().timeout(const Duration(seconds: 3));
        await response.drain<void>();
        stopwatch.stop();
        if (response.statusCode >= 200 && response.statusCode < 400) {
          samples.add(stopwatch.elapsedMicroseconds / 1000);
        } else {
          failures++;
        }
      } on Exception {
        failures++;
      }
      onProgress?.call('Ping & jitter', 0.08 + ((index + 1) / attempts) * 0.14);
    }
    if (samples.isEmpty) {
      throw const SocketException('Latency server is unreachable');
    }
    samples.sort();
    final ping = samples.length > 2
        ? samples.sublist(1, samples.length - 1).reduce((a, b) => a + b) /
            (samples.length - 2)
        : samples.reduce((a, b) => a + b) / samples.length;
    var jitter = 0.0;
    for (var index = 1; index < samples.length; index++) {
      jitter += (samples[index] - samples[index - 1]).abs();
    }
    if (samples.length > 1) jitter /= samples.length - 1;
    return (ping, jitter, failures * 100 / attempts);
  }

  Future<double> _download(
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
        onProgress?.call('Download', 0.25 + ratio * 0.42);
      }
    });
    await Future.wait(tasks).timeout(const Duration(seconds: 45));
    stopwatch.stop();
    return megabitsPerSecond(received, stopwatch.elapsedMicroseconds);
  }

  Future<double> _upload(
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
      const chunkSize = 64 * 1024;
      for (var offset = 0; offset < payload.length; offset += chunkSize) {
        _throwIfCancelled();
        final end = min(offset + chunkSize, payload.length);
        request.add(Uint8List.sublistView(payload, offset, end));
        sent += end - offset;
        final ratio = min(1.0, sent / expected);
        onProgress?.call('Upload', 0.72 + ratio * 0.25);
      }
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException('Upload returned ${response.statusCode}', uri: uri);
      }
    });
    await Future.wait(tasks).timeout(const Duration(seconds: 60));
    stopwatch.stop();
    return megabitsPerSecond(sent, stopwatch.elapsedMicroseconds);
  }

  void _throwIfCancelled() {
    if (_cancelled) throw const SpeedTestCancelled();
  }

  String _serverName(Map<String, dynamic> metadata, String fallback) {
    final city = metadata['city']?.toString();
    final colo = metadata['colo']?.toString();
    final parts = [city, colo].where((item) => item != null && item.isNotEmpty);
    return parts.isEmpty ? fallback : parts.join(' · ');
  }
}

double megabitsPerSecond(int bytes, int elapsedMicroseconds) {
  if (bytes <= 0 || elapsedMicroseconds <= 0) return 0;
  return (bytes * 8) / (elapsedMicroseconds / 1000000) / 1000000;
}
