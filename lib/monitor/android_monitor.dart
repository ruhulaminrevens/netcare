import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'traffic_monitor.dart' show formatData;

const _native = MethodChannel('rar_netcare/android');
typedef _Record = Map<Object?, Object?>;

class AndroidMonitor extends StatefulWidget {
  const AndroidMonitor({required this.active, required this.bangla, super.key});
  final bool active, bangla;
  @override
  State<AndroidMonitor> createState() => _AndroidMonitorState();
}

class _AndroidMonitorState extends State<AndroidMonitor>
    with WidgetsBindingObserver {
  SharedPreferences? prefs;
  final budget = TextEditingController();
  Timer? timer;
  bool access = false, canOverlay = false, running = false, busy = false;
  bool alerts = false, amber = false, planBusy = false, suspended = false;
  int days = 7, size = 15, generation = 0;
  double limit = 0;
  int? monthly;
  String section = 'Usage stats',
      network = 'Mobile',
      view = 'Summary',
      unit = 'Mbps',
      error = '',
      planError = '';
  Set<int> thresholds = {90};
  List<_Record> rows = [];
  Map<String, String> details = {};
  String tr(String en, String bn) => widget.bangla ? bn : en;
  static const sections = [
    'Usage stats',
    'Data plan',
    'Mini meter',
    'Wi-Fi & network',
    'App activity',
  ];
  static const banglaSections = [
    'ডেটা ব্যবহার',
    'ডেটা প্ল্যান',
    'মিনি মিটার',
    'ওয়াই-ফাই ও নেটওয়ার্ক',
    'অ্যাপ কার্যকলাপ',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setup();
  }

  Future<void> setup() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    prefs = p;
    limit = p.getDouble('android.plan.gb') ?? 0;
    budget.text = limit == 0 ? '' : limit.toString();
    alerts = p.getBool('android.plan.alerts') ?? false;
    thresholds = (p.getStringList('android.plan.thresholds') ?? ['90'])
        .map(int.parse)
        .toSet();
    unit = p.getString('android.meter.unit') ?? 'Mbps';
    size = p.getInt('android.meter.size') ?? 15;
    amber = p.getBool('android.meter.amber') ?? false;
    await refresh();
    if (mounted)
      timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!suspended && (alerts || (widget.active && section == 'Data plan')))
          checkPlan();
      });
  }

  @override
  void didUpdateWidget(AndroidMonitor old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && prefs != null) refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    suspended = state != AppLifecycleState.resumed;
    if (!suspended && prefs != null) refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    budget.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final id = ++generation;
    setState(() {
      busy = true;
      error = '';
      rows = [];
    });
    try {
      final permissions = (await _native.invokeMapMethod<String, bool>(
        'permissions',
      ))!;
      if (!mounted || id != generation) return;
      access = permissions['usage'] == true;
      canOverlay = permissions['overlay'] == true;
      running = permissions['running'] == true;
      if (!access) monthly = null;
      if (alerts || section == 'Data plan') unawaited(checkPlan());
      if (!widget.active) return;
      if (section == 'Wi-Fi & network') {
        final data = await _native.invokeMapMethod<String, String>('network');
        if (id == generation) details = data ?? {};
      } else if (access &&
          (section == 'Usage stats' || section == 'App activity')) {
        final data = await _native.invokeListMethod<Object?>(
          section == 'App activity' ? 'activity' : 'usage',
          {'days': days, 'network': network, 'apps': view == 'App-wise'},
        );
        if (id == generation) rows = data?.whereType<_Record>().toList() ?? [];
      }
    } on PlatformException catch (e) {
      if (id == generation) error = e.message ?? e.code;
    } finally {
      if (mounted && id == generation) setState(() => busy = false);
    }
  }

  Future<void> checkPlan() async {
    if (!access || planBusy || !mounted) return;
    planBusy = true;
    try {
      final v = await _native.invokeMapMethod<String, int>('plan', {
        'network': 'Mobile',
      });
      if (!mounted || v == null) return;
      final used = (v['rx'] ?? 0) + (v['tx'] ?? 0);
      setState(() {
        monthly = used;
        planError = '';
      });
      if (limit <= 0 || !alerts) return;
      final pct = used / (limit * 1e9) * 100;
      final now = DateTime.now();
      final key = 'android.alert.${now.year}.${now.month}.$limit';
      final seen = (prefs?.getStringList(key) ?? []).toSet();
      final crossed =
          thresholds.where((t) => t <= pct && !seen.contains('$t')).toList()
            ..sort();
      if (crossed.isEmpty) return;
      seen.addAll(crossed.map((t) => '$t'));
      await prefs?.setStringList(key, seen.toList());
      if (mounted) {
        SystemSound.play(SystemSoundType.alert);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Mobile data plan reached ${crossed.last}%',
                'মোবাইল ডেটা প্ল্যানের ${crossed.last}% ব্যবহৃত হয়েছে',
              ),
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted)
        setState(() {
          monthly = null;
          planError = e.message ?? e.code;
        });
    } finally {
      planBusy = false;
    }
  }

  Future<void> action(String name, [Map<String, Object>? args]) async {
    try {
      await _native.invokeMethod<void>(name, args);
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    }
  }

  Future<void> meter(bool enabled) async {
    await action('meter', {
      'enabled': enabled,
      'unit': unit,
      'size': size,
      'amber': amber,
    });
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted && error.isEmpty) await refresh();
  }

  Widget filters<T>(List<T> values, T selected, void Function(T) select) =>
      Wrap(
        spacing: 8,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text('$v'),
              selected: selected == v,
              onSelected: (_) => select(v),
            ),
        ],
      );
  String data(num v) => formatData(v.toDouble());
  String date(Object? v) =>
      MaterialLocalizations.of(context)
          .formatShortDate(DateTime.fromMillisecondsSinceEpoch(v as int));

  List<Widget> usage() {
    final rx = rows.fold<int>(0, (s, r) => s + (r['rx'] as int));
    final tx = rows.fold<int>(0, (s, r) => s + (r['tx'] as int));
    final peak = rows.fold<int>(
      1,
      (s, r) => math.max(s, (r['rx'] as int) + (r['tx'] as int)),
    );
    return [
      filters(['Mobile', 'Wi-Fi'], network, (v) {
        network = v;
        refresh();
      }),
      filters([7, 30, 90], days, (v) {
        days = v;
        refresh();
      }),
      Text(tr('Period in days', 'সময়সীমা (দিন)')),
      filters(['Summary', 'Day-wise', 'App-wise'], view, (v) {
        view = v;
        refresh();
      }),
      if (!busy && error.isEmpty && access) ...[
        Text(
          '↓ ${data(rx)}     ↑ ${data(tx)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (rows.isEmpty || (rx + tx == 0))
          Text(
            tr(
              'No recorded usage in this period.',
              'এই সময়ে কোনো ডেটা ব্যবহার রেকর্ড হয়নি।',
            ),
          ),
        if (view == 'Summary' && rows.isNotEmpty) ...[
          SizedBox(
            height: 165,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final r in rows)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${date(r['day'])}   ↓ ${data(r['rx'] as int)}   ↑ ${data(r['tx'] as int)}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 156 * (r['tx'] as int) / peak,
                              color: Colors.teal,
                            ),
                            Container(
                              height: 156 * (r['rx'] as int) / peak,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${date(rows.first['day'])} – ${date(rows.last['day'])}    ↓ Blue   ↑ Teal',
          ),
        ] else
          for (final r in view == 'Day-wise' ? rows.reversed : rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                view == 'Day-wise' ? date(r['day']) : r['label'].toString(),
              ),
              subtitle: Text(
                '↓ ${data(r['rx'] as int)}     ↑ ${data(r['tx'] as int)}',
              ),
            ),
      ],
    ];
  }

  List<Widget> plan() => [
    Text(tr('Mobile data · current calendar month', 'মোবাইল ডেটা · চলতি মাস')),
    Text(
      monthly == null ? '—' : data(monthly!),
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    if (limit > 0 && monthly != null) ...[
      LinearProgressIndicator(
        value: (monthly! / (limit * 1e9)).clamp(0.0, 1.0),
      ),
      Text(
        '${data(math.max(0, limit * 1e9 - monthly!))} ${tr("remaining", "বাকি")}',
      ),
    ],
    if (planError.isNotEmpty) Text(planError),
    TextField(
      controller: budget,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: tr('Monthly limit in GB', 'মাসিক সীমা (GB)'),
      ),
    ),
    OutlinedButton(
      onPressed: () async {
        final n = double.tryParse(budget.text.trim());
        if (n == null || !n.isFinite || n < 0) {
          setState(
            () => error = tr(
              'Enter a limit of zero or more.',
              'শূন্য বা তার বেশি লিখুন।',
            ),
          );
          return;
        }
        setState(() {
          limit = n;
          error = '';
        });
        await prefs?.setDouble('android.plan.gb', n);
        await checkPlan();
      },
      child: Text(tr('Save limit', 'সীমা সংরক্ষণ')),
    ),
    SwitchListTile(
      title: Text(
        tr('Alert while NetCare is open', 'NetCare খোলা থাকলে সতর্ক করুন'),
      ),
      value: alerts,
      onChanged: (v) async {
        setState(() => alerts = v);
        await prefs?.setBool('android.plan.alerts', v);
        await checkPlan();
      },
    ),
    Wrap(
      spacing: 8,
      children: [
        for (final n in [50, 75, 90, 100])
          FilterChip(
            label: Text('$n%'),
            selected: thresholds.contains(n),
            onSelected: (v) async {
              setState(() {
                if (v) {
                  thresholds.add(n);
                } else {
                  thresholds.remove(n);
                }
              });
              await prefs?.setStringList(
                'android.plan.thresholds',
                thresholds.map((t) => '$t').toList(),
              );
              await checkPlan();
            },
          ),
      ],
    ),
  ];

  List<Widget> meterSettings() => [
    if (!canOverlay)
      OutlinedButton(
        onPressed: () => action('overlaySettings'),
        child: Text(
          tr(
            'Allow display over other apps',
            'অন্য অ্যাপের উপরে দেখানোর অনুমতি দিন',
          ),
        ),
      ),
    SwitchListTile(
      title: Text(tr('Floating speed meter', 'ভাসমান স্পিড মিটার')),
      value: running,
      onChanged: canOverlay ? meter : null,
    ),
    Text(tr('Speed unit', 'গতির একক')),
    filters(['Mbps', 'KB/s'], unit, (v) async {
      setState(() => unit = v);
      await prefs?.setString('android.meter.unit', v);
      if (running) await meter(true);
    }),
    Text(tr('Text size', 'লেখার আকার')),
    filters([12, 15, 18, 21], size, (v) async {
      setState(() => size = v);
      await prefs?.setInt('android.meter.size', v);
      if (running) await meter(true);
    }),
    SwitchListTile(
      title: Text(tr('Amber text', 'অ্যাম্বার রঙের লেখা')),
      value: amber,
      onChanged: (v) async {
        setState(() => amber = v);
        await prefs?.setBool('android.meter.amber', v);
        if (running) await meter(true);
      },
    ),
    Text(
      tr(
        'Drag the meter to move it. Stop it here or from its notification.',
        'মিটারটি টেনে সরান। এখান থেকে বা নোটিফিকেশন থেকে বন্ধ করুন।',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final needsUsage = [
      'Usage stats',
      'Data plan',
      'App activity',
    ].contains(section);
    return ListView(
      padding: const EdgeInsets.all(16),
      children:
          [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: section,
                        items: [
                          for (var i = 0; i < sections.length; i++)
                            DropdownMenuItem(
                              value: sections[i],
                              child: Text(
                                widget.bangla ? banglaSections[i] : sections[i],
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            section = v;
                            refresh();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: tr('Refresh', 'রিফ্রেশ'),
                      onPressed: busy ? null : refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (busy) const LinearProgressIndicator(),
                if (error.isNotEmpty) Text(error),
                if (needsUsage && !access && !busy) ...[
                  Text(
                    tr(
                      'Usage Access lets NetCare read Android’s recorded data totals and recent app activity on this phone.',
                      'ফোনের ডেটা ব্যবহার ও সাম্প্রতিক অ্যাপের হিসাব দেখতে Usage Access প্রয়োজন।',
                    ),
                  ),
                  FilledButton(
                    onPressed: () => action('usageSettings'),
                    child: Text(tr('Open Usage Access', 'Usage Access খুলুন')),
                  ),
                ],
                if (section == 'Usage stats') ...usage(),
                if (section == 'Data plan') ...plan(),
                if (section == 'Mini meter') ...meterSettings(),
                if (section == 'Wi-Fi & network')
                  for (final e in details.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.key),
                      subtitle: SelectableText(e.value),
                    ),
                if (section == 'App activity') ...[
                  Text(
                    tr(
                      'Apps last used in the past 24 hours. Android lists visible running processes under Wi-Fi & network.',
                      'গত ২৪ ঘণ্টায় ব্যবহৃত অ্যাপ। Android যে running process দেখায় তা Wi-Fi ও network পাতায় পাবেন।',
                    ),
                  ),
                  if (access && !busy && rows.isEmpty && error.isEmpty)
                    Text(
                      tr(
                        'No recent activity available.',
                        'সাম্প্রতিক কার্যকলাপ পাওয়া যায়নি।',
                      ),
                    ),
                  for (final r in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r['label'].toString()),
                      subtitle: Text(
                        '${r['package']}\n${DateTime.fromMillisecondsSinceEpoch(r['last'] as int).toLocal().toString().split('.').first}',
                      ),
                    ),
                ],
              ]
              .map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: w,
                ),
              )
              .toList(),
    );
  }
}
