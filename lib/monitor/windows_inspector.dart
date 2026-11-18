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
 IPv4=($cfg.IPAddress -join ', '); Subnet=($cfg.IPSubnet -join ', '); Gateway=($cfg.DefaultIPGateway -join ', ');
 DNS=($cfg.DNSServerSearchOrder -join ', '); Suffix=$cfg.DNSDomain; DHCP=$cfg.DHCPServer;
 LeaseStart=[string]$cfg.DHCPLeaseObtained; LeaseEnd=[string]$cfg.DHCPLeaseExpires; MAC=$a.MacAddress; Link=$a.LinkSpeed}
} | ConvertTo-Json -Compress
''';
const _process = r'''
Get-Process | Where-Object {$_.MainWindowHandle -ne 0} | ForEach-Object {
 [pscustomobject]@{Name=$_.ProcessName; PID=$_.Id; Window=$_.MainWindowTitle;
 MemoryMB=[math]::Round($_.WorkingSet64/1MB,1); Responding=$_.Responding;
 Started=[string]$_.StartTime; Path=$_.Path}
} | Sort-Object Name | ConvertTo-Json -Compress
''';
const _wifi = r'''
$profiles = netsh wlan show profiles
$items = @(foreach($line in $profiles) {
 if($line -match '^\s*[^:]+:\s+(.+?)\s*$'){
 $profile=$matches[1]
 $details=netsh wlan show profile name="$profile"
 if($LASTEXITCODE -eq 0){
 $security=($details | Select-String '^\s*Authentication\s*:\s*(.+)' | Select-Object -First 1)
 [pscustomobject]@{Name=$profile; Authentication=if($security){$security.Matches[0].Groups[1].Value}else{'See profile details'}; Details=($details -join [Environment]::NewLine)}
 }} })
ConvertTo-Json -InputObject $items -Compress
''';

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
  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final data = await _powershell(switch (widget.title) {
        'Active process' => _process,
        'Network info' => _network,
        _ => _wifi
      });
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
                for (final entry in row.entries.where(
                    (e) => e.key != 'Name' && e.value != null && e.value != ''))
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
