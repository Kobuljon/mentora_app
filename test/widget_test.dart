import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentora_app/features/settings/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings screen renders the planned sections', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Models'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('For language learners'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('For language learners'), findsOneWidget);
    expect(find.text('Language learner'), findsOneWidget);
    expect(find.text('Grammar'), findsNothing);
    expect(find.text('Pronunciation'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('My data'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('My data'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Dark mode'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Dark mode'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Auto save notes'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Auto save notes'), findsOneWidget);
  });
}
