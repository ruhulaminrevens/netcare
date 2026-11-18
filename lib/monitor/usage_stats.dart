import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'traffic_monitor.dart';
import 'windows_inspector.dart';

class UsageStats extends StatefulWidget {
  const UsageStats({required this.monitor, required this.active, super.key});
  final TrafficMonitor monitor;
  final bool active;
  @override
  State<UsageStats> createState() => _UsageStatsState();
}

class _UsageStatsState extends State<UsageStats> {
  List<InfoRow> profiles = [], records = [];
  int days = 7;
  String? profile;
  String view = 'Summary', message = '';
  bool busy = false;
  static const local = 'netcare-local';
  bool loaded = false;
  @override
  void didUpdateWidget(UsageStats old) {
    super.didUpdateWidget(old);
    if (widget.active && !loaded) {
      loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !busy) refresh();
      });
    }
  }

  List<InfoRow> localDays(List<DateTime> edges) {
    final buckets = widget.monitor.usage.toList();
    return [
      for (var i = 0; i < edges.length - 1; i++)
        bucketRow(buckets, edges[i], edges[i + 1])
    ];
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      records = [];
      message = '';
    });
    try {
      var choices = <InfoRow>[];
      try {
        choices = await readRows(usageReader, []);
      } on Exception catch (e) {
        message = 'Windows profiles unavailable. $e';
      }
      if (!mounted) return;
      profiles = [
        {'id': local, 'label': 'NetCare recordings · physical adapters'},
        ...{for (final item in choices) item['id']: item}.values
      ];
      if (!profiles.any((p) => p['id'] == profile)) profile = local;
      if (view == 'App-wise' && profile == local) {
        if (choices.isEmpty) {
          message =
              'Windows has no profile with application accounting available.';
          return;
        }
        profile = choices.first['id'] as String;
      }
      final now = DateTime.now();
      final boundaries = [
        for (var i = days - 1; i >= 0; i--)
          DateTime(now.year, now.month, now.day - i),
        now
      ];
      if (profile == local) {
        records = localDays(boundaries);
        return;
      }
      records = await readRows(usageReader, [
        profile!,
        view == 'App-wise' ? 'apps' : 'days',
        for (final date in boundaries) '${date.millisecondsSinceEpoch}'
      ]);
      if (view == 'App-wise')
        records.sort((a, b) => total(b).compareTo(total(a)));
      if (records.isEmpty)
        message = 'Windows returned no usage records for this selection.';
    } catch (e) {
      message = 'Windows accounting unavailable for this profile. $e';
      if (view != 'App-wise' && mounted) {
        profile = local;
        final now = DateTime.now();
        records = localDays([
          for (var i = days - 1; i >= 0; i--)
            DateTime(now.year, now.month, now.day - i),
          now
        ]);
        message += ' Showing NetCare recordings across physical adapters.';
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  double total(InfoRow row) =>
      (row['rx'] as num).toDouble() + (row['tx'] as num).toDouble();
  String day(InfoRow row) => MaterialLocalizations.of(context).formatShortDate(
      DateTime.fromMillisecondsSinceEpoch(int.parse(row['label'])));
  @override
  Widget build(BuildContext context) {
    final rx = records.fold(0.0, (v, r) => v + (r['rx'] as num));
    final tx = records.fold(0.0, (v, r) => v + (r['tx'] as num));
    final peak = records.fold(1.0, (v, r) => math.max(v, total(r)));
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Usage statistics',
          style: Theme.of(context).textTheme.headlineMedium),
      const Text(
          'Choose NetCare recordings or a Windows connection profile. App-wise figures depend on Windows attribution.'),
      Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (profiles.isNotEmpty)
              DropdownButton<String>(
                  value: profile,
                  items: [
                    for (final p in profiles)
                      DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text(p['label'].toString()))
                  ],
                  onChanged: busy
                      ? null
                      : (v) {
                          profile = v;
                          refresh();
                        }),
            for (final d in [7, 30, 90])
              ChoiceChip(
                  label: Text('$d days'),
                  selected: d == days,
                  onSelected: busy
                      ? null
                      : (_) {
                          days = d;
                          refresh();
                        }),
            FilledButton.tonalIcon(
                onPressed: busy ? null : refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Load / refresh')),
          ]),
      Wrap(spacing: 8, children: [
        for (final mode in ['Summary', 'Day-wise', 'App-wise'])
          ChoiceChip(
              label: Text(mode),
              selected: view == mode,
              onSelected: busy
                  ? null
                  : (_) {
                      view = mode;
                      refresh();
                    })
      ]),
      if (busy) const LinearProgressIndicator(),
      if (message.isNotEmpty) Text(message),
      if (records.isNotEmpty) ...[
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
                '↓ ${formatData(rx)}     ↑ ${formatData(tx)}     Total  ${formatData(rx + tx)}',
                style: Theme.of(context).textTheme.titleLarge)),
        if (view == 'Summary')
          SizedBox(
              height: 240,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final r in records)
                  Expanded(
                      child: Tooltip(
                          message:
                              '${day(r)}   ↓ ${formatData(r['rx'].toDouble())}   ↑ ${formatData(r['tx'].toDouble())}',
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 1),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                        height: 220 * (r['tx'] as num) / peak,
                                        color: Colors.teal),
                                    Container(
                                        height: 220 * (r['rx'] as num) / peak,
                                        color: Colors.blue),
                                  ])))),
              ])),
        if (view == 'Summary')
          Text(
              '${day(records.first)}   –   ${day(records.last)}     Blue · Download     Teal · Upload'),
        if (view != 'Summary')
          for (final r in view == 'Day-wise' ? records.reversed : records)
            ListTile(
                title:
                    Text(view == 'Day-wise' ? day(r) : r['label'].toString()),
                subtitle: Text(
                    '↓ ${formatData(r['rx'].toDouble())}     ↑ ${formatData(r['tx'].toDouble())}'),
                trailing: Text(formatData(total(r)))),
      ]
    ]);
  }
}

InfoRow bucketRow(List<UsageBucket> buckets, DateTime start, DateTime end) {
  var rx = 0.0, tx = 0.0;
  for (final bucket in buckets) {
    final from = bucket.hour * 3600000;
    final overlap = math.min(end.millisecondsSinceEpoch, from + 3600000) -
        math.max(start.millisecondsSinceEpoch, from);
    if (overlap <= 0) continue;
    // A partly recorded current hour contains only the bytes observed so far.
    final elapsed =
        math.min(3600000, DateTime.now().millisecondsSinceEpoch - from);
    if (elapsed <= 0) continue;
    final share = (overlap / elapsed).clamp(0.0, 1.0);
    rx += bucket.rx * share;
    tx += bucket.tx * share;
  }
  return {'label': start.millisecondsSinceEpoch.toString(), 'rx': rx, 'tx': tx};
}
