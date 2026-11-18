import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('rar_netcare/monitor');
const _hourMs = 3600000;

class AdapterReading {
  const AdapterReading(
    this.id,
    this.name,
    this.description,
    this.type,
    this.physical,
    this.up,
    this.rx,
    this.tx,
    this.linkSpeed,
  );

  factory AdapterReading.decode(Map<Object?, Object?> row) => AdapterReading(
    row['id'] as String,
    row['name'] as String,
    row['description'] as String,
    row['type'] as int,
    row['physical'] as bool,
    row['up'] as bool,
    row['rx'] as int,
    row['tx'] as int,
    row['link'] as int,
  );

  final String id, name, description;
  final int type, rx, tx, linkSpeed;
  final bool physical, up;
  bool get automatic =>
      physical && (type == 6 || type == 71 || type == 243 || type == 244);
}

class TrafficPoint {
  const TrafficPoint(this.time, this.rx, this.tx);
  final DateTime time;
  final double rx, tx;
}

class UsageBucket {
  UsageBucket(this.hour, this.rx, this.tx, this.seconds);
  final int hour;
  double rx, tx, seconds;

  List<num> toJson() => [hour, rx, tx, seconds];
}

class TrafficMonitor extends ChangeNotifier {
  TrafficMonitor() {
    _load();
  }

  static const _key = 'desktop_monitor_v1';
  final _clock = Stopwatch()..start();
  final _points = <TrafficPoint>[];
  final _usage = <int, UsageBucket>{};
  final _probes = <int?>[];
  Timer? _ticker, _probeTicker;
  SharedPreferences? _preferences;
  List<AdapterReading> adapters = const [];
  Map<String, AdapterReading> _previous = const {};
  int? _previousTick;
  int _lastSave = 0;
  bool _busy = false, _probing = false, _disposed = false, _saving = false;
  bool overlay = false, qualityEnabled = false;
  bool ready = false;
  String adapterId = '';
  String? error, qualityError, settingsError;
  double monthlyGb = 0;
  TrafficPoint? current;

  List<TrafficPoint> get points => List.unmodifiable(_points);
  int? get latency => _probes.isEmpty ? null : _probes.last;
  double? get loss => _probes.isEmpty
      ? null
      : _probes.where((sample) => sample == null).length * 100 / _probes.length;
  double? get jitter {
    final changes = <int>[];
    for (var i = 1; i < _probes.length; i++) {
      final a = _probes[i - 1];
      final b = _probes[i];
      if (a != null && b != null) changes.add((b - a).abs());
    }
    return changes.isEmpty
        ? null
        : changes.reduce((a, b) => a + b) / changes.length;
  }

