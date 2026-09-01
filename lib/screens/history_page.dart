import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_strings.dart';
import '../models/speed_test_result.dart';
import '../widgets/netcare_widgets.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({
    required this.strings,
    required this.history,
    required this.onClear,
    super.key,
  });

  final AppStrings strings;
  final List<SpeedTestResult> history;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width >= 700 ? 28 : 16,
        vertical: 20,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.t('history'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            if (history.isNotEmpty)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(strings.t('clearHistory')),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (history.isEmpty)
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 42),
              child: Column(
                children: [
                  const Icon(Icons.query_stats_rounded, size: 54),
                  const SizedBox(height: 12),
                  Text(strings.t('noHistory')),
                ],
              ),
            ),
          )
        else
          ...history.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(result.timestamp),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  result.connectionType,
                                  result.isp,
                                  result.location,
                                ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: strings.t('copyReport'),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: result.toPrettyJson()),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(strings.t('copied'))),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Wrap(
                      spacing: 22,
                      runSpacing: 12,
                      children: [
                        _CompactMetric(
                          label: strings.t('download'),
                          value: '${result.downloadMbps.toStringAsFixed(1)} Mbps',
                        ),
                        _CompactMetric(
                          label: strings.t('upload'),
                          value: '${result.uploadMbps.toStringAsFixed(1)} Mbps',
                        ),
                        _CompactMetric(
                          label: strings.t('latency'),
                          value: '${result.pingMs.toStringAsFixed(1)} ms',
                        ),
                        _CompactMetric(
                          label: strings.t('jitter'),
                          value: '${result.jitterMs.toStringAsFixed(1)} ms',
                        ),
                        _CompactMetric(
                          label: strings.t('healthScore'),
                          value: '${result.healthScore}/100',
                        ),
                        if (result.transferredMegabytes > 0)
                          _CompactMetric(
                            label: strings.t('dataTransferred'),
                            value: '${result.transferredMegabytes.toStringAsFixed(1)} MB',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 28),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 135,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
