import 'meter_settings.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'traffic_monitor.dart';

const _rxColor = Color(0xFF4FB4FF);
const _txColor = Color(0xFF28D7AE);

class MonitorDashboard extends StatefulWidget {
  const MonitorDashboard({required this.monitor, super.key});
  final TrafficMonitor monitor;

  @override
  State<MonitorDashboard> createState() => _MonitorDashboardState();
}

class _MonitorDashboardState extends State<MonitorDashboard> {
  static const _ranges = {
    '10s': 10,
    '1m': 60,
    '5m': 300,
    '30m': 1800,
    '1h': 3600,
    '24h': 86400,
    '7d': 604800,
    '30d': 2592000,
    '90d': 7776000,
  };
  String _range = '1m';
  bool _download = true, _upload = true;
  ({DateTime end, List<TrafficPoint> points})? _paused;

  ({DateTime end, List<TrafficPoint> points}) _readChart() {
    final end = DateTime.now();
    final seconds = _ranges[_range]!;
    final start = end.subtract(Duration(seconds: seconds));
    if (seconds <= 3600) {
      return (
        end: end,
        points: widget.monitor.points
            .where((point) => !point.time.isBefore(start))
            .toList(),
      );
    }
    final groupHours = seconds <= 604800 ? 1 : 24;
    final groups = <int, UsageBucket>{};
    for (final bucket in widget.monitor.usage) {
      final hourStart = DateTime.fromMillisecondsSinceEpoch(
        bucket.hour * 3600000,
      );
      if (!hourStart.add(const Duration(hours: 1)).isAfter(start)) continue;
      final key = bucket.hour ~/ groupHours * groupHours;
      final group = groups.putIfAbsent(key, () => UsageBucket(key, 0, 0, 0));
      group.rx += bucket.rx;
      group.tx += bucket.tx;
      group.seconds += bucket.seconds;
    }
    final sorted = groups.values.toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
    return (
      end: end,
      points: [
        for (final bucket in sorted)
          if (bucket.seconds > 0)
            TrafficPoint(
              DateTime.fromMillisecondsSinceEpoch(
                (bucket.hour * 3600000 + groupHours * 1800000).clamp(
                  start.millisecondsSinceEpoch,
                  end.millisecondsSinceEpoch,
                ),
              ),
              bucket.rx * 8 / bucket.seconds,
              bucket.tx * 8 / bucket.seconds,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.monitor,
        builder: (context, _) {
          final monitor = widget.monitor;
          final reading = monitor.current;
          final trace = _paused ?? _readChart();
          final seconds = _ranges[_range]!;
          final history = seconds > 3600;
          final source = history || monitor.adapterId.isEmpty
              ? 'Automatic physical adapters'
              : monitor.selectedNames.isEmpty
                  ? 'Selected adapters offline'
                  : monitor.selectedNames;
          final qualityCaption = monitor.qualityEnabled
              ? monitor.qualityError ?? 'ICMP to 1.1.1.1 · rolling 20 probes'
              : 'Quality probes off';
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  _Heading('Traffic dashboard', source),
                  FilledButton.tonalIcon(
                    onPressed: () => monitor.setOverlay(!monitor.overlay),
                    icon: Icon(
                      monitor.overlay
                          ? Icons.visibility_off
                          : Icons.picture_in_picture_alt,
                    ),
                    label: Text(
                      monitor.overlay ? 'Hide mini meter' : 'Show mini meter',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    'Download',
                    reading == null ? '—' : formatRate(reading.rx),
                    _rxColor,
                  ),
                  _Metric(
                    'Upload',
                    reading == null ? '—' : formatRate(reading.tx),
                    _txColor,
                  ),
                  _Metric(
                    'Latency',
                    monitor.latency == null ? '—' : '${monitor.latency} ms',
                  ),
                  _Metric(
                    'Jitter',
                    monitor.jitter == null
                        ? '—'
                        : '${monitor.jitter!.toStringAsFixed(1)} ms',
                  ),
                  _Metric(
                    'Packet loss',
                    monitor.loss == null
                        ? '—'
                        : '${monitor.loss!.toStringAsFixed(0)}%',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(qualityCaption),
              if (monitor.error != null) Text(monitor.error!),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final range in _ranges.keys)
                            ChoiceChip(
                              label: Text(range),
                              selected: _range == range,
                              onSelected: (_) => setState(() {
                                _range = range;
                                _paused = null;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('Download'),
                            selected: _download,
                            selectedColor: _rxColor.withValues(alpha: .25),
                            onSelected: (value) =>
                                setState(() => _download = value),
                          ),
                          FilterChip(
                            label: const Text('Upload'),
                            selected: _upload,
                            selectedColor: _txColor.withValues(alpha: .25),
                            onSelected: (value) =>
                                setState(() => _upload = value),
                          ),
                          TextButton.icon(
                            icon: Icon(
                              _paused == null ? Icons.pause : Icons.play_arrow,
                            ),
                            label: Text(
                              _paused == null ? 'Pause graph' : 'Resume graph',
                            ),
                            onPressed: () => setState(() {
                              _paused = _paused == null ? _readChart() : null;
                            }),
                          ),
                          if (!history)
                            TextButton(
                              onPressed: () {
                                setState(() => _paused = null);
                                monitor.resetChart();
                              },
                              child: const Text('Reset graph'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 290,
                        width: double.infinity,
                        child: trace.points.isEmpty
                            ? Center(
                                child: Text(
                                  history
                                      ? 'No recorded usage in this range.'
                                      : 'Waiting for adapter samples…',
                                ),
                              )
                            : CustomPaint(
                                painter: _TrafficChart(
                                  trace.points,
                                  trace.end,
                                  seconds,
                                  _download,
                                  _upload,
                                  Theme.of(context).colorScheme,
                                  history
                                      ? (seconds <= 604800 ? 3600 : 86400)
                                      : 1,
                                ),
                              ),
                      ),
                      if (trace.points.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        if (_download)
                          _SeriesSummary(
                              'Download', trace.points.map((p) => p.rx)),
                        if (_upload)
                          _SeriesSummary(
                              'Upload', trace.points.map((p) => p.tx)),
                      ],
                      if (history)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Recorded physical-adapter traffic. Each point is an average for its recorded interval.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _TrafficChart extends CustomPainter {
  _TrafficChart(
    this.points,
    this.end,
    this.seconds,
    this.rx,
    this.tx,
    this.colors,
    this.step,
  );
  final List<TrafficPoint> points;
  final DateTime end;
  final int seconds, step;
  final bool rx, tx;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTRB(72, 14, size.width - 12, size.height - 30);
    if (area.width < 15) return;
    final maxRate = points.fold(
      1.0,
      (value, point) =>
          math.max(value, math.max(rx ? point.rx : 0, tx ? point.tx : 0)),
    );
    final grid = Paint()..color = colors.outlineVariant.withValues(alpha: .6);
    void label(String text, Offset position, {bool centered = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        centered ? position - Offset(painter.width / 2, 0) : position,
      );
    }

    for (var i = 0; i <= 4; i++) {
      final y = area.bottom - area.height * i / 4;
      final x = area.left + area.width * i / 4;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), grid);
      label(formatRate(maxRate * i / 4), Offset(0, y - 6));
      final age = (seconds * (4 - i) / 4).round();
      label(
        age == 0
            ? 'Now'
            : age >= 86400
                ? '${(age / 86400).toStringAsFixed(1)}d'
                : age >= 3600
                    ? '${(age / 3600).toStringAsFixed(1)}h'
                    : age >= 60
                        ? '${(age / 60).toStringAsFixed(1)}m'
                        : '${age}s',
        Offset(x, area.bottom + 8),
        centered: true,
      );
    }

    void series(bool download, Color color) {
      final line = Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      final dot = Paint()..color = color;
      Offset? previous;
      DateTime? previousTime;
      for (final point in points) {
        final age = end.difference(point.time).inMilliseconds / 1000;
        final offset = Offset(
          area.right - area.width * (age / seconds).clamp(0, 1),
          area.bottom -
              area.height * (download ? point.rx : point.tx) / maxRate,
        );
        if (previous != null &&
            point.time.difference(previousTime!).inMilliseconds <=
                step * 1800) {
          canvas.drawLine(previous, offset, line);
        } else {
          canvas.drawCircle(offset, 2, dot);
        }
        previous = offset;
        previousTime = point.time;
      }
    }

    if (rx) series(true, _rxColor);
    if (tx) series(false, _txColor);
  }

  @override
  bool shouldRepaint(_TrafficChart old) =>
      points != old.points ||
      end != old.end ||
      seconds != old.seconds ||
      rx != old.rx ||
      tx != old.tx ||
      colors != old.colors;
}

class _SeriesSummary extends StatelessWidget {
  const _SeriesSummary(this.label, this.values);
  final String label;
  final Iterable<double> values;

  @override
  Widget build(BuildContext context) => Text(
        '$label   Min ${formatRate(values.reduce(math.min))}   '
        'Avg ${formatRate(values.reduce((a, b) => a + b) / values.length)}   '
        'Peak ${formatRate(values.reduce(math.max))}',
      );
}

class MonitorAdapterPage extends StatefulWidget {
  const MonitorAdapterPage({required this.monitor, super.key});
  final TrafficMonitor monitor;

  @override
  State<MonitorAdapterPage> createState() => _AdapterState();
}

class _AdapterState extends State<MonitorAdapterPage> {
  TrafficMonitor get monitor => widget.monitor;
  String search = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: monitor,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _Heading(
              'Network adapters',
              'Choose which adapter feeds the live graph and mini meter.',
            ),
            const SizedBox(height: 14),
            TextField(
                decoration: const InputDecoration(
                    labelText: 'Search adapters',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => search = v.toLowerCase())),
            Text(monitor.adapterId.isEmpty
                ? 'Monitoring active physical adapters'
                : 'Monitoring: ${monitor.selectedNames}'),
            _adapterTile(
              '',
              'Automatic',
              'Active physical Ethernet, Wi-Fi and mobile broadband',
              true,
            ),
            if (monitor.error != null) Text(monitor.error!),
            if (monitor.adapterId.isNotEmpty && monitor.selectedNames.isEmpty)
              const ListTile(
                title: Text('Your selected adapter is currently unavailable.'),
              ),
            for (final adapter in monitor.adapters.where(
                (a) => (a.name + a.description).toLowerCase().contains(search)))
              _adapterTile(
                adapter.id,
                adapter.name,
                '${adapter.description}\n${adapter.physical ? 'Physical' : 'Virtual'} · '
                '${adapter.up ? 'Up' : 'Down'} · ${formatRate(adapter.linkSpeed.toDouble())}',
                adapter.up,
              ),
          ],
        ),
      );

  Widget _adapterTile(String id, String name, String details, bool up) => Card(
        child: ListTile(
          leading: Icon(
            (id.isEmpty
                    ? monitor.adapterId.isEmpty
                    : monitor.selectedIds.contains(id))
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
          ),
          title: Text(name),
          subtitle: Text(details),
          trailing: Icon(up ? Icons.lan_outlined : Icons.link_off),
          selected: (id.isEmpty
              ? monitor.adapterId.isEmpty
              : monitor.selectedIds.contains(id)),
          onTap: () => id.isEmpty
              ? monitor.selectAdapter(id)
              : monitor.toggleAdapter(id),
        ),
      );
}

class MonitorUsagePage extends StatefulWidget {
  const MonitorUsagePage({required this.monitor, super.key});
  final TrafficMonitor monitor;

  @override
  State<MonitorUsagePage> createState() => _MonitorUsagePageState();
}

class _MonitorUsagePageState extends State<MonitorUsagePage> {
  final _budget = TextEditingController();
  bool _loadedBudget = false;
  String? _budgetError;

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.monitor,
        builder: (context, _) {
          final monitor = widget.monitor;
          if (!_loadedBudget && monitor.ready) {
            _loadedBudget = true;
            if (monitor.monthlyGb > 0) {
              _budget.text = monitor.monthlyGb.toString();
            }
          }
          final now = DateTime.now();
          final month = DateTime(now.year, now.month);
          final days = <DateTime, UsageBucket>{};
          var monthlyTotal = 0.0;
          for (final bucket in monitor.usage) {
            final start = DateTime.fromMillisecondsSinceEpoch(
              bucket.hour * 3600000,
            );
            final end = start.add(const Duration(hours: 1));
            final day = DateTime(start.year, start.month, start.day);
            final nextDay = DateTime(day.year, day.month, day.day + 1);
            final covered = end.isAfter(nextDay)
                ? nextDay.difference(start).inSeconds / 3600
                : 1.0;
            void addDay(DateTime date, double share) {
              final group =
                  days.putIfAbsent(date, () => UsageBucket(0, 0, 0, 0));
              group.rx += bucket.rx * share;
              group.tx += bucket.tx * share;
              if (!date.isBefore(month) && !date.isAfter(now)) {
                monthlyTotal += (bucket.rx + bucket.tx) * share;
              }
            }

            addDay(day, covered);
            if (covered < 1) addDay(nextDay, 1 - covered);
          }
          final dates = days.keys.toList()..sort((a, b) => b.compareTo(a));
          final budget = monitor.monthlyGb * 1e9;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _Heading(
                'Usage & data plan',
                'Totals cover physical adapters while RAR NetCare is running.',
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatData(monthlyTotal)} this month',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (budget > 0) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (monthlyTotal / budget).clamp(0.0, 1.0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          monthlyTotal >= budget
                              ? 'Monthly data plan reached (${formatData(budget)}).'
                              : '${formatData(budget - monthlyTotal)} remaining of ${formatData(budget)}.',
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        runSpacing: 8,
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _budget,
                              enabled: monitor.ready,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Monthly limit (GB)',
                                helperText: '0 disables the limit',
                                errorText: _budgetError,
                              ),
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              final text = _budget.text.trim();
                              final value = double.tryParse(text);
                              final valid = value != null &&
                                  value.isFinite &&
                                  value >= 0 &&
                                  value <= 1e9;
                              setState(
                                () => _budgetError = valid
                                    ? null
                                    : 'Enter a limit from 0 to 1 billion GB.',
                              );
                              if (valid) monitor.setBudget(value);
                            },
                            child: const Text('Save limit'),
                          ),
                        ],
                      ),
                      PlanAlerts(monitor),
                      if (monitor.settingsError != null)
                        Text(monitor.settingsError!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Recent daily usage',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (dates.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('No usage has been recorded yet.'),
                ),
              for (final date in dates.take(30))
                ListTile(
                  title: Text(
                    MaterialLocalizations.of(context).formatFullDate(date),
                  ),
                  subtitle: Text(
                    'Down ${formatData(days[date]!.rx)} · Up ${formatData(days[date]!.tx)}',
                  ),
                  trailing: Text(formatData(days[date]!.rx + days[date]!.tx)),
                ),
            ],
          );
        },
      );
}

