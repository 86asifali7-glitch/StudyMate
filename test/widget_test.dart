import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/app/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App navigation flow test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('StudyMate'), findsWidgets);

    // Fast-forward 3 seconds for splash timer
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify Onboarding Screen
    expect(find.text('Welcome to StudyMate'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Tap Get Started to go to MainShell (Home)
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify Home Screen content
    expect(find.text('Quick Access'), findsOneWidget);

    // Tap Notes tab in bottom navigation
    await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('My Notes'), findsOneWidget);

    // Tap Tasks tab in bottom navigation
    await tester.tap(find.byIcon(Icons.check_circle_outline_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Stay organized. Get things done.'), findsOneWidget);

    // Tap Timetable tab in bottom navigation
    await tester.tap(find.byIcon(Icons.calendar_month_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Your weekly class schedule'), findsOneWidget);

    // Tap Home tab in bottom navigation
    await tester.tap(find.byIcon(Icons.home_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Quick Access'), findsOneWidget);
  });
}




