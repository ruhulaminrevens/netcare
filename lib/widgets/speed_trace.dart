import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/speed_test_result.dart';

class TraceSample {
  const TraceSample(this.ms, this.kind, this.value);
  final int ms;
  final String kind;
  final double value;
}

class SpeedTrace extends StatefulWidget {
  const SpeedTrace({required this.samples, required this.result, super.key});
  final List<TraceSample> samples;
  final SpeedTestResult? result;
  @override
  State<SpeedTrace> createState() => _SpeedTraceState();
}

class _SpeedTraceState extends State<SpeedTrace> {
  final key = GlobalKey();
  String get summary {
    final r = widget.result;
    if (r == null) return 'Measuring…';
    String ms(double? n) => n == null ? '—' : '${n.toStringAsFixed(1)} ms';
    return '↓ ${r.downloadMbps.toStringAsFixed(1)} Mbps    ↑ ${r.uploadMbps.toStringAsFixed(1)} Mbps\nIdle ${ms(r.pingMs)}    Download load ${ms(r.loadedDownloadMs)}    Upload load ${ms(r.loadedUploadMs)}\nBufferbloat estimate  ${r.bufferGrade}    ·    HTTP probe loss ${r.packetLossPercent?.toStringAsFixed(0) ?? '—'}%\n${r.server ?? ''}    ·    ${r.timestamp.toLocal()}';
  }

  Future<void> save() async {
    try {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      final reply = await Process.run(
          '$root\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
          [
            '-NoProfile',
            '-STA',
            '-Command',
            r"""[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); Add-Type -AssemblyName System.Windows.Forms; $d=New-Object Windows.Forms.SaveFileDialog; $d.Filter='PNG (*.png)|*.png'; $d.FileName='RAR-NetCare-result.png'; if($d.ShowDialog() -eq 'OK'){[Console]::Write($d.FileName)}"""
          ],
          stdoutEncoding: utf8);
      if (reply.exitCode != 0)
        throw const FileSystemException('Save dialog failed');
      final path = reply.stdout.toString();
      if (path.isEmpty) return;
      await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saved $path')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PNG export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RepaintBoundary(
            key: key,
            child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RAR NetCare   •   Speed & latency',
                              style: Theme.of(context).textTheme.titleLarge),
                          for (final latency in [false, true]) ...[
                            Text(latency
                                ? 'HTTP latency · ms'
                                : 'Transfer average · Mbps'),
                            SizedBox(
                                height: 65,
                                width: double.infinity,
                                child: CustomPaint(
                                    painter: _Plot(widget.samples, latency))),
                          ],
                          const Text(
                              'Blue · Download     Green · Upload     Amber · Idle'),
                          Text(summary),
                        ])))),
        if (widget.result != null)
          Wrap(children: [
            TextButton(onPressed: save, child: const Text('Save PNG')),
            TextButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: summary)),
                child: const Text('Copy result'))
          ])
      ]);
}

class _Plot extends CustomPainter {
  _Plot(this.samples, this.latency);
  final List<TraceSample> samples;
  final bool latency;
  @override
  void paint(Canvas c, Size s) {
    final points = samples.where((p) => p.kind.contains('latency') == latency);
    final peak = points.fold(1.0, (a, b) => math.max(a, b.value));
    final previous = <String, Offset>{};
    for (final p in points) {
      final pos = Offset(s.width * p.ms / math.max(1, samples.last.ms),
          s.height - 3 - (s.height - 6) * p.value / peak);
      final paint = Paint()
        ..strokeWidth = 2
        ..color = p.kind.startsWith('Download')
            ? Colors.blue
            : p.kind.startsWith('Upload')
                ? Colors.teal
                : Colors.amber;
      if (previous.containsKey(p.kind))
        c.drawLine(previous[p.kind]!, pos, paint);
      c.drawCircle(pos, 2, paint);
      previous[p.kind] = pos;
    }
  }

  @override
  bool shouldRepaint(_Plot old) => true;
}
