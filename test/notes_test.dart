import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/app/app.dart';
import 'package:studymate/screens/notes_screen.dart';

quill.QuillController getQuillController(WidgetTester tester) {
  final editor = tester.widget<quill.QuillEditor>(
      find.byKey(const Key('note_content_field')));
  return editor.controller;
}

Future<void> enterQuillText(WidgetTester tester, String text) async {
  final controller = getQuillController(tester);
  final docLen = controller.document.length;
  controller.replaceText(0, docLen > 1 ? docLen - 1 : 0, text, null);
  await tester.pumpAndSettle();
}

TextAlign getParagraphAlignmentAt(quill.QuillController controller, int offset) {
  final savedSelection = controller.selection;
  controller.updateSelection(
    TextSelection.collapsed(offset: offset),
    quill.ChangeSource.local,
  );
  final style = controller.getSelectionStyle();
  final alignVal = style.attributes[quill.Attribute.align.key]?.value;
  if (savedSelection.isValid) {
    controller.updateSelection(savedSelection, quill.ChangeSource.local);
  }
  if (alignVal == quill.Attribute.centerAlignment.value ||
      alignVal == 'center') {
    return TextAlign.center;
  }
  if (alignVal == quill.Attribute.rightAlignment.value || alignVal == 'right') {
    return TextAlign.right;
  }
  if (alignVal == quill.Attribute.justifyAlignment.value ||
      alignVal == 'justify') {
    return TextAlign.justify;
  }
  return TextAlign.left;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotesScreen.resetForTesting();
  });

  testWidgets(
      'Test creating, editing, saving, and reopening notes with persistence',
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
    await tester.tap(find.byKey(const Key('create_note_button')));
    await tester.pumpAndSettle();

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
    await enterQuillText(
        tester, 'Characteristic equation: det(A - lambda * I) = 0.\n');
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
    expect(
      getQuillController(tester).document.toPlainText().trimRight(),
      'Characteristic equation: det(A - lambda * I) = 0.',
    );

    // 3. TEST EDITING AND SAVING
    await tester.enterText(
      find.byKey(const Key('note_title_field')),
      'Linear Algebra - Diagonalization & Eigenvalues',
    );
    await enterQuillText(
      tester,
      'Characteristic equation: det(A - lambda * I) = 0.\nA = P * D * P^(-1).\n',
    );
    await tester.tap(find.byKey(const Key('save_note_button')));
    await tester.pumpAndSettle();

    // Verify edited note in list
    expect(
      find.text('Linear Algebra - Diagonalization & Eigenvalues'),
      findsOneWidget,
    );

    // 4. TEST PERSISTENCE ACROSS NAVIGATION
    await tester.tap(find.byIcon(Icons.home_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Quick Access'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
    await tester.pumpAndSettle();

    expect(
      find.text('Linear Algebra - Diagonalization & Eigenvalues'),
      findsOneWidget,
    );
    await tester.tap(find.text('Linear Algebra - Diagonalization & Eigenvalues'));
    await tester.pumpAndSettle();

    expect(
      (tester.widget(titleFieldFinder) as TextField).controller!.text,
      'Linear Algebra - Diagonalization & Eigenvalues',
    );
    expect(
      getQuillController(tester).document.toPlainText().trimRight(),
      'Characteristic equation: det(A - lambda * I) = 0.\nA = P * D * P^(-1).',
    );
  });

  testWidgets(
      'Test all formatting toolbar buttons: Bold, Italic, Underline, Bulleted list, Numbered list, Formula, saving and reopening with rich-text',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
    await tester.pumpAndSettle();

    // Open first note editor
    await tester.tap(find.text('Calculus Derivatives & Integrals'));
    await tester.pumpAndSettle();

    final contentFieldFinder = find.byKey(const Key('note_content_field'));
    expect(contentFieldFinder, findsOneWidget);
    final controller = getQuillController(tester);

    // ─── 1. TEST BOLD ON SELECTED TEXT ─────────────────────────────────────
    await enterQuillText(tester, 'Sample text\n');
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 6),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('format_bold_button')));
    await tester.pumpAndSettle();

    expect(controller.document.toPlainText().trimRight(), 'Sample text');
    expect(controller.document.toPlainText().contains('*'), isFalse);
    expect(
        controller.getSelectionStyle().containsKey(quill.Attribute.bold.key),
        isTrue);

    // Toggle Bold OFF on "Sample"
    await tester.tap(find.byKey(const Key('format_bold_button')));
    await tester.pumpAndSettle();
    expect(controller.document.toPlainText().trimRight(), 'Sample text');
    expect(
        controller.getSelectionStyle().containsKey(quill.Attribute.bold.key),
        isFalse);

    // ─── 2. TEST ITALIC TOOLBAR BUTTON ─────────────────────────────────────
    controller.updateSelection(
      const TextSelection(baseOffset: 7, extentOffset: 11),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('format_italic_button')));
    await tester.pumpAndSettle();

    expect(controller.document.toPlainText().trimRight(), 'Sample text');
    expect(controller.document.toPlainText().contains('*'), isFalse);
    expect(
        controller.getSelectionStyle().containsKey(quill.Attribute.italic.key),
        isTrue);

    // Toggle Italic OFF
    await tester.tap(find.byKey(const Key('format_italic_button')));
    await tester.pumpAndSettle();
    expect(
        controller.getSelectionStyle().containsKey(quill.Attribute.italic.key),
        isFalse);

    // ─── 3. TEST UNDERLINE TOOLBAR BUTTON ──────────────────────────────────
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 6),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('format_underline_button')));
    await tester.pumpAndSettle();

    expect(controller.document.toPlainText().trimRight(), 'Sample text');
    expect(controller.document.toPlainText().contains('<u>'), isFalse);
    expect(
        controller
            .getSelectionStyle()
            .containsKey(quill.Attribute.underline.key),
        isTrue);

    // Toggle Underline OFF
    await tester.tap(find.byKey(const Key('format_underline_button')));
    await tester.pumpAndSettle();
    expect(
        controller
            .getSelectionStyle()
            .containsKey(quill.Attribute.underline.key),
        isFalse);

    // ─── 4. TEST BULLETED LIST TOOLBAR BUTTON ──────────────────────────────
    await enterQuillText(tester, 'Item one\n');
    controller.updateSelection(
      const TextSelection.collapsed(offset: 4),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('format_bullet_button')));
    await tester.pumpAndSettle();
    expect(
      controller.getSelectionStyle().attributes[quill.Attribute.list.key]?.value,
      quill.Attribute.ul.value,
    );

    // Toggle Bulleted list OFF
    await tester.tap(find.byKey(const Key('format_bullet_button')));
    await tester.pumpAndSettle();
    expect(
      controller.getSelectionStyle().attributes[quill.Attribute.list.key]?.value,
      isNull,
    );

    // ─── 5. TEST NUMBERED LIST TOOLBAR BUTTON ──────────────────────────────
    await tester.tap(find.byKey(const Key('format_numbered_button')));
    await tester.pumpAndSettle();
    expect(
      controller.getSelectionStyle().attributes[quill.Attribute.list.key]?.value,
      quill.Attribute.ol.value,
    );

    // Toggle Numbered list OFF
    await tester.tap(find.byKey(const Key('format_numbered_button')));
    await tester.pumpAndSettle();
    expect(
      controller.getSelectionStyle().attributes[quill.Attribute.list.key]?.value,
      isNull,
    );

    // ─── 6. TEST FORMULA / SYMBOL PICKER ───────────────────────────────────
    await enterQuillText(tester, 'Equation: \n');
    controller.updateSelection(
      const TextSelection.collapsed(offset: 10),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('format_formula_button')));
    await tester.pumpAndSettle();

    expect(find.text('Insert Formula / Symbol'), findsOneWidget);
    expect(find.text('Quick Symbols'), findsOneWidget);
    expect(find.text('Formula Templates'), findsOneWidget);

    await tester.tap(find.text('∫'));
    await tester.pumpAndSettle();

    expect(controller.document.toPlainText().trimRight(), 'Equation: ∫');

    // ─── 7. TEST SAVING AND REOPENING RICH-FORMATTED NOTE ──────────────────
    await enterQuillText(
      tester,
      'Key formulas:\n• ∫ f(x) dx\n• Derivative: d/dx [x^n] = n*x^(n-1)\n',
    );
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 13),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_bold_button')));
    await tester.pumpAndSettle();

    controller.updateSelection(
      const TextSelection(baseOffset: 28, extentOffset: 39),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_underline_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_note_button')));
    await tester.pumpAndSettle();
    expect(find.text('Note saved successfully!'), findsOneWidget);

    // Reopen note from list
    await tester.tap(find.text('Calculus Derivatives & Integrals'));
    await tester.pumpAndSettle();

    final reopenedController = getQuillController(tester);
    expect(
      reopenedController.document.toPlainText().trimRight(),
      'Key formulas:\n• ∫ f(x) dx\n• Derivative: d/dx [x^n] = n*x^(n-1)',
    );

    // Verify rich formatting is preserved on reopened note
    reopenedController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 13),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    expect(
      reopenedController
          .getSelectionStyle()
          .containsKey(quill.Attribute.bold.key),
      isTrue,
    );

    reopenedController.updateSelection(
      const TextSelection(baseOffset: 28, extentOffset: 39),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    expect(
      reopenedController
          .getSelectionStyle()
          .containsKey(quill.Attribute.underline.key),
      isTrue,
    );

    // ─── 8. TEST LEGACY MARKDOWN MIGRATION ─────────────────────────────────
    final doc = NoteEditorScreen.noteToQuillDocument(
      '**Bold Title** and *italic word* and <u>underlined</u>',
      null,
    );
    expect(doc.toPlainText().trimRight(),
        'Bold Title and italic word and underlined');
    expect(doc.toPlainText().contains('**'), isFalse);
    expect(doc.toPlainText().contains('*'), isFalse);
    expect(doc.toPlainText().contains('<u>'), isFalse);
  });

  testWidgets('Test text alignment option in formatting bar and persistence',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calculus Derivatives & Integrals'));
    await tester.pumpAndSettle();

    final alignButtonFinder = find.byKey(const Key('format_align_button'));
    expect(alignButtonFinder, findsOneWidget);

    final controller = getQuillController(tester);

    const shortParagraph = 'Calculus Derivatives & Integrals';
    const longParagraph =
        'The derivative of a function of a real variable measures the sensitivity to change of the function value with respect to a change in its argument. Fundamental calculus concepts are essential for advanced physics and engineering analysis.';
    await enterQuillText(tester, '$shortParagraph\n$longParagraph\n');

    // Initial check: All paragraphs Left
    expect(getParagraphAlignmentAt(controller, 0), TextAlign.left);
    expect(
      getParagraphAlignmentAt(controller, shortParagraph.length + 5),
      TextAlign.left,
    );

    // 1. Center alignment on short heading paragraph (Left -> Center)
    controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.tap(alignButtonFinder);
    await tester.pumpAndSettle();

    expect(getParagraphAlignmentAt(controller, 0), TextAlign.center);
    // Unselected long paragraph remains Left
    expect(
      getParagraphAlignmentAt(controller, shortParagraph.length + 5),
      TextAlign.left,
    );
    expect(find.byIcon(Icons.format_align_center_rounded), findsOneWidget);

    // 2. Right alignment (Center -> Right)
    await tester.tap(alignButtonFinder);
    await tester.pumpAndSettle();
    expect(getParagraphAlignmentAt(controller, 0), TextAlign.right);
    expect(
      getParagraphAlignmentAt(controller, shortParagraph.length + 5),
      TextAlign.left,
    );
    expect(find.byIcon(Icons.format_align_right_rounded), findsOneWidget);

    // 3. Justify alignment (Right -> Justify)
    await tester.tap(alignButtonFinder);
    await tester.pumpAndSettle();
    expect(getParagraphAlignmentAt(controller, 0), TextAlign.justify);
    expect(
      getParagraphAlignmentAt(controller, shortParagraph.length + 5),
      TextAlign.left,
    );
    expect(find.byIcon(Icons.format_align_justify_rounded), findsOneWidget);

    // 4. Left alignment (Justify -> Left)
    await tester.tap(alignButtonFinder);
    await tester.pumpAndSettle();
    expect(getParagraphAlignmentAt(controller, 0), TextAlign.left);
    expect(
      getParagraphAlignmentAt(controller, shortParagraph.length + 5),
      TextAlign.left,
    );
    expect(find.byIcon(Icons.format_align_left_rounded), findsOneWidget);

    // 5. Long-press alignment modal picker on the long paragraph
    controller.updateSelection(
      TextSelection(
        baseOffset: shortParagraph.length + 5,
        extentOffset: shortParagraph.length + 5,
      ),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.longPress(alignButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Text Alignment'), findsOneWidget);
    expect(find.byKey(const Key('format_align_left_option')), findsOneWidget);
    expect(find.byKey(const Key('format_align_center_option')), findsOneWidget);
    expect(find.byKey(const Key('format_align_right_option')), findsOneWidget);
    expect(find.byKey(const Key('format_align_justify_option')), findsOneWidget);

    // Choose Justify for the long paragraph
    await tester.tap(find.byKey(const Key('format_align_justify_option')));
    await tester.pumpAndSettle();

    expect(
      getParagraphAlignmentAt(controller, shortParagraph.length + 5),
      TextAlign.justify,
    );
    expect(getParagraphAlignmentAt(controller, 0), TextAlign.left);
    expect(find.byIcon(Icons.format_align_justify_rounded), findsOneWidget);

    // 6. Save note and verify alignment is persisted when reopening
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Note saved successfully!'), findsOneWidget);

    // Reopen the note
    await tester.tap(find.text('Calculus Derivatives & Integrals'));
    await tester.pumpAndSettle();

    final reopenedController = getQuillController(tester);
    expect(
      reopenedController.document.toPlainText().trimRight(),
      '$shortParagraph\n$longParagraph',
    );

    // Verify paragraph 0 is preserved as Left
    expect(getParagraphAlignmentAt(reopenedController, 0), TextAlign.left);

    // Verify paragraph 1 is Justified as saved!
    expect(
      getParagraphAlignmentAt(reopenedController, shortParagraph.length + 5),
      TextAlign.justify,
    );
    reopenedController.updateSelection(
      TextSelection.collapsed(offset: shortParagraph.length + 5),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.format_align_justify_rounded), findsOneWidget);

    // Switch alignment to Center via picker on reopened note
    await tester.longPress(alignButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_align_center_option')));
    await tester.pumpAndSettle();

    expect(
      getParagraphAlignmentAt(reopenedController, shortParagraph.length + 5),
      TextAlign.center,
    );
    expect(getParagraphAlignmentAt(reopenedController, 0), TextAlign.left);
    expect(find.byIcon(Icons.format_align_center_rounded), findsOneWidget);
  });

  testWidgets(
      'Test multi-paragraph alignment selection behavior: Left, Center, Right, Justify with unselected paragraphs unchanged',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calculus Derivatives & Integrals'));
    await tester.pumpAndSettle();

    final alignButtonFinder = find.byKey(const Key('format_align_button'));
    final controller = getQuillController(tester);

    const p0 = 'Header Paragraph';
    const p1 = 'First body paragraph discussing calculus derivations.';
    const p2 = 'Second body paragraph focusing on integral equations.';
    const p3 = 'Final summary conclusion paragraph for review.';
    final fullText = '$p0\n$p1\n$p2\n$p3\n';

    await enterQuillText(tester, fullText);

    final p0Offset = 2;
    final p1Offset = p0.length + 1 + 5;
    final p2Offset = p0.length + 1 + p1.length + 1 + 5;
    final p3Offset = p0.length + 1 + p1.length + 1 + p2.length + 1 + 5;

    // 1. Initial check: All paragraphs are Left-aligned in document model
    expect(getParagraphAlignmentAt(controller, p0Offset), TextAlign.left);
    expect(getParagraphAlignmentAt(controller, p1Offset), TextAlign.left);
    expect(getParagraphAlignmentAt(controller, p2Offset), TextAlign.left);
    expect(getParagraphAlignmentAt(controller, p3Offset), TextAlign.left);

    // 2. Apply Center alignment to Paragraph 0 with collapsed cursor
    controller.updateSelection(
      TextSelection.collapsed(offset: p0Offset),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.tap(alignButtonFinder);
    await tester.pumpAndSettle();

    // Paragraph 0 is now Center
    expect(getParagraphAlignmentAt(controller, p0Offset), TextAlign.center);
    expect(find.byIcon(Icons.format_align_center_rounded), findsOneWidget);

    // Check that unselected paragraphs (1, 2, 3) remain unchanged (Left)
    expect(getParagraphAlignmentAt(controller, p1Offset), TextAlign.left);
    expect(getParagraphAlignmentAt(controller, p2Offset), TextAlign.left);
    expect(getParagraphAlignmentAt(controller, p3Offset), TextAlign.left);

    // 3. Select text inside Paragraph 1 and apply Right alignment
    controller.updateSelection(
      TextSelection(
        baseOffset: p0.length + 1 + 3,
        extentOffset: p0.length + 1 + 18,
      ),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.longPress(alignButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_align_right_option')));
    await tester.pumpAndSettle();

    // Paragraph 1 is now Right-aligned
    expect(getParagraphAlignmentAt(controller, p1Offset), TextAlign.right);
    expect(find.byIcon(Icons.format_align_right_rounded), findsOneWidget);

    // Verify selection was preserved on Paragraph 1
    expect(controller.selection.start, p0.length + 1 + 3);
    expect(controller.selection.end, p0.length + 1 + 18);

    // Verify Paragraph 0 is still Center
    expect(getParagraphAlignmentAt(controller, p0Offset), TextAlign.center);
    // Verify Paragraph 2 and 3 are still Left
    expect(getParagraphAlignmentAt(controller, p2Offset), TextAlign.left);
    expect(getParagraphAlignmentAt(controller, p3Offset), TextAlign.left);

    // 4. Select text across multiple paragraphs (Paragraph 2 and Paragraph 3) and apply Justify
    controller.updateSelection(
      TextSelection(
        baseOffset: p2Offset,
        extentOffset: p3Offset + 10,
      ),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.longPress(alignButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_align_justify_option')));
    await tester.pumpAndSettle();

    // Paragraph 2 & 3 are now Justify
    expect(getParagraphAlignmentAt(controller, p2Offset), TextAlign.justify);
    expect(getParagraphAlignmentAt(controller, p3Offset), TextAlign.justify);

    // Unselected Paragraph 0 is STILL Center
    expect(getParagraphAlignmentAt(controller, p0Offset), TextAlign.center);
    // Unselected Paragraph 1 is STILL Right
    expect(getParagraphAlignmentAt(controller, p1Offset), TextAlign.right);

    // 5. Save note and verify each paragraph retains its exact alignment upon reopening
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Note saved successfully!'), findsOneWidget);

    // Reopen note
    await tester.tap(find.text('Calculus Derivatives & Integrals'));
    await tester.pumpAndSettle();

    final reopenedController = getQuillController(tester);
    expect(
      reopenedController.document.toPlainText().trimRight(),
      fullText.trimRight(),
    );

    // Check Paragraph 0 is Center, Paragraph 1 is Right, Paragraph 2 & 3 are Justify
    expect(
      getParagraphAlignmentAt(reopenedController, p0Offset),
      TextAlign.center,
    );
    expect(
      getParagraphAlignmentAt(reopenedController, p1Offset),
      TextAlign.right,
    );
    expect(
      getParagraphAlignmentAt(reopenedController, p2Offset),
      TextAlign.justify,
    );
    expect(
      getParagraphAlignmentAt(reopenedController, p3Offset),
      TextAlign.justify,
    );

    // 6. Change Paragraph 3 to Left alignment only
    reopenedController.updateSelection(
      TextSelection.collapsed(offset: p3Offset),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.longPress(alignButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('format_align_left_option')));
    await tester.pumpAndSettle();

    expect(
      getParagraphAlignmentAt(reopenedController, p3Offset),
      TextAlign.left,
    );
    // Paragraph 2 remains Justify, Paragraph 1 remains Right, Paragraph 0 remains Center
    expect(
      getParagraphAlignmentAt(reopenedController, p2Offset),
      TextAlign.justify,
    );
    expect(
      getParagraphAlignmentAt(reopenedController, p1Offset),
      TextAlign.right,
    );
    expect(
      getParagraphAlignmentAt(reopenedController, p0Offset),
      TextAlign.center,
    );

    // 7. Save and reopen again: verify all retained simultaneously
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Note saved successfully!'), findsOneWidget);

    await tester.tap(find.text('Calculus Derivatives & Integrals'));
    await tester.pumpAndSettle();

    final finalController = getQuillController(tester);
    expect(
      getParagraphAlignmentAt(finalController, p0Offset),
      TextAlign.center,
    );
    expect(
      getParagraphAlignmentAt(finalController, p1Offset),
      TextAlign.right,
    );
    expect(
      getParagraphAlignmentAt(finalController, p2Offset),
      TextAlign.justify,
    );
    expect(
      getParagraphAlignmentAt(finalController, p3Offset),
      TextAlign.left,
    );
  });
}
