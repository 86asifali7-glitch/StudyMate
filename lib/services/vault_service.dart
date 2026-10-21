import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vault_item.dart';
import 'vault_crypto.dart';

class VaultService extends ChangeNotifier {
  VaultService._internal();
  static final VaultService instance = VaultService._internal();

  static const String _kPrefSalt = 'studymate_vault_salt';
  static const String _kPrefPinHash = 'studymate_vault_pin_hash';
  static const String _kPrefEncMasterKey = 'studymate_vault_enc_master_key';
  static const String _kPrefHint = 'studymate_vault_hint';
  static const String _kPrefItems = 'studymate_vault_items_meta';
  static const String _kVaultDirName = 'study_mate_vault';
  static const String _kTmpDirName = 'study_mate_vault_tmp';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _hasPin = false;
  bool get hasPin => _hasPin;

  bool _isLocked = true;
  bool get isLocked => _isLocked;

  String? _pinHint;
  String? get pinHint => _pinHint;

  Uint8List? _masterKey;
  Uint8List? get masterKey => _masterKey;

  List<VaultItem> _items = [];
  List<VaultItem> get items => List.unmodifiable(_items);

  final List<String> _tempFilesCreated = [];

  Future<void> initialize() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    final pinHash = prefs.getString(_kPrefPinHash);
    _hasPin = pinHash != null && pinHash.isNotEmpty;
    _pinHint = prefs.getString(_kPrefHint);

