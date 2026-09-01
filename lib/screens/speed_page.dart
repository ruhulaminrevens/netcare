import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../models/ip_intelligence.dart';
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
        localIp: snapshot?.activeLocalIp ?? snapshot?.wifiIp,
        gateway: snapshot?.gateway,
        publicInfo: snapshot?.publicInfo,
        connectionType: _connectionLabel(widget.strings, snapshot),
        ipAccessType: snapshot?.ipAccessType.name,
        ipStability: snapshot?.ipStability.name,
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
    final publicInfo = _result?.publicInfo ?? widget.snapshot?.publicInfo;
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
                ? 'Wi-Fi, mobile data ও LAN-এর বাস্তব speed, IP এবং connection health দেখুন'
                : 'Measure real Wi-Fi, mobile-data, and LAN speed, IP, and connection health',
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
                    if (widget.snapshot?.isMobile == true) ...[
                      const SizedBox(height: 12),
                      _Notice(
                        icon: Icons.signal_cellular_alt_rounded,
                        text: strings.t('mobileDataWarning'),
                        color: const Color(0xFFFFC857),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _running ? _cancel : _start,
                      icon: Icon(
                        _running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      ),
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
              final metrics = _ResultMetrics(
                strings: strings,
                result: _result,
              );
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: gauge),
                        const SizedBox(width: 18),
                        Expanded(flex: 6, child: metrics),
                      ],
                    )
                  : Column(
                      children: [gauge, const SizedBox(height: 18), metrics],
                    );
            },
          ),
          const SizedBox(height: 18),
          _IpIntelligenceCard(
            strings: strings,
            info: publicInfo,
            snapshot: widget.snapshot,
            loading: widget.loadingNetwork,
          ),
          if (_result != null) ...[
            const SizedBox(height: 18),
            _TestFactsCard(strings: strings, result: _result!),
          ],
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
    return GridView.count(
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
    );
  }
}

class _IpIntelligenceCard extends StatelessWidget {
  const _IpIntelligenceCard({
    required this.strings,
    required this.info,
    required this.snapshot,
    required this.loading,
  });

  final AppStrings strings;
  final PublicIpInfo? info;
  final NetworkSnapshot? snapshot;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, color: Color(0xFF31D6C4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.isBangla ? 'পাবলিক IP ও ISP তথ্য' : 'Public IP & ISP intelligence',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(label: strings.t('publicIp'), value: info?.ip ?? '—'),
          _InfoRow(label: strings.t('ipVersion'), value: info?.version ?? '—'),
          _InfoRow(label: strings.t('provider'), value: info?.providerName ?? '—'),
          _InfoRow(
            label: strings.t('organization'),
            value: info?.organization ?? '—',
          ),
          _InfoRow(
            label: strings.t('asn'),
            value: info?.asn == null ? '—' : 'AS${info!.asn}',
          ),
          _InfoRow(
            label: strings.t('providerLocation'),
            value: info?.locationLabel ?? '—',
          ),
          _InfoRow(label: strings.t('timezone'), value: info?.timezone ?? '—'),
          _InfoRow(
            label: strings.t('ipAccess'),
            value: _ipAccessLabel(strings, snapshot?.ipAccessType),
          ),
          _InfoRow(
            label: strings.t('ipStability'),
            value: _ipStabilityLabel(strings, snapshot),
            last: true,
          ),
          const SizedBox(height: 10),
          Text(
            strings.t('wanHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TestFactsCard extends StatelessWidget {
  const _TestFactsCard({required this.strings, required this.result});

  final AppStrings strings;
  final SpeedTestResult result;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: Color(0xFF35A7FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.t('testFacts'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              StatusPill(
                label: '${result.healthScore}/100 · ${result.healthGrade}',
                positive: result.healthScore >= 75,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(label: strings.t('connection'), value: result.connectionType ?? '—'),
          _InfoRow(label: strings.t('server'), value: result.server ?? '—'),
          _InfoRow(
            label: strings.t('dataTransferred'),
            value: '${result.transferredMegabytes.toStringAsFixed(1)} MB',
          ),
          _InfoRow(
            label: strings.t('duration'),
            value: '${result.testDurationSeconds.toStringAsFixed(1)} s',
          ),
          _InfoRow(
            label: strings.t('requestLoss'),
            value: result.packetLossPercent == null
                ? '—'
                : '${result.packetLossPercent!.toStringAsFixed(1)}%',
            last: true,
          ),
          const SizedBox(height: 10),
          _Notice(
            icon: Icons.verified_rounded,
            text: strings.t('actualDataNote'),
            color: const Color(0xFF31D6C4),
          ),
        ],
      ),
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
                label: _connectionLabel(strings, snapshot),
                positive: snapshot?.connectionKinds.any(
                      (kind) => kind != ConnectionKind.none,
                    ) ==
                    true,
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
            value: snapshot?.activeLocalIp ?? snapshot?.wifiIp ?? '—',
          ),
          _InfoRow(label: strings.t('gateway'), value: snapshot?.gateway ?? '—'),
          _InfoRow(
            label: strings.t('dns'),
            value: snapshot?.dnsLatencyMs == null
                ? '—'
                : '${snapshot!.dnsLatencyMs!.toStringAsFixed(1)} ms',
          ),
          _InfoRow(
            label: strings.t('allLocalIps'),
            value: snapshot?.localAddresses.isNotEmpty == true
                ? snapshot!.localAddresses.join(', ')
                : '—',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
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
            width: MediaQuery.sizeOf(context).width < 430 ? 112 : 155,
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

String _connectionLabel(AppStrings strings, NetworkSnapshot? snapshot) {
  final kinds = snapshot?.connectionKinds ?? const <ConnectionKind>[];
  final labels = <String>[];
  for (final kind in kinds) {
    final label = switch (kind) {
      ConnectionKind.wifi => strings.t('wifi'),
      ConnectionKind.mobile => strings.t('mobileData'),
      ConnectionKind.ethernet => strings.t('ethernet'),
      ConnectionKind.vpn => strings.t('vpn'),
      ConnectionKind.bluetooth => 'Bluetooth',
      ConnectionKind.other => strings.t('otherConnection'),
      ConnectionKind.none => strings.t('noConnection'),
    };
    if (!labels.contains(label)) labels.add(label);
  }
  return labels.isEmpty ? strings.t('unknown') : labels.join(' + ');
}

String _ipAccessLabel(AppStrings strings, IpAccessType? type) {
  return switch (type) {
    IpAccessType.directPublic => strings.t('directPublic'),
    IpAccessType.publicAtRouter => strings.t('publicAtRouter'),
    IpAccessType.cgnatConfirmed => strings.t('cgnatConfirmed'),
    IpAccessType.sharedLikely => strings.t('sharedLikely'),
    IpAccessType.upstreamNatOrVpn => strings.t('upstreamNatOrVpn'),
    IpAccessType.natUnverified => strings.t('natUnverified'),
    _ => strings.t('unknown'),
  };
}

String _ipStabilityLabel(AppStrings strings, NetworkSnapshot? snapshot) {
  final type = snapshot?.ipStability;
  final base = switch (type) {
    IpStability.firstObservation => strings.t('firstObservation'),
    IpStability.stableObserved => strings.t('stableObserved'),
    IpStability.dynamicDetected => strings.t('dynamicDetected'),
    _ => strings.t('unknown'),
  };
  final count = snapshot?.ipObservation?.observationCount;
  return count != null && count > 1 ? '$base ($count checks)' : base;
}
