import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../models/network_profile.dart';
import '../widgets/netcare_widgets.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({
    required this.strings,
    required this.profile,
    required this.snapshot,
    required this.loading,
    required this.onSaveAndRun,
    super.key,
  });

  final AppStrings strings;
  final NetworkProfile profile;
  final NetworkSnapshot? snapshot;
  final bool loading;
  final Future<void> Function(NetworkProfile profile) onSaveAndRun;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  late final TextEditingController _name;
  late final TextEditingController _gateway;
  late final TextEditingController _routerWanIp;
  late final TextEditingController _switchIp;
  late final TextEditingController _serverIp;
  late final TextEditingController _remoteHost;
  late final TextEditingController _remotePort;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _gateway = TextEditingController();
    _routerWanIp = TextEditingController();
    _switchIp = TextEditingController();
    _serverIp = TextEditingController();
    _remoteHost = TextEditingController();
    _remotePort = TextEditingController();
    _applyProfile(widget.profile);
  }

  @override
  void didUpdateWidget(covariant DiagnosticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.toJson().toString() != widget.profile.toJson().toString()) {
      _applyProfile(widget.profile);
    }
  }

  void _applyProfile(NetworkProfile profile) {
    _name.text = profile.name;
    _gateway.text = profile.gateway;
    _routerWanIp.text = profile.routerWanIp;
    _switchIp.text = profile.switchIp;
    _serverIp.text = profile.serverIp;
    _remoteHost.text = profile.remoteHost;
    _remotePort.text = '${profile.remotePort}';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _gateway,
      _routerWanIp,
      _switchIp,
      _serverIp,
      _remoteHost,
      _remotePort,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_remotePort.text.trim());
    if (port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.t('invalidPort'))),
      );
      return;
    }
    final profile = NetworkProfile(
      name: _name.text.trim(),
      gateway: _gateway.text.trim(),
      routerWanIp: _routerWanIp.text.trim(),
      switchIp: _switchIp.text.trim(),
      serverIp: _serverIp.text.trim(),
      remoteHost: _remoteHost.text.trim(),
      remotePort: port,
    );
    await widget.onSaveAndRun(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.t('profileSaved'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width >= 700 ? 28 : 16,
        vertical: 20,
      ),
      children: [
        Text(
          strings.t('diagnostics'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(strings.t('profileHint')),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('profile'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 650;
                  final fields = [
                    _Field(controller: _name, label: strings.t('profileName')),
                    _Field(controller: _gateway, label: strings.t('gateway')),
                    _Field(
                      controller: _routerWanIp,
                      label: strings.t('routerWanIp'),
                      helper: strings.t('wanHint'),
                    ),
                    _Field(controller: _switchIp, label: strings.t('switchIp')),
                    _Field(controller: _serverIp, label: strings.t('serverIp')),
                    _Field(controller: _remoteHost, label: strings.t('remoteHost')),
                    _Field(
                      controller: _remotePort,
                      label: strings.t('remotePort'),
                      number: true,
                    ),
                  ];
                  if (!wide) {
                    return Column(
                      children: fields
                          .map(
                            (field) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: field,
                            ),
                          )
                          .toList(),
                    );
                  }
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: fields
                        .map(
                          (field) => SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: field,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.loading ? null : _save,
                icon: widget.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.health_and_safety_outlined),
                label: Text(strings.t('saveAndRun')),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('results'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              if (widget.loading)
                const LinearProgressIndicator()
              else if (widget.snapshot?.checks.isEmpty ?? true)
                Text(strings.isBangla
                    ? 'Gateway বা custom device যোগ করলে এখানে reachability result দেখাবে।'
                    : 'Add a gateway or custom device to see reachability results.')
              else
                ...widget.snapshot!.checks.map(
                  (check) => _CheckRow(check: check, strings: strings),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.number = false,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final bool number;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.strings});

  final EndpointCheck check;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final color = check.reachable ? const Color(0xFF31D6C4) : const Color(0xFFFF6B6B);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .13),
        child: Icon(
          check.reachable ? Icons.check_rounded : Icons.close_rounded,
          color: color,
        ),
      ),
      title: Text(check.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${check.host}:${check.port}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            check.reachable ? strings.t('reachable') : strings.t('blocked'),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (check.reachable)
            Text('${check.latencyMs.toStringAsFixed(1)} ms'),
        ],
      ),
    );
  }
}
