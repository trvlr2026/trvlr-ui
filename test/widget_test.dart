import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trvlr_ui/app.dart';
import 'package:trvlr_ui/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches splash screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const TrvlrApp(),
      ),
    );
    expect(find.text('Trvlr'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