  Future<void> _load() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final raw = jsonDecode(_preferences!.getString(_key) ?? '{}');
      if (raw is Map) {
        adapterId = raw['adapter'] is String ? raw['adapter'] as String : '';
        monthlyGb = raw['budget'] is num
            ? (raw['budget'] as num).toDouble()
            : 0;
        qualityEnabled = raw['quality'] == true;
        final buckets = raw['usage'];
        if (buckets is List) {
          for (final row in buckets) {
            if (row is! List ||
                row.length != 4 ||
                row[0] is! int ||
                row.skip(1).any((item) => item is! num)) {
              continue;
            }
            _usage[row[0] as int] = UsageBucket(
              row[0] as int,
              (row[1] as num).toDouble(),
              (row[2] as num).toDouble(),
              (row[3] as num).toDouble(),
            );
          }
        }
      }
    } on Exception {
      settingsError = 'Saved monitor settings could not be loaded.';
    }
    if (_disposed) return;
    ready = true;
    _prune();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
    _configureProbe();
    await _sample();
  }

  Iterable<UsageBucket> get usage => _usage.values;

  void selectAdapter(String id) {
    if (!ready || id == adapterId) return;
    adapterId = id;
    current = null;
    _points.clear();
    _notify();
    _save();
  }

  void setBudget(double value) {
    if (!ready || !value.isFinite || value < 0) return;
    monthlyGb = value;
    _notify();
    _save();
  }

  void setQuality(bool enabled) {
    if (!ready) return;
    qualityEnabled = enabled;
    _configureProbe();
    _notify();
    _save();
  }

  void resetChart() {
    _points.clear();
    _notify();
  }

  Future<void> setOverlay(bool visible) async {
    try {
      await _channel.invokeMethod<void>('overlay', visible);
      overlay = visible;
      _updateOverlay();
      _notify();
    } on Exception {
      error = 'The mini meter could not be opened.';
      _notify();
    }
  }

  Future<void> _updateOverlay() async {
    final reading = current;
    if (!overlay) return;
    try {
      await _channel.invokeMethod<void>('display', [
        reading == null ? '—' : formatRate(reading.rx),
        reading == null ? '—' : formatRate(reading.tx),
      ]);
    } on Exception {
      overlay = false;
    }
  }

  Future<void> _sample() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'adapters',
      );
      if (_disposed) return;
      if (rows == null) throw const FormatException('Adapter readings missing');
      adapters = rows.map(AdapterReading.decode).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final ticks = _clock.elapsedMicroseconds;
      final now = DateTime.now();
      final previousTick = _previousTick;
      current = null;
      if (previousTick != null) {
        final seconds = (ticks - previousTick) / 1e6;
        // Discard intervals spanning suspend or a stalled counter read.
        if (seconds > 0 && seconds <= 10) {
          var rx = 0, tx = 0, totalRx = 0, totalTx = 0;
          var found = false, physicalFound = false;
          for (final adapter in adapters) {
            final old = _previous[adapter.id];
            if (old == null ||
                !old.up ||
                !adapter.up ||
                adapter.rx < old.rx ||
                adapter.tx < old.tx) {
              continue;
            }
            final deltaRx = adapter.rx - old.rx, deltaTx = adapter.tx - old.tx;
            if (adapter.automatic) {
              physicalFound = true;
              totalRx += deltaRx;
              totalTx += deltaTx;
            }
            if (adapterId.isEmpty
                ? adapter.automatic
                : adapter.id == adapterId) {
              found = true;
              rx += deltaRx;
              tx += deltaTx;
            }
          }
          if (physicalFound) _recordUsage(now, seconds, totalRx, totalTx);
          if (found) {
            current = TrafficPoint(now, rx * 8 / seconds, tx * 8 / seconds);
            _points.add(current!);
          }
          final cutoff = now.subtract(const Duration(hours: 1));
          _points.removeWhere((point) => point.time.isBefore(cutoff));
          if (_points.length > 3700) {
            _points.removeRange(0, _points.length - 3700);
          }
        }
      }
      _previousTick = ticks;
      _previous = {for (final adapter in adapters) adapter.id: adapter};
      error = null;
      _prune();
      if (_clock.elapsedMilliseconds - _lastSave >= 10000) {
        _lastSave = _clock.elapsedMilliseconds;
        _save();
      }
    } on Exception {
      error = 'Windows adapter counters are unavailable.';
      _previousTick = null;
      _previous = const {};
      current = null;
    } finally {
      _busy = false;
      _updateOverlay();
      _notify();
    }
  }

  void _recordUsage(DateTime now, double seconds, int rx, int tx) {
    final end = now.millisecondsSinceEpoch.toDouble();
    final start = end - seconds * 1000;
    final firstHour = (start / _hourMs).floor();
    final lastHour = (end / _hourMs).floor();
    for (var hour = firstHour; hour <= lastHour; hour++) {
      final overlap =
          math.min(end, (hour + 1) * _hourMs) - math.max(start, hour * _hourMs);
      if (overlap <= 0) continue;
      final fraction = overlap / (seconds * 1000);
      final bucket = _usage.putIfAbsent(hour, () => UsageBucket(hour, 0, 0, 0));
      bucket.rx += rx * fraction;
      bucket.tx += tx * fraction;
      bucket.seconds += overlap / 1000;
    }
  }

  void _prune() {
    final cutoff =
        DateTime.now()
            .subtract(const Duration(days: 92))
            .millisecondsSinceEpoch ~/
        _hourMs;
    _usage.removeWhere((hour, _) => hour < cutoff);
  }

  bool _saveAgain = false;

  Future<void> _save() async {
    final prefs = _preferences;
    if (prefs == null) return;
    if (_saving) {
      _saveAgain = true;
      return;
    }
    _saving = true;
    try {
      do {
        _saveAgain = false;
        final stored = await prefs.setString(
          _key,
          jsonEncode({
            'adapter': adapterId,
            'budget': monthlyGb,
            'quality': qualityEnabled,
            'usage': _usage.values.map((bucket) => bucket.toJson()).toList(),
          }),
        );
        if (!stored) {
          throw const FileSystemException('Monitor settings write failed');
        }
        settingsError = null;
      } while (_saveAgain);
    } on Exception {
      settingsError = 'Monitoring history could not be saved.';
    } finally {
      _saving = false;
      _notify();
    }
  }

  int _probeGeneration = 0;
  void _configureProbe() {
    _probeTicker?.cancel();
    _probeGeneration++;
    _probes.clear();
    qualityError = null;
    if (!qualityEnabled) return;
    _probeTicker = Timer.periodic(const Duration(seconds: 5), (_) => _probe());
    _probe();
  }

  Future<void> _probe() async {
    if (_probing || _disposed || !qualityEnabled) return;
    _probing = true;
    final generation = _probeGeneration;
    try {
      final result = await runWindowsCommand('PING.EXE', const [
        '-4',
        '-n',
        '1',
        '-w',
        '1250',
        '1.1.1.1',
      ]);
      if (_disposed || _probeGeneration != generation) return;
      final output = result.stdout.toString();
      final match = RegExp(
        r'[=<]\s*(\d+)\s*ms[^\r\n]*TTL\s*=',
        caseSensitive: false,
      ).firstMatch(output);
      _probes.add(match == null ? null : int.parse(match.group(1)!));
      if (_probes.length > 20) _probes.removeAt(0);
      qualityError = null;
    } on Exception {
      if (_probeGeneration == generation) {
        qualityError = 'ICMP probe unavailable';
      }
    } finally {
      _probing = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _probeTicker?.cancel();
    _save();
    super.dispose();
  }
}

