import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../models/network_profile.dart';
import '../models/speed_test_result.dart';
import '../services/speed_test_service.dart';
import '../widgets/netcare_widgets.dart';

class SpeedPage extends StatefulWidget {
  const SpeedPage({
    required this.strings,
    required this.snapshot,
    required this.loadingNetwork,
    required this.onRefreshNetwork,
    required this.onResult,
    super.key,
  });

  final AppStrings strings;
  final NetworkSnapshot? snapshot;
  final bool loadingNetwork;
  final Future<void> Function() onRefreshNetwork;
  final Future<void> Function(SpeedTestResult result) onResult;

  @override
  State<SpeedPage> createState() => _SpeedPageState();
}

class _SpeedPageState extends State<SpeedPage> {
  final SpeedTestService _speedTest = SpeedTestService();
  SpeedTestMode _mode = SpeedTestMode.balanced;
  SpeedTestResult? _result;
  bool _running = false;
  double _progress = 0;
  String _stage = 'Ready';
  String? _error;

  @override
  void dispose() {
    _speedTest.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _progress = 0;
      _stage = widget.strings.t('checking');
      _error = null;
    });
    try {
      final snapshot = widget.snapshot;
      final result = await _speedTest.run(
        mode: _mode,
        localIp: snapshot?.wifiIp ??
            (snapshot?.localAddresses.isNotEmpty == true
                ? snapshot!.localAddresses.first
                : null),
        gateway: snapshot?.gateway,
        onProgress: (stage, fraction) {
          if (!mounted) return;
          setState(() {
            _stage = stage;
            _progress = fraction;
          });
        },
      );
      if (!mounted) return;
      setState(() => _result = result);
      await widget.onResult(result);
    } on SpeedTestCancelled {
      if (!mounted) return;
      setState(() => _error = widget.strings.t('cancelled'));
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = '${widget.strings.t('testFailed')}: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _cancel() {
    _speedTest.cancel();
    setState(() {
      _running = false;
      _error = widget.strings.t('cancelled');
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return RefreshIndicator(
      onRefresh: widget.onRefreshNetwork,
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width >= 700 ? 28 : 16,
          vertical: 20,
        ),
        children: [
          _PageHeading(
            title: strings.t('speedTest'),
            subtitle: strings.isBangla
                ? 'এক ট্যাপে speed, stability এবং connection health দেখুন'
                : 'Measure speed, stability, and connection health in one tap',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              final gauge = SectionCard(
                child: Column(
                  children: [
                    SpeedGauge(
                      value: _result?.downloadMbps ?? 0,
                      label: _running ? _stage : strings.t('download'),
                      progress: _progress,
                      running: _running,
                    ),
                    if (_running)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: LinearProgressIndicator(value: _progress),
                      ),
                    const SizedBox(height: 14),
                    SegmentedButton<SpeedTestMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: SpeedTestMode.quick,
                          label: Text(strings.t('quick')),
                        ),
                        ButtonSegment(
                          value: SpeedTestMode.balanced,
                          label: Text(strings.t('balanced')),
                        ),
                        ButtonSegment(
                          value: SpeedTestMode.deep,
                          label: Text(strings.t('deep')),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: _running
                          ? null
                          : (values) => setState(() => _mode = values.first),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${strings.t('dataUse')}: ~${_mode.estimatedMegabytes} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _running ? _cancel : _start,
                      icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      label: Text(
                        _running ? strings.t('stopTest') : strings.t('startTest'),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFF6B6B)),
                      ),
                    ],
                  ],
                ),
              );
              final metrics = _ResultMetrics(strings: strings, result: _result);
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: gauge),
                        const SizedBox(width: 18),
                        Expanded(flex: 6, child: metrics),
                      ],
                    )
                  : Column(children: [gauge, const SizedBox(height: 18), metrics]);
            },
          ),
          const SizedBox(height: 18),
          _NetworkSnapshotCard(
            strings: strings,
            snapshot: widget.snapshot,
            loading: widget.loadingNetwork,
            onRefresh: widget.onRefreshNetwork,
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ResultMetrics extends StatelessWidget {
  const _ResultMetrics({required this.strings, required this.result});

  final AppStrings strings;
  final SpeedTestResult? result;

  @override
  Widget build(BuildContext context) {
    String speed(double? value) => value?.toStringAsFixed(1) ?? '—';
    return Column(
      children: [
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 470 ? 2 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            MetricTile(
              label: strings.t('download'),
              value: speed(result?.downloadMbps),
              unit: strings.t('mbps'),
              icon: Icons.download_rounded,
            ),
            MetricTile(
              label: strings.t('upload'),
              value: speed(result?.uploadMbps),
              unit: strings.t('mbps'),
              icon: Icons.upload_rounded,
              color: const Color(0xFF35A7FF),
            ),
            MetricTile(
              label: strings.t('latency'),
              value: speed(result?.pingMs),
              unit: strings.t('ms'),
              icon: Icons.network_ping_rounded,
              color: const Color(0xFFFFC857),
            ),
            MetricTile(
              label: strings.t('jitter'),
              value: speed(result?.jitterMs),
              unit: strings.t('ms'),
              icon: Icons.show_chart_rounded,
              color: const Color(0xFFB892FF),
            ),
          ],
        ),
        if (result != null) ...[
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              children: [
                _InfoRow(label: strings.t('provider'), value: result!.isp ?? '—'),
                _InfoRow(label: strings.t('publicIp'), value: result!.publicIp ?? '—'),
                _InfoRow(label: strings.t('server'), value: result!.server ?? '—'),
                _InfoRow(
                  label: strings.t('packetLoss'),
                  value: result!.packetLossPercent == null
                      ? '—'
                      : '${result!.packetLossPercent!.toStringAsFixed(1)}%',
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NetworkSnapshotCard extends StatelessWidget {
  const _NetworkSnapshotCard({
    required this.strings,
    required this.snapshot,
    required this.loading,
    required this.onRefresh,
  });

  final AppStrings strings;
  final NetworkSnapshot? snapshot;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.t('networkSnapshot'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                tooltip: strings.t('refresh'),
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatusPill(
                label: snapshot?.internetAvailable == true
                    ? '${strings.t('internet')}: ${strings.t('available')}'
                    : '${strings.t('internet')}: ${strings.t('unavailable')}',
                positive: snapshot?.internetAvailable == true,
              ),
              StatusPill(
                label: snapshot?.tailscaleDetected == true
                    ? '${strings.t('tailscale')}: ${strings.t('detected')}'
                    : '${strings.t('tailscale')}: ${strings.t('notDetected')}',
                positive: snapshot?.tailscaleDetected == true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: strings.t('localIp'),
            value: snapshot?.wifiIp ??
                (snapshot?.localAddresses.isNotEmpty == true
                    ? snapshot!.localAddresses.join(', ')
                    : '—'),
          ),
          _InfoRow(label: strings.t('gateway'), value: snapshot?.gateway ?? '—'),
          _InfoRow(
            label: strings.t('dns'),
            value: snapshot?.dnsLatencyMs == null
                ? '—'
                : '${snapshot!.dnsLatencyMs!.toStringAsFixed(1)} ms',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
