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

    await _scrollToText(tester, 'For language learners');
    expect(find.text('For language learners'), findsOneWidget);
    expect(find.text('Language learner'), findsOneWidget);
    expect(find.text('Grammar'), findsNothing);
    expect(find.text('Pronunciation'), findsNothing);

    await _scrollToText(tester, 'My data');
    expect(find.text('My data'), findsOneWidget);

    await _scrollToText(tester, 'Dark mode');
    expect(find.text('Dark mode'), findsOneWidget);
  });
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  for (var i = 0; i < 12; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  fail('Could not find "$text" after scrolling settings.');
}
