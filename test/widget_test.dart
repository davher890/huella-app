import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:the_horse_tracker_app/main.dart';

void main() {
  testWidgets('App starts and shows the login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const HorseTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesion'), findsOneWidget);
  });
}
