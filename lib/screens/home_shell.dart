import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../models/network_profile.dart';
import '../models/speed_test_result.dart';
import '../monitor/monitor_pages.dart';
import '../monitor/traffic_monitor.dart';
import '../services/network_diagnostic_service.dart';
import '../services/storage_service.dart';
import 'diagnostics_page.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'speed_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.storage,
    required this.isBangla,
    required this.darkMode,
    required this.onLanguageChanged,
    required this.onDarkModeChanged,
    super.key,
  });

  final StorageService storage;
  final bool isBangla;
  final bool darkMode;
  final ValueChanged<bool> onLanguageChanged;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final NetworkDiagnosticService _diagnostics = NetworkDiagnosticService();
  late final TrafficMonitor? _monitor;
  int _selectedIndex = 0;
  bool _loadingNetwork = true;
  NetworkSnapshot? _snapshot;
  NetworkProfile _profile = const NetworkProfile();
  List<SpeedTestResult> _history = const [];

  @override
  void initState() {
    super.initState();
    _monitor = Platform.isWindows ? TrafficMonitor() : null;
    _loadAll();
  }

  @override
  void dispose() {
    _monitor?.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final profile = await widget.storage.loadProfile();
    final history = await widget.storage.loadHistory();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _history = history;
    });
    await _refreshNetwork();
  }

  Future<void> _refreshNetwork() async {
    setState(() => _loadingNetwork = true);
    var snapshot = await _diagnostics.inspect(profile: _profile);
    final observation = await widget.storage.observePublicIp(
      snapshot.publicInfo?.ip,
      scope: networkObservationScope(snapshot, profileName: _profile.name),
    );
    snapshot = snapshot.withIpObservation(observation);
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loadingNetwork = false;
    });
  }

  Future<void> _onResult(SpeedTestResult result) async {
    await widget.storage.addResult(result);
    final history = await widget.storage.loadHistory();
    if (!mounted) return;
    setState(() => _history = history);
  }

  Future<void> _onProfileSaved(NetworkProfile profile) async {
    await widget.storage.saveProfile(profile);
    if (!mounted) return;
    setState(() => _profile = profile);
    await _refreshNetwork();
  }

  Future<void> _clearHistory() async {
    await widget.storage.clearHistory();
    if (!mounted) return;
    setState(() => _history = const []);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.isBangla);
    final monitor = _monitor;
    final pages = [
      if (monitor != null) MonitorDashboard(monitor: monitor),
      SpeedPage(
        strings: strings,
        snapshot: _snapshot,
        loadingNetwork: _loadingNetwork,
        onRefreshNetwork: _refreshNetwork,
        onResult: _onResult,
      ),
      DiagnosticsPage(
        strings: strings,
        profile: _profile,
        snapshot: _snapshot,
        loading: _loadingNetwork,
        onSaveAndRun: _onProfileSaved,
      ),
      HistoryPage(strings: strings, history: _history, onClear: _clearHistory),
      if (monitor != null) ...[
        MonitorAdapterPage(monitor: monitor),
        MonitorUsagePage(monitor: monitor),
        MonitorToolPage(monitor: monitor, page: WindowsToolPage.wifi),
        MonitorToolPage(monitor: monitor, page: WindowsToolPage.processes),
        MonitorToolPage(monitor: monitor, page: WindowsToolPage.tools),
      ],
      SettingsPage(
        strings: strings,
        isBangla: widget.isBangla,
        darkMode: widget.darkMode,
        onLanguageChanged: widget.onLanguageChanged,
        onDarkModeChanged: widget.onDarkModeChanged,
      ),
    ];
    final wide = monitor != null || MediaQuery.sizeOf(context).width >= 920;
    final destinations = [
      if (monitor != null)
        NavigationDestination(
          icon: const Icon(Icons.monitor_heart_outlined),
          label: widget.isBangla ? 'ড্যাশবোর্ড' : 'Dashboard',
        ),
      NavigationDestination(
        icon: const Icon(Icons.speed_rounded),
        label: monitor == null
            ? strings.t('overview')
            : widget.isBangla
            ? 'স্পিড টেস্ট'
            : 'Speed test',
      ),
      NavigationDestination(
        icon: const Icon(Icons.hub_outlined),
        label: strings.t('diagnostics'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.history_rounded),
        label: strings.t('history'),
      ),
      if (monitor != null) ...[
        NavigationDestination(
          icon: const Icon(Icons.lan_outlined),
          label: widget.isBangla ? 'অ্যাডাপ্টার' : 'Adapters',
        ),
        NavigationDestination(
          icon: const Icon(Icons.data_usage_outlined),
          label: widget.isBangla ? 'ডেটা ব্যবহার' : 'Usage & plan',
        ),
        const NavigationDestination(icon: Icon(Icons.wifi), label: 'Wi-Fi'),
        NavigationDestination(
          icon: const Icon(Icons.account_tree_outlined),
          label: widget.isBangla ? 'কানেকশন' : 'Connections',
        ),
        NavigationDestination(
          icon: const Icon(Icons.build_outlined),
          label: widget.isBangla ? 'নেটওয়ার্ক টুলস' : 'Network tools',
        ),
      ],
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        label: strings.t('settings'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: wide ? 28 : 16,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_heart_rounded, color: Color(0xFF31D6C4)),
            SizedBox(width: 10),
            Text('RAR NetCare', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => widget.onLanguageChanged(!widget.isBangla),
            icon: const Icon(Icons.translate_rounded),
            label: Text(widget.isBangla ? 'EN' : 'বাংলা'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (value) =>
                      setState(() => _selectedIndex = value),
                  extended:
                      monitor != null &&
                      MediaQuery.sizeOf(context).width >= 900,
                  minExtendedWidth: 182,
                  scrollable: true,
                  labelType: monitor == null
                      ? NavigationRailLabelType.all
                      : NavigationRailLabelType.none,
                  destinations: destinations
                      .map(
                        (item) => NavigationRailDestination(
                          icon: item.icon,
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: pages),
                ),
              ],
            )
          : IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => _selectedIndex = value),
              destinations: destinations,
            ),
    );
  }
}
