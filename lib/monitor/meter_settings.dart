import 'package:flutter/material.dart';
import 'traffic_monitor.dart';

class MeterSettings extends StatelessWidget {
  const MeterSettings(this.monitor, {super.key});
  final TrafficMonitor monitor;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        Widget choice(String label, String key, List<dynamic> values,
                dynamic initial) =>
            ListTile(
                title: Text(label),
                trailing: DropdownButton<dynamic>(
                    value: monitor.options[key] ?? initial,
                    items: [
                      for (final v in values)
                        DropdownMenuItem(value: v, child: Text('$v'))
                    ],
                    onChanged: monitor.ready
                        ? (v) => monitor.changeOption(key, v)
                        : null));
        return Card(
            child: Column(children: [
          SwitchListTile(
              title: const Text('Floating mini meter'),
              value: monitor.overlay,
              onChanged: monitor.ready ? monitor.setOverlay : null),
          choice('Font', 'meterFont', ['Segoe UI', 'Consolas', 'Arial'],
              'Segoe UI'),
          choice('Text size', 'meterSize', [12, 15, 18, 21, 24], 15),
          choice('Speed unit', 'meterUnit',
              ['Auto bits', 'Auto bytes', 'Mbps', 'MB/s'], 'Auto bits'),
          choice('Colors', 'meterColor', ['Ocean', 'Amber'], 'Ocean'),
          SwitchListTile(
              title: const Text('Bold text'),
              value: monitor.options['meterBold'] == true,
              onChanged: (v) => monitor.changeOption('meterBold', v)),
        ]));
      });
}

class PlanAlerts extends StatelessWidget {
  const PlanAlerts(this.monitor, {super.key});
  final TrafficMonitor monitor;
  @override
  Widget build(BuildContext context) {
    final values = (monitor.options['thresholds'] as List? ?? [90])
        .whereType<int>()
        .toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
          title: const Text('Monthly usage alerts'),
          subtitle:
              const Text('Sound and in-app notification while monitoring.'),
          value: monitor.options['alerts'] == true,
          onChanged: (v) => monitor.changeOption('alerts', v)),
      Wrap(spacing: 6, children: [
        for (final n in {50, 75, 90, 100, ...values}.toList()..sort())
          FilterChip(
              selected: values.contains(n),
              label: Text('$n%'),
              onSelected: (v) {
                if (v) {
                  values.add(n);
                } else {
                  values.remove(n);
                }
                monitor.changeOption('thresholds', values.toList());
              }),
        TextButton(
            onPressed: () async {
              final n = await showDialog<int>(
                  context: context,
                  builder: (context) {
                    int? threshold;
                    return AlertDialog(
                        title: const Text('Custom threshold (%)'),
                        content: TextField(
                            keyboardType: TextInputType.number,
                            onChanged: (s) => threshold = int.tryParse(s)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () {
                                if (threshold != null &&
                                    threshold! > 0 &&
                                    threshold! <= 100)
                                  Navigator.pop(context, threshold);
                              },
                              child: const Text('Add'))
                        ]);
                  });
              if (n != null) {
                values.add(n);
                monitor.changeOption('thresholds', values.toList());
              }
            },
            child: const Text('Custom')),
      ])
    ]);
  }
}