    final rawItems = prefs.getString(_kPrefItems);
    if (rawItems != null && rawItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems) as List<dynamic>;
        _items = decoded
            .map((e) => VaultItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error decoding vault items: $e');
        _items = [];
      }
    } else {
      _items = [];
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Setup initial PIN/Password and generate new Master Vault Key
  Future<bool> setupPin(String pin, {String? hint}) async {
    if (pin.length < 4) return false;
    final prefs = await SharedPreferences.getInstance();

    final salt = VaultCrypto.generateRandomSalt();
    final pinHash = VaultCrypto.hashPin(pin, salt);
    final kek = VaultCrypto.deriveKey(pin, salt);

    // Generate random 256-bit Master Vault Key
    final mvk = VaultCrypto.generateMasterKey();
    final encMvk = VaultCrypto.encryptBytes(mvk, kek);

    await prefs.setString(_kPrefSalt, salt);
    await prefs.setString(_kPrefPinHash, pinHash);
    await prefs.setString(_kPrefEncMasterKey, base64Encode(encMvk));
    if (hint != null && hint.trim().isNotEmpty) {
      await prefs.setString(_kPrefHint, hint.trim());
      _pinHint = hint.trim();
    } else {
      await prefs.remove(_kPrefHint);
      _pinHint = null;
    }

    _masterKey = mvk;
    _hasPin = true;
    _isLocked = false;
    notifyListeners();
    return true;
  }

  /// Unlock the vault using user's PIN/Password
  Future<bool> unlock(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_kPrefSalt);
    final pinHash = prefs.getString(_kPrefPinHash);
    final rawEncMvk = prefs.getString(_kPrefEncMasterKey);

    if (salt == null || pinHash == null || rawEncMvk == null) {
      return false;
    }

    final computedHash = VaultCrypto.hashPin(pin, salt);
    if (computedHash != pinHash) {
      return false;
    }

    try {
      final kek = VaultCrypto.deriveKey(pin, salt);
      final encMvk = base64Decode(rawEncMvk);
      final decryptedMvk = VaultCrypto.decryptBytes(encMvk, kek);

      _masterKey = decryptedMvk;
      _isLocked = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to decrypt master vault key: $e');
      return false;
    }
  }

  /// Lock vault immediately and clean up decrypted in-memory master key & temp preview files
  void lock() {
    _masterKey = null;
    _isLocked = true;
    _cleanupTempFiles();
    notifyListeners();
  }

  /// Change PIN safely by re-wrapping only the Master Vault Key
  Future<bool> changePin({
    required String oldPin,
    required String newPin,
    String? hint,
  }) async {
    if (newPin.length < 4) return false;
    if (_masterKey == null) {
      // Must be unlocked to change PIN
      final ok = await unlock(oldPin);
      if (!ok) return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final newSalt = VaultCrypto.generateRandomSalt();
    final newPinHash = VaultCrypto.hashPin(newPin, newSalt);
    final newKek = VaultCrypto.deriveKey(newPin, newSalt);

    final encMvk = VaultCrypto.encryptBytes(_masterKey!, newKek);

    await prefs.setString(_kPrefSalt, newSalt);
    await prefs.setString(_kPrefPinHash, newPinHash);
    await prefs.setString(_kPrefEncMasterKey, base64Encode(encMvk));

    if (hint != null && hint.trim().isNotEmpty) {
      await prefs.setString(_kPrefHint, hint.trim());
      _pinHint = hint.trim();
    }

    notifyListeners();
    return true;
  }

  /// Reset the vault (emergency wipe of all encrypted files and PIN)
  Future<void> resetVault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefSalt);
    await prefs.remove(_kPrefPinHash);
    await prefs.remove(_kPrefEncMasterKey);
    await prefs.remove(_kPrefHint);
    await prefs.remove(_kPrefItems);

    // Delete vault files from disk
    if (!kIsWeb) {
      try {
        final vaultDir = await _getVaultDirectory();
        if (vaultDir.existsSync()) {
          vaultDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    }

    _cleanupTempFiles();
    _masterKey = null;
    _items = [];
    _hasPin = false;
    _isLocked = true;
    _pinHint = null;
    notifyListeners();
  }

  /// Resolve dedicated internal directory for encrypted files
  Future<Directory> _getVaultDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(docsDir.path, _kVaultDirName));
    if (!vaultDir.existsSync()) {
      vaultDir.createSync(recursive: true);
    }
    return vaultDir;
  }

  /// Resolve temporary directory for secure previewing
  Future<Directory> _getTmpDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final tmpDir = Directory(p.join(cacheDir.path, _kTmpDirName));
    if (!tmpDir.existsSync()) {
      tmpDir.createSync(recursive: true);
    }
    return tmpDir;
  }

  void _cleanupTempFiles() {
    if (kIsWeb) return;
    for (final path in _tempFilesCreated) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    _tempFilesCreated.clear();
  }

  Future<void> _saveMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _items.map((e) => e.toJson()).toList();
    await prefs.setString(_kPrefItems, jsonEncode(jsonList));
  }

  /// Import and encrypt a file into the personal vault
  Future<VaultItem?> importFile({
    required String fileName,
    required Uint8List bytes,
    required VaultCategory category,
    String? customName,
  }) async {
    if (_masterKey == null || _isLocked) {
      throw StateError('Vault is locked. Unlock before importing.');
    }
    if (bytes.isEmpty) return null;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final storedFileName = 'vault_$id.enc';

    // Encrypt bytes with Master Vault Key
    final encryptedData = VaultCrypto.encryptBytes(bytes, _masterKey!);

    String? localPath;
    if (!kIsWeb) {
      final dir = await _getVaultDirectory();
      final targetFile = File(p.join(dir.path, storedFileName));
      await targetFile.writeAsBytes(encryptedData, flush: true);
      localPath = targetFile.path;
    }

    // Default display name
    String displayName = customName?.trim() ?? '';
    if (displayName.isEmpty) {
      displayName = p.basenameWithoutExtension(fileName).replaceAll('_', ' ');
    }

    final item = VaultItem(
      id: id,
      name: displayName,
      category: category,
      originalFileName: fileName,
      storedFileName: storedFileName,
      fileSizeBytes: bytes.length,
      importDate: DateTime.now(),
      localPath: localPath,
      webDataKey: kIsWeb ? 'vault_item_$id' : null,
    );

    _items.insert(0, item);
    await _saveMetadata();
    notifyListeners();
    return item;
  }

  /// Create a secret encrypted text note in the vault
  Future<VaultItem?> createSecretNote({
    required String title,
    required String content,
  }) async {
    if (_masterKey == null || _isLocked) {
      throw StateError('Vault is locked. Unlock before creating note.');
    }
    final noteBytes = Uint8List.fromList(utf8.encode(content));
    final snippet = content.length > 80 ? '${content.substring(0, 80)}...' : content;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final storedFileName = 'note_$id.enc';

    final encryptedData = VaultCrypto.encryptBytes(noteBytes, _masterKey!);

    String? localPath;
    if (!kIsWeb) {
      final dir = await _getVaultDirectory();
      final targetFile = File(p.join(dir.path, storedFileName));
      await targetFile.writeAsBytes(encryptedData, flush: true);
      localPath = targetFile.path;
    }

    final item = VaultItem(
      id: id,
      name: title.trim().isEmpty ? 'Secret Note' : title.trim(),
      category: VaultCategory.pdfNotes,
      originalFileName: '${title.replaceAll(' ', '_')}.txt',
      storedFileName: storedFileName,
      fileSizeBytes: noteBytes.length,
      importDate: DateTime.now(),
      localPath: localPath,
      isNote: true,
      noteSnippet: snippet,
      webDataKey: kIsWeb ? 'vault_item_$id' : null,
    );

    _items.insert(0, item);
    await _saveMetadata();
    notifyListeners();
    return item;
  }

  /// Decrypt and retrieve bytes for a vault item
  Future<Uint8List?> getDecryptedBytes(VaultItem item) async {
    if (_masterKey == null || _isLocked) {
      throw StateError('Vault is locked. Unlock to decrypt items.');
    }

    Uint8List? cipherBytes;
    if (!kIsWeb && item.localPath != null) {
      final file = File(item.localPath!);
      if (!file.existsSync()) {
        // Fallback: check vault directory
        final dir = await _getVaultDirectory();
        final alt = File(p.join(dir.path, item.storedFileName));
        if (alt.existsSync()) {
          cipherBytes = await alt.readAsBytes();
        } else {
          return null;
        }
      } else {
        cipherBytes = await file.readAsBytes();
      }
    }

    if (cipherBytes == null || cipherBytes.isEmpty) {
      return null;
    }

    return VaultCrypto.decryptBytes(cipherBytes, _masterKey!);
  }

  /// Prepare a decrypted temporary file for native playback/viewing (e.g. video, PDF)
  Future<String?> prepareTempFileForOpening(VaultItem item) async {
    final bytes = await getDecryptedBytes(item);
    if (bytes == null) return null;

    final tmpDir = await _getTmpDirectory();
    String safeOriginalName = item.originalFileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
    if (p.extension(safeOriginalName).isEmpty) {
      switch (item.category) {
        case VaultCategory.image:
          safeOriginalName += '.jpg';
          break;
        case VaultCategory.video:
          safeOriginalName += '.mp4';
          break;
        case VaultCategory.audio:
          safeOriginalName += '.mp3';
          break;
        case VaultCategory.pdfNotes:
          safeOriginalName += item.isNote ? '.txt' : '.pdf';
          break;
      }
    }

    final tmpPath = p.join(tmpDir.path, '${item.id}_$safeOriginalName');
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsBytes(bytes, flush: true);

    if (!_tempFilesCreated.contains(tmpPath)) {
      _tempFilesCreated.add(tmpPath);
    }
    return tmpPath;
  }

  /// Delete item from vault and remove encrypted payload from disk
  Future<bool> deleteItem(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return false;

    final item = _items[index];
    if (!kIsWeb && item.localPath != null) {
      try {
        final f = File(item.localPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }

    _items.removeAt(index);
    await _saveMetadata();
    notifyListeners();
    return true;
  }

  /// Rename display name of vault item
  Future<bool> renameItem(String id, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return false;

    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return false;

    _items[index] = _items[index].copyWith(name: clean);
    await _saveMetadata();
    notifyListeners();
    return true;
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;

    _items[index] = _items[index].copyWith(isFavorite: !_items[index].isFavorite);
    await _saveMetadata();
    notifyListeners();
  }

  /// Get list of items filtered by category
  List<VaultItem> getItemsByCategory(VaultCategory cat) {
    return _items.where((e) => e.category == cat).toList();
  }

  @visibleForTesting
  Future<void> clearAllForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefSalt);
    await prefs.remove(_kPrefPinHash);
    await prefs.remove(_kPrefEncMasterKey);
    await prefs.remove(_kPrefHint);
    await prefs.remove(_kPrefItems);
    _cleanupTempFiles();
    _masterKey = null;
    _items = [];
    _hasPin = false;
    _isLocked = true;
    _pinHint = null;
    _isInitialized = false;
  }
}
