import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/models/pdf_document.dart';
import 'package:studymate/screens/home_screen.dart';
import 'package:studymate/screens/pdf_library_screen.dart';
import 'package:studymate/services/pdf_storage_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir = Directory.systemTemp.createTempSync('studymate_pdf_test_');

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePathProviderPlatform fakePathProvider;

  setUp(() async {
    fakePathProvider = FakePathProviderPlatform();
    PathProviderPlatform.instance = fakePathProvider;
    SharedPreferences.setMockInitialValues({});
    await PdfStorageService.instance.clearAllForTesting();
  });

  tearDown(() {
    try {
      if (fakePathProvider.tempDir.existsSync()) {
        fakePathProvider.tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('PdfDocument Model Tests', () {
    test('serialization to and from JSON', () {
      final now = DateTime(2026, 10, 20, 14, 30);
      final doc = PdfDocument(
        id: '12345',
        name: 'Calculus Notes',
        originalFileName: 'calculus_notes.pdf',
        fileSizeBytes: 2048,
        importDate: now,
        isFavorite: true,
        localPath: '/storage/12345.pdf',
        webDataKey: 'studymate_pdf_file_12345',
      );

      final json = doc.toJson();
      expect(json['id'], '12345');
      expect(json['name'], 'Calculus Notes');
      expect(json['originalFileName'], 'calculus_notes.pdf');
      expect(json['storedFileName'], '12345.pdf');
      expect(json['fileSizeBytes'], 2048);
      expect(json['isFavorite'], true);
      expect(json['localPath'], '/storage/12345.pdf');
      expect(json['webDataKey'], 'studymate_pdf_file_12345');

      final reconstructed = PdfDocument.fromJson(json);
      expect(reconstructed.id, doc.id);
      expect(reconstructed.name, doc.name);
      expect(reconstructed.originalFileName, doc.originalFileName);
      expect(reconstructed.storedFileName, '12345.pdf');
      expect(reconstructed.fileSizeBytes, doc.fileSizeBytes);
      expect(reconstructed.isFavorite, doc.isFavorite);
      expect(reconstructed.localPath, doc.localPath);
      expect(reconstructed.webDataKey, doc.webDataKey);
    });

    test('backward compatibility: fromJson defaults storedFileName when missing', () {
      final oldJson = {
        'id': 'legacy_99',
        'name': 'Old Doc',
        'originalFileName': 'old.pdf',
        'fileSizeBytes': 1024,
        'importDate': DateTime(2025, 1, 1).toIso8601String(),
        'isFavorite': false,
      };

      final doc = PdfDocument.fromJson(oldJson);
      expect(doc.id, 'legacy_99');
      expect(doc.storedFileName, 'legacy_99.pdf');
    });

    test('formattedFileSize handles bytes, KB, and MB', () {
      final docB = PdfDocument(
        id: '1',
        name: 'Small',
        originalFileName: 'small.pdf',
        fileSizeBytes: 512,
        importDate: DateTime.now(),
      );
      expect(docB.formattedSize, '512 B');

      final docKB = PdfDocument(
        id: '2',
        name: 'Medium',
        originalFileName: 'medium.pdf',
        fileSizeBytes: 15360, // 15 KB
        importDate: DateTime.now(),
      );
      expect(docKB.formattedSize, '15.0 KB');

      final docMB = PdfDocument(
        id: '3',
        name: 'Large',
        originalFileName: 'large.pdf',
        fileSizeBytes: 2 * 1024 * 1024 + 512 * 1024, // 2.5 MB
        importDate: DateTime.now(),
      );
      expect(docMB.formattedSize, '2.5 MB');
    });

    test('copyWith properly updates selected fields', () {
      final doc = PdfDocument(
        id: '1',
        name: 'Physics',
        originalFileName: 'physics.pdf',
        fileSizeBytes: 1000,
        importDate: DateTime.now(),
        isFavorite: false,
      );

      final updated = doc.copyWith(name: 'Advanced Physics', isFavorite: true);
      expect(updated.name, 'Advanced Physics');
      expect(updated.isFavorite, true);
      expect(updated.id, doc.id);
      expect(updated.fileSizeBytes, doc.fileSizeBytes);
    });
  });

  group('PdfStorageService Unit Tests', () {
    final validPdfBytes = Uint8List.fromList([
      0x25, 0x50, 0x44, 0x46, // %PDF
      0x2D, 0x31, 0x2E, 0x35, // -1.5
      0x0A, 0x25, 0xE2, 0xE3,
    ]);

    test('isValidPdf checks extension and magic header', () {
      final service = PdfStorageService.instance;

      expect(service.isValidPdf('lecture.pdf', validPdfBytes), isTrue);
      expect(service.isValidPdf('LECTURE.PDF', validPdfBytes), isTrue);
      expect(service.isValidPdf('lecture.txt', validPdfBytes), isFalse);

      final invalidBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header
      expect(service.isValidPdf('lecture.pdf', invalidBytes), isFalse);
    });

    test('importPdf stores PDF and creates document metadata', () async {
      final service = PdfStorageService.instance;

      final result = await service.importPdf(
        fileName: 'Biology_101.pdf',
        bytes: validPdfBytes,
      );

      expect(result.isSuccess, isTrue);
      expect(result.document, isNotNull);
      expect(result.document!.name, 'Biology 101');
      expect(result.document!.originalFileName, 'Biology_101.pdf');
      expect(service.pdfs.length, 1);
      expect(service.pdfs.first.fileSizeBytes, validPdfBytes.length);

      // Verify file was written to disk
      expect(await service.verifyFileExists(result.document!), isTrue);
    });

    test('importPdf prevents duplicate imports unless explicitly allowed', () async {
      final service = PdfStorageService.instance;

      final res1 = await service.importPdf(
        fileName: 'Notes.pdf',
        bytes: validPdfBytes,
      );
      expect(res1.isSuccess, isTrue);

      // Attempt duplicate import
      final res2 = await service.importPdf(
        fileName: 'notes.pdf',
        bytes: validPdfBytes,
      );
      expect(res2.isSuccess, isFalse);
      expect(res2.isDuplicate, isTrue);
      expect(service.pdfs.length, 1);

      // Allow duplicate
      final res3 = await service.importPdf(
        fileName: 'notes.pdf',
        bytes: validPdfBytes,
        allowDuplicate: true,
      );
      expect(res3.isSuccess, isTrue);
      expect(service.pdfs.length, 2);
    });

    test('importPdf rejects empty or invalid bytes', () async {
      final service = PdfStorageService.instance;

      final emptyRes = await service.importPdf(
        fileName: 'empty.pdf',
        bytes: Uint8List(0),
      );
      expect(emptyRes.isSuccess, isFalse);
      expect(emptyRes.error, contains('Empty document'));

      final invalidRes = await service.importPdf(
        fileName: 'bad.pdf',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(invalidRes.isSuccess, isFalse);
      expect(invalidRes.error, contains('not a valid PDF'));
    });

    test('renamePdf updates document display name', () async {
      final service = PdfStorageService.instance;
      final res = await service.importPdf(
        fileName: 'chem_lab.pdf',
        bytes: validPdfBytes,
      );
      final id = res.document!.id;

      final success = await service.renamePdf(id, 'Chemistry Lab Report');
      expect(success, isTrue);
      expect(service.pdfs.first.name, 'Chemistry Lab Report');

      // Empty name is rejected
      final failed = await service.renamePdf(id, '   ');
      expect(failed, isFalse);
      expect(service.pdfs.first.name, 'Chemistry Lab Report');
    });

    test('toggleFavorite toggles favorite status and persists it', () async {
      final service = PdfStorageService.instance;
      final res = await service.importPdf(
        fileName: 'history.pdf',
        bytes: validPdfBytes,
      );
      final id = res.document!.id;
      expect(service.pdfs.first.isFavorite, isFalse);

      await service.toggleFavorite(id);
      expect(service.pdfs.first.isFavorite, isTrue);

      await service.toggleFavorite(id);
      expect(service.pdfs.first.isFavorite, isFalse);
    });

    test('deletePdf removes document and deletes stored file', () async {
      final service = PdfStorageService.instance;
      final res = await service.importPdf(
        fileName: 'delete_me.pdf',
        bytes: validPdfBytes,
      );
      final doc = res.document!;
      expect(service.pdfs.length, 1);
      expect(await service.verifyFileExists(doc), isTrue);

      final success = await service.deletePdf(doc.id);
      expect(success, isTrue);
      expect(service.pdfs.isEmpty, isTrue);
      expect(await service.verifyFileExists(doc), isFalse);
    });

    test('imported PDF is saved in study_mate_pdfs with unique safe storedFileName', () async {
      final service = PdfStorageService.instance;
      final res = await service.importPdf(
        fileName: 'Lecture 1: Intro @ 2026!.pdf',
        bytes: validPdfBytes,
      );
      expect(res.isSuccess, isTrue);
      final doc = res.document!;
      expect(doc.localPath, isNotNull);
      expect(doc.localPath, contains('study_mate_pdfs'));
      expect(doc.storedFileName, contains('Lecture_1__Intro___2026_.pdf'));
      expect(File(doc.localPath!).existsSync(), isTrue);
    });

    test('persists metadata across app restarts (re-initializing service)', () async {
      final service = PdfStorageService.instance;
      final res = await service.importPdf(
        fileName: 'persistent_doc.pdf',
        bytes: validPdfBytes,
      );
      expect(res.isSuccess, isTrue);
      final savedId = res.document!.id;
      await service.toggleFavorite(savedId);

      // Simulate app restart by re-initializing service
      await service.initialize(forceReload: true);
      expect(service.pdfs.length, 1);
      final reloaded = service.pdfs.first;
      expect(reloaded.id, savedId);
      expect(reloaded.isFavorite, isTrue);
      expect(reloaded.originalFileName, 'persistent_doc.pdf');
      expect(await service.verifyFileExists(reloaded), isTrue);
    });

    test('openPdfDocument gracefully handles missing file', () async {
      final service = PdfStorageService.instance;
      final missingDoc = PdfDocument(
        id: 'missing_123',
        name: 'Missing',
        originalFileName: 'missing.pdf',
        storedFileName: 'missing_123.pdf',
        fileSizeBytes: 100,
        importDate: DateTime.now(),
        localPath: '/non/existent/path/missing_123.pdf',
      );

      final openRes = await service.openPdfDocument(missingDoc);
      expect(openRes.isSuccess, isFalse);
      expect(openRes.message, contains('not found'));
    });
  });

  group('HomeScreen and PdfLibraryScreen Widget Tests', () {
    testWidgets('HomeScreen displays My PDFs shortcut and navigates to PdfLibraryScreen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down so Quick Access My PDFs card is in view
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Check "My PDFs" shortcut card exists on Home
      expect(find.text('My PDFs'), findsWidgets);
      expect(find.text('Personal study documents library'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsWidgets);

      // Tap on "My PDFs" card
      await tester.tap(find.text('Personal study documents library'));
      await tester.pumpAndSettle();

      // Verify we arrived on PdfLibraryScreen
      expect(find.byType(PdfLibraryScreen), findsOneWidget);
      expect(find.text('Import PDF'), findsOneWidget);
      expect(find.text('Your PDF Library is Empty'), findsOneWidget);
    });

    testWidgets('PdfLibraryScreen shows search bar, filter tabs, and imported documents',
        (tester) async {
      final validPdfBytes = Uint8List.fromList([
        0x25, 0x50, 0x44, 0x46,
        0x2D, 0x31, 0x2E, 0x35,
        0x0A, 0x25,
      ]);

      await tester.runAsync(() async {
        final service = PdfStorageService.instance;
        final doc1Res = await service.importPdf(fileName: 'math_notes.pdf', bytes: validPdfBytes);
        await service.importPdf(fileName: 'english_essay.pdf', bytes: validPdfBytes);
        await service.toggleFavorite(doc1Res.document!.id);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PdfLibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check both documents appear
      expect(find.text('math notes'), findsOneWidget);
      expect(find.text('english essay'), findsOneWidget);

      // Test Search query filtering
      await tester.enterText(find.byType(TextField), 'math');
      await tester.pump();

      expect(find.text('math notes'), findsOneWidget);
      expect(find.text('english essay'), findsNothing);

      // Clear search and unfocus
      await tester.enterText(find.byType(TextField), '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('math notes'), findsOneWidget);
      expect(find.text('english essay'), findsOneWidget);

      // Test Favorites filter chip
      await tester.tap(find.text('Favorites (1)'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('math notes'), findsOneWidget);
      expect(find.text('english essay'), findsNothing);

      // Switch back to All
      await tester.tap(find.text('All Documents (2)'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('math notes'), findsOneWidget);
      expect(find.text('english essay'), findsOneWidget);
    });
  });
}
