import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef InfoRow = Map<String, dynamic>;

Future<List<InfoRow>> readRows(String program, List<String> args) async {
  final proc = await Process.start(program, args);
  try {
    final parts = await Future.wait<Object>([
      proc.exitCode,
      utf8.decoder.bind(proc.stdout).join(),
      proc.stderr.transform(const Utf8Decoder(allowMalformed: true)).join(),
    ]).timeout(const Duration(seconds: 90));
    if (parts.first != 0) throw FormatException(parts.last.toString().trim());
    if ((parts[1] as String).trim().isEmpty) return [];
    final raw = jsonDecode(parts[1] as String);
    return [
      for (final row in (raw is List ? raw : [raw]))
        if (row is Map) Map<String, dynamic>.from(row)
    ];
  } on TimeoutException {
    proc.kill();
    throw const FormatException('Windows did not finish the query in time.');
  }
}

String get _system => Platform.environment['SystemRoot'] ?? r'C:\Windows';
Future<List<InfoRow>> _powershell(String script) =>
    readRows('$_system\\System32\\WindowsPowerShell\\v1.0\\powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "[Console]::OutputEncoding=[Text.UTF8Encoding]::new(\$false); \$ErrorActionPreference='Stop'; " +
          script
    ]);

const _network = r'''
Get-NetIPConfiguration -All | ForEach-Object {
 $n=$_; $a=$n.NetAdapter
 $cfg=Get-CimInstance Win32_NetworkAdapterConfiguration -Filter ("InterfaceIndex="+$n.InterfaceIndex) | Select-Object -First 1
 [pscustomobject]@{Name=$n.InterfaceAlias; Description=$a.InterfaceDescription; Status=[string]$a.Status;
 Addresses=($cfg.IPAddress -join ', '); Subnet=($cfg.IPSubnet -join ', '); Gateway=($cfg.DefaultIPGateway -join ', ');
 DNS=($cfg.DNSServerSearchOrder -join ', '); Suffix=$cfg.DNSDomain; DHCP=$cfg.DHCPServer;
 LeaseStart=[string]$cfg.DHCPLeaseObtained; LeaseEnd=[string]$cfg.DHCPLeaseExpires; MAC=$a.MacAddress; Link=$a.LinkSpeed}
} | ConvertTo-Json -Compress
''';
const _process = r'''
Get-Process | Where-Object {$_.MainWindowHandle -ne 0} | ForEach-Object {
 [pscustomobject]@{Name=$_.ProcessName; PID=$_.Id; Window=$_.MainWindowTitle;
 MemoryMB=[math]::Round($_.WorkingSet64/1MB,1); Responding=$_.Responding;
 Stamp=if($_.StartTime){$_.StartTime.ToUniversalTime().Ticks.ToString()}; Started=[string]$_.StartTime; Path=$_.Path}
} | Sort-Object Name | ConvertTo-Json -Compress
''';
String get usageReader =>
    '${File(Platform.resolvedExecutable).parent.path}\\netcare_usage.exe';

class Inspector extends StatefulWidget {
  const Inspector(this.title, {this.publicIp, super.key});
  final String title;
  final String? publicIp;
  @override
  State<Inspector> createState() => _InspectorState();
}

