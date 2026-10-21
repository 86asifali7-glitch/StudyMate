import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/models/vault_item.dart';
import 'package:studymate/screens/home_screen.dart';
import 'package:studymate/screens/vault_home_screen.dart';
import 'package:studymate/screens/vault_lock_screen.dart';
import 'package:studymate/services/vault_crypto.dart';
import 'package:studymate/services/vault_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir = Directory.systemTemp.createTempSync('studymate_vault_test_');

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
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
    await VaultService.instance.clearAllForTesting();
  });

  tearDown(() {
    try {
      if (fakePathProvider.tempDir.existsSync()) {
        fakePathProvider.tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('VaultCrypto Tests', () {
    test('salt and key generation produces valid entropy', () {
      final salt1 = VaultCrypto.generateRandomSalt();
      final salt2 = VaultCrypto.generateRandomSalt();
      expect(salt1, isNotEmpty);
      expect(salt2, isNotEmpty);
      expect(salt1, isNot(equals(salt2)));

      final key = VaultCrypto.generateMasterKey();
      expect(key.length, 32); // 256 bits
    });

    test('hashPin produces deterministic hash and detects mismatch', () {
      final salt = VaultCrypto.generateRandomSalt();
      final hash1 = VaultCrypto.hashPin('1234', salt);
      final hash2 = VaultCrypto.hashPin('1234', salt);
      final hashWrong = VaultCrypto.hashPin('9999', salt);

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hashWrong)));
    });

    test('AES-256 encryption and decryption round-trip preserves byte identity', () {
      final masterKey = VaultCrypto.generateMasterKey();
      final originalData = Uint8List.fromList(utf8.encode('Top Secret Study Notes 2026!'));

      final encrypted = VaultCrypto.encryptBytes(originalData, masterKey);
      expect(encrypted, isNot(equals(originalData)));
      expect(encrypted.length, greaterThan(originalData.length + 16)); // includes 16-byte IV

      final decrypted = VaultCrypto.decryptBytes(encrypted, masterKey);
      expect(decrypted, equals(originalData));
      expect(utf8.decode(decrypted), 'Top Secret Study Notes 2026!');
    });

    test('decryption with incorrect key throws exception', () {
      final key1 = VaultCrypto.generateMasterKey();
      final key2 = VaultCrypto.generateMasterKey();
      final originalData = Uint8List.fromList(utf8.encode('Confidential Exam Paper'));

      final encrypted = VaultCrypto.encryptBytes(originalData, key1);
      expect(() => VaultCrypto.decryptBytes(encrypted, key2), throwsA(anything));
    });
  });

  group('VaultItem Model Tests', () {
    test('model serialization and deserialization across all categories', () {
      final now = DateTime(2026, 10, 20, 16, 45);

      final itemImage = VaultItem(
        id: '101',
        name: 'Secret Scan',
        category: VaultCategory.image,
        originalFileName: 'exam_scan.png',
        storedFileName: 'vault_101.enc',
        fileSizeBytes: 20480,
        importDate: now,
        isFavorite: true,
      );

      final json = itemImage.toJson();
      expect(json['id'], '101');
      expect(json['category'], 'image');
      expect(json['storedFileName'], 'vault_101.enc');

      final reconstructed = VaultItem.fromJson(json);
      expect(reconstructed.id, '101');
      expect(reconstructed.name, 'Secret Scan');
      expect(reconstructed.category, VaultCategory.image);
      expect(reconstructed.formattedSize, '20.0 KB');
      expect(reconstructed.isFavorite, isTrue);

      final itemVideo = VaultItem(
        id: '102',
        name: 'Lecture Video',
        category: VaultCategory.video,
        originalFileName: 'lecture.mp4',
        storedFileName: 'vault_102.enc',
        fileSizeBytes: 5 * 1024 * 1024,
        importDate: now,
      );
      expect(itemVideo.category, VaultCategory.video);
      expect(itemVideo.formattedSize, '5.0 MB');

      final itemAudio = VaultItem(
        id: '103',
        name: 'Voice Memo',
        category: VaultCategory.audio,
        originalFileName: 'memo.mp3',
        storedFileName: 'vault_103.enc',
        fileSizeBytes: 512,
        importDate: now,
      );
      expect(itemAudio.category, VaultCategory.audio);
      expect(itemAudio.formattedSize, '512 B');

      final itemNote = VaultItem(
        id: '104',
        name: 'Private Formula',
        category: VaultCategory.pdfNotes,
        originalFileName: 'formula.txt',
        storedFileName: 'note_104.enc',
        fileSizeBytes: 120,
        importDate: now,
        isNote: true,
        noteSnippet: 'E = mc^2',
      );
      expect(itemNote.category, VaultCategory.pdfNotes);
      expect(itemNote.isNote, isTrue);
      expect(itemNote.noteSnippet, 'E = mc^2');
    });
  });

  group('VaultService Integration Tests', () {
    test('setup PIN, lock, and unlock flow', () async {
      final service = VaultService.instance;
      expect(service.hasPin, isFalse);
      expect(service.isLocked, isTrue);

      // Setup PIN
      final setupSuccess = await service.setupPin('4321', hint: 'Countdown');
      expect(setupSuccess, isTrue);
      expect(service.hasPin, isTrue);
      expect(service.isLocked, isFalse);
      expect(service.pinHint, 'Countdown');
      expect(service.masterKey, isNotNull);

      // Lock vault
      service.lock();
      expect(service.isLocked, isTrue);
      expect(service.masterKey, isNull);

      // Failed unlock
      final badUnlock = await service.unlock('0000');
      expect(badUnlock, isFalse);
      expect(service.isLocked, isTrue);

      // Successful unlock
      final goodUnlock = await service.unlock('4321');
      expect(goodUnlock, isTrue);
      expect(service.isLocked, isFalse);
      expect(service.masterKey, isNotNull);
    });

    test('importing files encrypts them on disk and decrypts accurately', () async {
      final service = VaultService.instance;
      await service.setupPin('1234');

      final testImageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final item = await service.importFile(
        fileName: 'id_card.png',
        bytes: testImageBytes,
        category: VaultCategory.image,
      );

      expect(item, isNotNull);
      expect(service.items.length, 1);
      expect(service.items.first.category, VaultCategory.image);

      // Verify stored file on disk is encrypted (does not match plain bytes)
      final storedFile = File(item!.localPath!);
      expect(storedFile.existsSync(), isTrue);
      final rawDiskBytes = await storedFile.readAsBytes();
      expect(rawDiskBytes, isNot(equals(testImageBytes)));

      // Decrypt through service
      final decrypted = await service.getDecryptedBytes(item);
      expect(decrypted, equals(testImageBytes));
    });

    test('create secret note encrypts and decrypts text content', () async {
      final service = VaultService.instance;
      await service.setupPin('1234');

      const secretText = 'Secret Exam Room Code: 998877';
      final noteItem = await service.createSecretNote(
        title: 'Exam Code',
        content: secretText,
      );

      expect(noteItem, isNotNull);
      expect(noteItem!.isNote, isTrue);
      expect(noteItem.category, VaultCategory.pdfNotes);

      final decryptedBytes = await service.getDecryptedBytes(noteItem);
      expect(decryptedBytes, isNotNull);
      expect(utf8.decode(decryptedBytes!), secretText);
    });

    test('changing PIN preserves access to existing encrypted items', () async {
      final service = VaultService.instance;
      await service.setupPin('1111');

      final secretDoc = Uint8List.fromList(utf8.encode('Confidential Thesis Draft'));
      final item = await service.importFile(
        fileName: 'thesis.pdf',
        bytes: secretDoc,
        category: VaultCategory.pdfNotes,
      );

      // Change PIN from 1111 to 2222
      final changeOk = await service.changePin(oldPin: '1111', newPin: '2222', hint: 'Four twos');
      expect(changeOk, isTrue);

      // Lock and unlock with new PIN
      service.lock();
      final unlockNew = await service.unlock('2222');
      expect(unlockNew, isTrue);

      // Existing item decrypts successfully with new PIN
      final decrypted = await service.getDecryptedBytes(item!);
      expect(utf8.decode(decrypted!), 'Confidential Thesis Draft');
    });

    test('delete item removes file from disk and metadata', () async {
      final service = VaultService.instance;
      await service.setupPin('1234');

      final item = await service.importFile(
        fileName: 'temp.mp3',
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        category: VaultCategory.audio,
      );

      expect(service.items.length, 1);
      final filePath = item!.localPath!;
      expect(File(filePath).existsSync(), isTrue);

      final deleteOk = await service.deleteItem(item.id);
      expect(deleteOk, isTrue);
      expect(service.items.isEmpty, isTrue);
      expect(File(filePath).existsSync(), isFalse);
    });

    test('resetVault securely wipes all items, files, and PIN', () async {
      final service = VaultService.instance;
      await service.setupPin('1234');
      await service.createSecretNote(title: 'Note 1', content: 'Secret 1');

      expect(service.hasPin, isTrue);
      expect(service.items.length, 1);

      await service.resetVault();
      expect(service.hasPin, isFalse);
      expect(service.isLocked, isTrue);
      expect(service.items.isEmpty, isTrue);
    });
  });

  group('Vault UI Widget Tests', () {
    testWidgets('HomeScreen displays Personal Vault shortcut and navigates to VaultLockScreen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to Quick Access
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Check Personal Vault card exists
      expect(find.text('Personal Vault'), findsWidgets);
      expect(find.text('Encrypted media, files & secret notes'), findsOneWidget);

      // Tap on Personal Vault card
      await tester.tap(find.text('Personal Vault').first);
      await tester.pumpAndSettle();

      // Arrives on VaultLockScreen in setup mode
      expect(find.byType(VaultLockScreen), findsOneWidget);
      expect(find.text('Set Up Vault PIN'), findsOneWidget);
    });

    testWidgets('VaultLockScreen setup PIN flow unlocks and opens VaultHomeScreen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VaultLockScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set Up Vault PIN'), findsOneWidget);

      // Enter 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // Prompts to confirm
      expect(find.text('Confirm Vault PIN'), findsOneWidget);

      // Confirm with 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // Security hint dialog appears -> tap Skip
      expect(find.text('Security Hint'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Successfully arrives at VaultHomeScreen
      expect(find.byType(VaultHomeScreen), findsOneWidget);
      expect(find.text('Personal Vault'), findsOneWidget);
      expect(find.text('AES-256'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('PDFs & Notes'), findsOneWidget);

      // Verify FAB dynamically changes label according to active tab
      // Tab 0 (Images) -> "Add Image"
      expect(find.text('Add Image'), findsWidgets);

      // Switch to Tab 1 (Videos) -> FAB changes to "Add Video"
      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();
      expect(find.text('Add Video'), findsWidgets);

      // Switch to Tab 2 (Audio) -> FAB changes to "Add Music"
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      expect(find.text('Add Music'), findsWidgets);

      // Switch to Tab 3 (PDFs & Notes) -> FAB changes to "Add PDF / Note"
      await tester.tap(find.text('PDFs & Notes'));
      await tester.pumpAndSettle();
      expect(find.text('Add PDF / Note'), findsWidgets);
    });
  });
}
