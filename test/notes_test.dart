import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/app/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Test creating, editing, saving, and reopening notes with persistence',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // From Onboarding to Home
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Navigate to Notes screen
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    // Verify notes list is displayed with existing notes
    expect(find.text('My Notes'), findsOneWidget);
    expect(find.text('Calculus Derivatives & Integrals'), findsOneWidget);

    // 1. TEST CREATING A NOTE
    // Tap Create Note button
    await tester.tap(find.text('Create Note'));
    await tester.pumpAndSettle();

    expect(find.text('New Note'), findsOneWidget);
    expect(find.byKey(const Key('save_note_button')), findsOneWidget);

    // Fill in new note details
    await tester.enterText(
        find.byKey(const Key('note_title_field')), 'Linear Algebra Eigenvalues');
    await tester.enterText(
        find.byKey(const Key('note_subject_field')), 'Mathematics');
    await tester.enterText(find.byKey(const Key('note_content_field')),
        'Characteristic equation: det(A - lambda * I) = 0.');

    // Save the new note
    await tester.tap(find.byKey(const Key('save_note_button')));
    await tester.pumpAndSettle();

    // Verify note is saved and present in the list
    expect(find.text('Linear Algebra Eigenvalues'), findsOneWidget);
    expect(find.text('Note saved successfully!'), findsOneWidget);

    // 2. TEST REOPENING AND VERIFYING CONTENT
    await tester.tap(find.text('Linear Algebra Eigenvalues'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Note'), findsOneWidget);
    final titleFieldFinder = find.byKey(const Key('note_title_field'));
    expect(
      (tester.widget(titleFieldFinder) as TextField).controller!.text,
      'Linear Algebra Eigenvalues',
    );
    final contentFieldFinder = find.byKey(const Key('note_content_field'));
    expect(
      (tester.widget(contentFieldFinder) as TextField).controller!.text,
      'Characteristic equation: det(A - lambda * I) = 0.',
    );

    // 3. TEST EDITING AND SAVING
    await tester.enterText(
      find.byKey(const Key('note_title_field')),
      'Linear Algebra - Diagonalization & Eigenvalues',
    );
    await tester.enterText(
      find.byKey(const Key('note_content_field')),
      'Characteristic equation: det(A - lambda * I) = 0.\nA = P * D * P^(-1).',
    );
    await tester.tap(find.byKey(const Key('save_note_button')));
    await tester.pumpAndSettle();

    // Verify edited note in list
    expect(
      find.text('Linear Algebra - Diagonalization & Eigenvalues'),
      findsOneWidget,
    );

    // 4. TEST PERSISTENCE ACROSS NAVIGATION
    // Navigate back to Home
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Welcome back! 👋'), findsOneWidget);

    // Navigate to Notes again
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    // Reopen the edited note again
    expect(
      find.text('Linear Algebra - Diagonalization & Eigenvalues'),
      findsOneWidget,
    );
    await tester.tap(find.text('Linear Algebra - Diagonalization & Eigenvalues'));
    await tester.pumpAndSettle();

    // Check all preserved fields
    expect(
      (tester.widget(titleFieldFinder) as TextField).controller!.text,
      'Linear Algebra - Diagonalization & Eigenvalues',
    );
    expect(
      (tester.widget(contentFieldFinder) as TextField).controller!.text,
      'Characteristic equation: det(A - lambda * I) = 0.\nA = P * D * P^(-1).',
    );
  });
}
