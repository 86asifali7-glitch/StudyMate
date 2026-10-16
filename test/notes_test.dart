import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/app/app.dart';
import 'package:studymate/screens/notes_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotesScreen.resetForTesting();
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
    await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
    await tester.pumpAndSettle();

    // Verify notes list is displayed with existing notes
    expect(find.text('My Notes'), findsOneWidget);
    expect(find.text('Calculus Derivatives & Integrals'), findsOneWidget);

    // 1. TEST CREATING A NOTE VIA POPUP DIALOG
    // Tap Create Note button
    await tester.tap(find.byKey(const Key('create_note_button')));
    await tester.pumpAndSettle();

    // Verify centered popup dialog is shown with Title and Subject inputs and Cancel/Create buttons
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const Key('create_note_title_field')), findsOneWidget);
    expect(find.byKey(const Key('create_note_subject_field')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);

    // Test Cancel button dismisses dialog without adding note
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    // Tap Create Note again to actually create the note
    await tester.tap(find.byKey(const Key('create_note_button')));
    await tester.pumpAndSettle();

    // Fill in Title and Subject in popup dialog
    await tester.enterText(
        find.byKey(const Key('create_note_title_field')), 'Linear Algebra Eigenvalues');
    await tester.enterText(
        find.byKey(const Key('create_note_subject_field')), 'Mathematics');

    // Click Create button
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Verify popup dialog is closed and note appears in the Notes list
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Linear Algebra Eigenvalues'), findsOneWidget);

    // 2. TEST CLICKING THE NOTE TO OPEN FULL EDITOR AND ADDING CONTENT
    await tester.tap(find.text('Linear Algebra Eigenvalues'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Note'), findsOneWidget);
    expect(find.byKey(const Key('save_note_button')), findsOneWidget);
    final titleFieldFinder = find.byKey(const Key('note_title_field'));
    expect(
      (tester.widget(titleFieldFinder) as TextField).controller!.text,
      'Linear Algebra Eigenvalues',
    );
    final subjectFieldFinder = find.byKey(const Key('note_subject_field'));
    expect(
      (tester.widget(subjectFieldFinder) as TextField).controller!.text,
      'Mathematics',
    );

    // Add detailed content in full editor
    await tester.enterText(find.byKey(const Key('note_content_field')),
        'Characteristic equation: det(A - lambda * I) = 0.');
    await tester.tap(find.byKey(const Key('save_note_button')));
    await tester.pumpAndSettle();

    expect(find.text('Note saved successfully!'), findsOneWidget);

    // Reopen to verify content and perform additional edits
    await tester.tap(find.text('Linear Algebra Eigenvalues'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Note'), findsOneWidget);
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
    await tester.tap(find.byIcon(Icons.home_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Quick Access'), findsOneWidget);

    // Navigate to Notes again
    await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
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

  testWidgets(
      'Test all formatting toolbar buttons: Bold, Italic, Underline, Bulleted list, Numbered list, Formula, saving and reopening with rich-text',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Go to Notes
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
    await tester.pumpAndSettle();

    // Open first note editor
    await tester.tap(find.text('Calculus Derivatives & Integrals'));
    await tester.pumpAndSettle();

    final contentFieldFinder = find.byKey(const Key('note_content_field'));
    expect(contentFieldFinder, findsOneWidget);
    final textField = tester.widget<TextField>(contentFieldFinder);
    final controller = textField.controller! as RichTextEditingController;

    // ─── 1. TEST BOLD ON SELECTED TEXT & NEWLY TYPED TEXT ──────────────────
    // A) Bold on selected text: select "Sample" and format as bold
    controller.value = const TextEditingValue(
      text: 'Sample text',
      selection: TextSelection(baseOffset: 0, extentOffset: 6),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_bold_button')));
    await tester.pumpAndSettle();

    // Must visually format text WITHOUT inserting visible Markdown symbols (**)
    expect(controller.text, 'Sample text');
    expect(controller.text.contains('*'), isFalse);
    expect(controller.isBoldAtSelection(), isTrue);

    // Toggle Bold OFF on "Sample"
    await tester.tap(find.byKey(const Key('format_bold_button')));
    await tester.pumpAndSettle();
    expect(controller.text, 'Sample text');
    expect(controller.isBoldAtSelection(), isFalse);

    // B) Bold on newly typed text: tap bold with collapsed cursor
    controller.value = const TextEditingValue(
      text: 'Sample text',
      selection: TextSelection.collapsed(offset: 11),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_bold_button')));
    await tester.pumpAndSettle();

    // Verify bold mode active, but NO asterisks inserted into text
    expect(controller.isBoldAtSelection(), isTrue);
    expect(controller.text, 'Sample text');
    expect(controller.text.contains('*'), isFalse);

    // Type new text while bold is active
    await tester.enterText(contentFieldFinder, 'Sample text more');
    await tester.pumpAndSettle();
    expect(controller.text, 'Sample text more');
    expect(controller.text.contains('*'), isFalse);

    // ─── 2. TEST ITALIC TOOLBAR BUTTON ─────────────────────────────────────
    // Select "text" and format as italic
    controller.value = const TextEditingValue(
      text: 'Sample text',
      selection: TextSelection(baseOffset: 7, extentOffset: 11),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_italic_button')));
    await tester.pumpAndSettle();

    // Must visually format text WITHOUT inserting asterisks
    expect(controller.text, 'Sample text');
    expect(controller.text.contains('*'), isFalse);
    expect(controller.isItalicAtSelection(), isTrue);

    // Toggle Italic OFF on "text"
    await tester.tap(find.byKey(const Key('format_italic_button')));
    await tester.pumpAndSettle();
    expect(controller.text, 'Sample text');
    expect(controller.isItalicAtSelection(), isFalse);

    // ─── 3. TEST UNDERLINE TOOLBAR BUTTON ──────────────────────────────────
    // Select "Sample" and format as underline
    controller.value = const TextEditingValue(
      text: 'Sample text',
      selection: TextSelection(baseOffset: 0, extentOffset: 6),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_underline_button')));
    await tester.pumpAndSettle();

    // Must visually format text WITHOUT inserting <u> or _ symbols
    expect(controller.text, 'Sample text');
    expect(controller.text.contains('<u>'), isFalse);
    expect(controller.text.contains('_'), isFalse);
    expect(controller.isUnderlineAtSelection(), isTrue);

    // Toggle Underline OFF on "Sample"
    await tester.tap(find.byKey(const Key('format_underline_button')));
    await tester.pumpAndSettle();
    expect(controller.text, 'Sample text');
    expect(controller.isUnderlineAtSelection(), isFalse);

    // ─── 4. TEST BULLETED LIST TOOLBAR BUTTON ──────────────────────────────
    controller.value = const TextEditingValue(
      text: 'Item one',
      selection: TextSelection.collapsed(offset: 4),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_bullet_button')));
    await tester.pumpAndSettle();
    expect(controller.text, '• Item one');

    // Toggle Bulleted list OFF
    await tester.tap(find.byKey(const Key('format_bullet_button')));
    await tester.pumpAndSettle();
    expect(controller.text, 'Item one');

    // ─── 5. TEST NUMBERED LIST TOOLBAR BUTTON ──────────────────────────────
    await tester.tap(find.byKey(const Key('format_numbered_button')));
    await tester.pumpAndSettle();
    expect(controller.text, '1. Item one');

    // Toggle Numbered list OFF
    await tester.tap(find.byKey(const Key('format_numbered_button')));
    await tester.pumpAndSettle();
    expect(controller.text, 'Item one');

    // ─── 6. TEST FORMULA / SYMBOL PICKER ───────────────────────────────────
    controller.value = const TextEditingValue(
      text: 'Equation: ',
      selection: TextSelection.collapsed(offset: 10),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_formula_button')));
    await tester.pumpAndSettle();

    // Verify formula picker bottom sheet opened
    expect(find.text('Insert Formula / Symbol'), findsOneWidget);
    expect(find.text('Quick Symbols'), findsOneWidget);
    expect(find.text('Formula Templates'), findsOneWidget);

    // Tap '∫' symbol
    await tester.tap(find.text('∫'));
    await tester.pumpAndSettle();

    expect(controller.text, 'Equation: ∫');

    // ─── 7. TEST SAVING AND REOPENING RICH-FORMATTED NOTE ──────────────────
    // Apply rich formatting via toolbar
    controller.value = const TextEditingValue(
      text: 'Key formulas:\n• ∫ f(x) dx\n• Derivative: d/dx [x^n] = n*x^(n-1)\n1. First principle\n2. Second principle',
      selection: TextSelection(baseOffset: 0, extentOffset: 13), // "Key formulas:"
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_bold_button')));
    await tester.pumpAndSettle();

    controller.value = const TextEditingValue(
      text: 'Key formulas:\n• ∫ f(x) dx\n• Derivative: d/dx [x^n] = n*x^(n-1)\n1. First principle\n2. Second principle',
      selection: TextSelection(baseOffset: 28, extentOffset: 39), // "Derivative:"
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_underline_button')));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.byKey(const Key('save_note_button')));
    await tester.pumpAndSettle();
    expect(find.text('Note saved successfully!'), findsOneWidget);

    // Reopen note from list
    await tester.tap(find.text('Calculus Derivatives & Integrals'));
    await tester.pumpAndSettle();

    // Verify content retained all text with ZERO Markdown symbols
    final reopenedField = tester.widget<TextField>(find.byKey(const Key('note_content_field')));
    final reopenedController = reopenedField.controller! as RichTextEditingController;
    expect(
      reopenedController.text,
      'Key formulas:\n• ∫ f(x) dx\n• Derivative: d/dx [x^n] = n*x^(n-1)\n1. First principle\n2. Second principle',
    );
    expect(reopenedController.text.contains('**'), isFalse);
    expect(reopenedController.text.contains('<u>'), isFalse);
    expect(reopenedController.text.contains('*First*'), isFalse);

    // Verify rich formatting is preserved on reopened note
    reopenedController.selection = const TextSelection(baseOffset: 0, extentOffset: 13);
    expect(reopenedController.isBoldAtSelection(), isTrue);

    reopenedController.selection = const TextSelection(baseOffset: 28, extentOffset: 39);
    expect(reopenedController.isUnderlineAtSelection(), isTrue);

    // ─── 8. TEST LEGACY MARKDOWN MIGRATION ─────────────────────────────────
    // Existing legacy notes with raw markdown must load cleanly with formatting converted
    final legacyController = RichTextEditingController.fromNote(
      '**Bold Title** and *italic word* and <u>underlined</u>',
      null,
    );
    expect(legacyController.text, 'Bold Title and italic word and underlined');
    expect(legacyController.text.contains('**'), isFalse);
    expect(legacyController.text.contains('*'), isFalse);
    expect(legacyController.text.contains('<u>'), isFalse);

    legacyController.selection = const TextSelection(baseOffset: 0, extentOffset: 10);
    expect(legacyController.isBoldAtSelection(), isTrue);

    legacyController.selection = const TextSelection(baseOffset: 15, extentOffset: 26);
    expect(legacyController.isItalicAtSelection(), isTrue);

    legacyController.selection = const TextSelection(baseOffset: 31, extentOffset: 41);
    expect(legacyController.isUnderlineAtSelection(), isTrue);
  });
}
