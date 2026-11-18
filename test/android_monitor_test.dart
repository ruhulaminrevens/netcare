import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruhul_netcare/monitor/android_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('rar_netcare/android');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final allowed in [false, true]) {
    testWidgets('Usage access = $allowed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'permissions')
          return {'usage': allowed, 'running': false, 'overlay': false};
        if (call.method == 'usage')
          return [
            {'day': 1735689600000, 'rx': 2000000, 'tx': 1000000},
          ];
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AndroidMonitor(active: true, bangla: false)),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.contains('usage'), allowed);
      if (allowed) {
        expect(find.byType(Tooltip), findsWidgets);
        await tester.tap(find.text('Day-wise'));
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsOneWidget);
      } else {
        expect(find.text('Open Usage Access'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
