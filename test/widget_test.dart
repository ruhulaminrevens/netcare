import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ruhul_netcare/widgets/netcare_widgets.dart';

void main() {
  testWidgets('interactive cards render on a Material surface', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionCard(
            child: ListTile(title: Text('Ruhul NetCare')),
          ),
        ),
      ),
    );

    expect(find.text('Ruhul NetCare'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
