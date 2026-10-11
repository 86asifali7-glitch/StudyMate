import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/app/app.dart';

void main() {
  testWidgets('App navigation flow test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('StudyMate'), findsWidgets);

    // Fast-forward 3 seconds for splash timer
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify Onboarding Screen
    expect(find.text('Welcome to StudyMate'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Tap Get Started to go to Home Screen
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify Home Screen
    expect(find.text('Welcome back! 👋'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Tap Notes
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('My Notes'), findsOneWidget);
    expect(find.text('Add Note'), findsOneWidget);

    // Go back
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tap Tasks
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Study Tasks'), findsOneWidget);
    expect(find.text('Add Task'), findsOneWidget);

    // Go back
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tap Timetable
    await tester.tap(find.text('Timetable'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Timetable'), findsOneWidget);

    // Go back
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tap Profile
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Student Profile'), findsOneWidget);
    expect(find.text('Alex Johnson'), findsOneWidget);

    // Tap Edit Profile icon in AppBar
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Edit Student Information'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    // Edit Name
    await tester.enterText(find.widgetWithText(TextField, 'Alex Johnson'), 'Alex Smith');
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify saved info
    expect(find.text('Alex Smith'), findsOneWidget);
    expect(find.text('Profile saved successfully!'), findsOneWidget);
  });
}



