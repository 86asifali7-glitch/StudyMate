import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen displays correct notes count in Quick Access and Stats',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Default note count is 3 (matches the 3 starter notes in NotesScreen)
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('3'), findsWidgets); // quick access & stats row
    expect(find.text('12 items'), findsNothing);
    expect(find.text('12'), findsNothing);
  });

  testWidgets('HomeScreen displays updated notes count when saved in storage',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'studymate_saved_notes': ['{"id":"1","title":"Test Note 1"}'],
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('12 items'), findsNothing);
  });
}
