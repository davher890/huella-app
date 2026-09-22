import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:the_horse_tracker_app/main.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_secure_storage has no platform implementation in the test
  // binding, so its method channel is mocked to behave as an empty store.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
    if (call.method == 'read') return null;
    if (call.method == 'readAll') return <String, String>{};
    return null;
  });

  testWidgets('App starts and shows the login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const HorseTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesion'), findsOneWidget);
  });
}