Future<ProcessResult> runWindowsCommand(
  String command,
  List<String> args,
) async {
  final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  final process = await Process.start('$root\\System32\\$command', args);
  Future<String> capture(Stream<List<int>> stream) =>
      systemEncoding.decoder.bind(stream).join();
  try {
    final result = await Future.wait<Object>([
      process.exitCode,
      capture(process.stdout),
      capture(process.stderr),
    ]).timeout(const Duration(seconds: 12));
    return ProcessResult(process.pid, result[0] as int, result[1], result[2]);
  } on TimeoutException {
    process.kill();
    rethrow;
  }
}

String formatRate(double bits) {
  if (bits >= 1e9) return '${(bits / 1e9).toStringAsFixed(2)} Gbps';
  if (bits >= 1e6) return '${(bits / 1e6).toStringAsFixed(2)} Mbps';
  if (bits >= 1e3) return '${(bits / 1e3).toStringAsFixed(1)} Kbps';
  return '${bits.toStringAsFixed(0)} bps';
}

String formatData(double bytes) {
  if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(2)} GB';
  if (bytes >= 1e6) return '${(bytes / 1e6).toStringAsFixed(2)} MB';
  if (bytes >= 1e3) return '${(bytes / 1e3).toStringAsFixed(1)} KB';
  return '${bytes.toStringAsFixed(0)} B';
}
