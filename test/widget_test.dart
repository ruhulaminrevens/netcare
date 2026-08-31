import 'package:flutter_test/flutter_test.dart';
import 'package:ruhul_netcare/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the app identity', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const NetCareApp());
    await tester.pump();

    expect(find.text('Ruhul NetCare'), findsOneWidget);
  });
}
