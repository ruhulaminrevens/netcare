import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../models/network_profile.dart';
import '../models/speed_test_result.dart';
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
  int _selectedIndex = 0;
  bool _loadingNetwork = true;
  NetworkSnapshot? _snapshot;
  NetworkProfile _profile = const NetworkProfile();
  List<SpeedTestResult> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
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
      scope: networkObservationScope(
        snapshot,
        profileName: _profile.name,
      ),
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
    final pages = [
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
      HistoryPage(
        strings: strings,
        history: _history,
        onClear: _clearHistory,
      ),
      SettingsPage(
        strings: strings,
        isBangla: widget.isBangla,
        darkMode: widget.darkMode,
        onLanguageChanged: widget.onLanguageChanged,
        onDarkModeChanged: widget.onDarkModeChanged,
      ),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 920;
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.speed_rounded),
        label: strings.t('overview'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.hub_outlined),
        label: strings.t('diagnostics'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.history_rounded),
        label: strings.t('history'),
      ),
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
                  labelType: NavigationRailLabelType.all,
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
                Expanded(child: IndexedStack(index: _selectedIndex, children: pages)),
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