enum WindowsToolPage { wifi, processes, tools }

class MonitorToolPage extends StatefulWidget {
  const MonitorToolPage({required this.page, required this.monitor, super.key});
  final WindowsToolPage page;
  final TrafficMonitor monitor;

  @override
  State<MonitorToolPage> createState() => _MonitorToolPageState();
}

class _MonitorToolPageState extends State<MonitorToolPage> {
  String _output = '';
  bool _working = false;
  final _host = TextEditingController(text: 'example.com');

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _working = true;
      _output = '';
    });
    try {
      final output = await action();
      if (mounted) {
        setState(
          () => _output =
              output.trim().isEmpty ? 'No records returned.' : output.trim(),
        );
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _output =
              'The command did not complete. Check the network or Windows permissions.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String> _cmd(String exe, List<String> args) async {
    final result = await runWindowsCommand(exe, args);
    return [
      result.stdout.toString().trim(),
      result.stderr.toString().trim(),
      if (result.exitCode != 0) 'Windows exit code: ${result.exitCode}',
    ].where((part) => part.isNotEmpty).join('\n');
  }

  Future<String> _processes() async {
    final results = await Future.wait([
      _cmd('NETSTAT.EXE', ['-ano']),
      _cmd('TASKLIST.EXE', ['/FO', 'CSV', '/NH']),
    ]);
    final names = <String, String>{};
    final csv = RegExp(r'^"((?:[^"]|"")*)","(\d+)"', multiLine: true);
    for (final match in csv.allMatches(results[1])) {
      names[match.group(2)!] = match.group(1)!.replaceAll('""', '"');
    }
    return results[0].split('\n').map((line) {
      final pid = RegExp(r'^\s*(?:TCP|UDP)\s+.*?\s+(\d+)\s*$')
          .firstMatch(line)
          ?.group(1);
      final name = names[pid];
      return name == null ? line.trimRight() : '${line.trimRight()}   $name';
    }).join('\n');
  }

  Future<String> _lookup() async {
    final host = _host.text.trim();
    if (host.isEmpty ||
        host.length > 253 ||
        !RegExp(r'^[A-Za-z0-9.:-]+$').hasMatch(host)) {
      return 'Enter a valid hostname or IP address.';
    }
    final addresses =
        await InternetAddress.lookup(host).timeout(const Duration(seconds: 6));
    return addresses.map((address) => address.address).toSet().join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final wifi = widget.page == WindowsToolPage.wifi;
    final processes = widget.page == WindowsToolPage.processes;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Heading(
          wifi
              ? 'Wi-Fi connection'
              : processes
                  ? 'Active connections'
                  : 'Network tools',
          wifi
              ? 'Read the current connection, radio, channel and signal details from Windows.'
              : processes
                  ? 'Inspect local TCP and UDP endpoints with their owning PID and process name where available.'
                  : 'Run a DNS lookup or inspect the current IP configuration.',
        ),
        const SizedBox(height: 16),
        if (wifi || processes)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _working
                  ? null
                  : () => _run(
                        wifi
                            ? () => _cmd('NETSH.EXE', [
                                  'wlan',
                                  'show',
                                  'interfaces',
                                ])
                            : _processes,
                      ),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          )
        else ...[
          ListenableBuilder(
            listenable: widget.monitor,
            builder: (context, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Live connection quality'),
              subtitle: const Text(
                'Send one ICMP echo to 1.1.1.1 every five seconds.',
              ),
              value: widget.monitor.qualityEnabled,
              onChanged: widget.monitor.setQuality,
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _host,
                  decoration: const InputDecoration(
                    labelText: 'Hostname or IP',
                  ),
                  onSubmitted: (_) {
                    if (!_working) _run(_lookup);
                  },
                ),
              ),
              FilledButton.tonal(
                onPressed: _working ? null : () => _run(_lookup),
                child: const Text('DNS lookup'),
              ),
              TextButton(
                onPressed: _working
                    ? null
                    : () => _run(() => _cmd('IPCONFIG.EXE', ['/all'])),
                child: const Text('IP configuration'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (_working) const LinearProgressIndicator(),
        if (_output.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _output));
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Copied')));
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                  SelectableText(
                    _output,
                    style: const TextStyle(fontFamily: 'Consolas'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.detail);
  final String title, detail;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(detail),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, [this.accent]);
  final String label, value;
  final Color? accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 145,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
}