class _InspectorState extends State<Inspector> {
  List<InfoRow> rows = [];
  String filter = '', error = '';
  bool busy = false;
  Future<void> windowAction(InfoRow row, {required bool close}) async {
    final target = row['PID'];
    final stamp = int.tryParse(row['Stamp']?.toString() ?? '');
    if (target is! int || target <= 0 || target == pid || stamp == null) return;
    if (close) {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text('Close ${row['Name']}?'),
                  content: const Text(
                      'The app will receive a normal window close request. Save your work first.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Close window'))
                  ]));
      if (confirm != true || !mounted) return;
    }
    try {
      final command = close
          ? r'$ok=$p.CloseMainWindow()'
          : r'$ok=(New-Object -ComObject WScript.Shell).AppActivate($p.Id)';
      await _powershell('\$p=Get-Process -Id $target; ' +
          r'if($p.MainWindowHandle -eq 0 -or $p.StartTime.ToUniversalTime().Ticks -ne ' +
          stamp.toString() +
          r'){throw "The selected window has changed."}; ' +
          command +
          r'; if(!$ok){throw "Windows declined the request."}; "[]"');
      if (mounted && close) await refresh();
    } catch (e) {
      if (mounted) setState(() => error = 'Window action unavailable. $e');
    }
  }

  Future<void> forget(InfoRow row) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Forget ${row['Name']}?'),
                content: Text(
                    'Remove this saved profile from ${row['Interface']}. Reconnecting may require the Wi-Fi password.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Forget'))
                ]));
    if (confirmed != true || !mounted) return;
    try {
      await readRows(usageReader,
          ['--forget', row['InterfaceId'] as String, row['Name'] as String]);
      if (mounted) await refresh();
    } catch (e) {
      if (mounted)
        setState(() => error = 'Windows could not remove the profile. $e');
    }
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final data = widget.title == 'Saved Wi-Fi'
          ? await readRows(usageReader, ['--wifi'])
          : await _powershell(
              widget.title == 'Active process' ? _process : _network);
      if (mounted) setState(() => rows = data);
    } catch (e) {
      if (mounted)
        setState(() => error = 'Windows could not return these details. $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
        if (widget.title == 'Network info' && widget.publicIp != null)
          ExpansionTile(
              title: const Text('Public IP'),
              children: [SelectableText(widget.publicIp!)]),
        TextField(
            decoration: const InputDecoration(
                labelText: 'Filter by name or detail',
                prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => filter = v.toLowerCase())),
        Wrap(children: [
          TextButton.icon(
              onPressed: busy ? null : refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Load / refresh')),
          if (widget.title == 'Saved Wi-Fi')
            TextButton(
                onPressed: () => Process.start('$_system\\explorer.exe',
                    ['ms-settings:network-wifimanage']),
                child: const Text('Manage saved networks in Windows')),
          if (widget.title == 'Active process')
            TextButton(
                onPressed: () =>
                    Process.start('$_system\\System32\\Taskmgr.exe', []),
                child: const Text('Open Task Manager')),
        ]),
        if (busy) const LinearProgressIndicator(),
        if (error.isNotEmpty) Text(error),
        if (rows.isEmpty && !busy && error.isEmpty)
          const Text('Refresh to view available records.'),
        for (final row in rows
            .where((r) => r.values.join(' ').toLowerCase().contains(filter)))
          Card(
              child: ExpansionTile(
                  title: Text('${row['Name']}'),
                  subtitle: Text(
                      '${row['Window'] ?? row['Description'] ?? row['Authentication'] ?? ''}'),
                  children: [
                if (widget.title == 'Saved Wi-Fi')
                  TextButton(
                      onPressed: () => forget(row),
                      child: const Text('Forget this profile')),
                if (widget.title == 'Active process' &&
                    row['PID'] != pid &&
                    row['Stamp'] != null)
                  Wrap(children: [
                    TextButton(
                        onPressed: () => windowAction(row, close: false),
                        child: const Text('Focus window')),
                    TextButton(
                        onPressed: () => windowAction(row, close: true),
                        child: const Text('Close window')),
                  ]),
                for (final entry in row.entries.where((e) =>
                    e.key != 'Stamp' &&
                    e.key != 'Name' &&
                    e.value != null &&
                    e.value != ''))
                  ListTile(
                      dense: true,
                      title: Text(entry.key),
                      subtitle: SelectableText(entry.value.toString()),
                      trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => Clipboard.setData(
                              ClipboardData(text: entry.value.toString())))),
              ])),
      ]);
}
