import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_document.dart';
import 'pdf_web_storage.dart';

class PdfStorageResult {
  final PdfDocument? document;
  final String? error;
  final bool isDuplicate;

  const PdfStorageResult.success(this.document)
      : error = null,
        isDuplicate = false;

  const PdfStorageResult.error(this.error)
      : document = null,
        isDuplicate = false;

  const PdfStorageResult.duplicate(this.document)
      : error = 'A PDF with this name and size is already in your library.',
        isDuplicate = true;

  bool get isSuccess => document != null && error == null;
}

class PdfOpenResult {
  final bool isSuccess;
  final String message;

  const PdfOpenResult.success([this.message = 'Document opened.'])
      : isSuccess = true;

  const PdfOpenResult.error(this.message) : isSuccess = false;
}

class PdfStorageService extends ChangeNotifier {
  PdfStorageService._internal();
  static final PdfStorageService instance = PdfStorageService._internal();

  static const String kPdfMetadataKey = 'studymate_saved_pdfs_meta';
  static const String kPdfWebPrefix = 'studymate_pdf_file_';
  static const String kPdfSubdir = 'study_mate_pdfs';
  static const String kPdfLegacySubdir = 'studymate_pdfs';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isProcessingLock = false;
  bool get isProcessing => _isProcessingLock;

  List<PdfDocument> _pdfs = [];
  List<PdfDocument> get pdfs => List.unmodifiable(_pdfs);

  Future<void> initialize({bool forceReload = false}) async {
    if (_isInitialized && !forceReload) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kPdfMetadataKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _pdfs = decoded
            .map((e) => PdfDocument.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading PDF metadata: $e');
        _pdfs = [];
      }
    } else {
      _pdfs = [];
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _pdfs.map((e) => e.toJson()).toList();
    await prefs.setString(kPdfMetadataKey, jsonEncode(jsonList));
    notifyListeners();
  }

  /// Validates whether the byte buffer or filename represents a valid PDF
  bool isValidPdf(String fileName, Uint8List? bytes) {
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      return false;
    }
    if (bytes != null && bytes.length >= 4) {
      // Check magic header %PDF (0x25, 0x50, 0x44, 0x46)
      return bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;
    }
    return true;
  }

  String _generateSafeStoredFileName(String originalName, String id) {
    var sanitized = originalName.trim().replaceAll(RegExp(r'[^\w\.\-]'), '_');
    if (sanitized.toLowerCase().endsWith('.pdf')) {
      sanitized = sanitized.substring(0, sanitized.length - 4);
    }
    if (sanitized.isEmpty) {
      sanitized = 'document';
    }
    return '${id}_$sanitized.pdf';
  }

  /// Imports a PDF file and copies it into persistent app-managed storage.
  /// Uses a mutex lock to prevent concurrent imports from corrupting storage.
  Future<PdfStorageResult> importPdf({
    required String fileName,
    required Uint8List bytes,
    bool allowDuplicate = false,
  }) async {
    if (_isProcessingLock) {
      return const PdfStorageResult.error(
        'Another import is currently in progress. Please wait a moment.',
      );
    }

    _isProcessingLock = true;
    try {
      await initialize();

      // 1. Validation
      if (!isValidPdf(fileName, bytes)) {
        return const PdfStorageResult.error(
          'Invalid document: Selected file is not a valid PDF.',
        );
      }

      if (bytes.isEmpty) {
        return const PdfStorageResult.error(
          'Empty document: Selected file has 0 bytes.',
        );
      }

      // 2. Duplicate check
      final existingIndex = _pdfs.indexWhere(
        (p) =>
            p.originalFileName.toLowerCase() == fileName.toLowerCase() &&
            p.fileSizeBytes == bytes.length,
      );

      if (existingIndex != -1 && !allowDuplicate) {
        return PdfStorageResult.duplicate(_pdfs[existingIndex]);
      }

      final id = '${DateTime.now().microsecondsSinceEpoch}_${_pdfs.length}';
      final displayName = _generateDisplayName(fileName);
      final storedFileName = _generateSafeStoredFileName(fileName, id);

      String? localPath;
      String? webKey;

      if (kIsWeb) {
        // Web storage: Store in browser IndexedDB for unlimited, persistent local storage
        webKey = '$kPdfWebPrefix$id';
        final saved = await pdfWebStorage.savePdf(webKey, bytes);
        if (!saved) {
          // Fallback to SharedPreferences if IndexedDB is blocked
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(webKey, base64Encode(bytes));
          } catch (e) {
            return PdfStorageResult.error(
              'Failed to persist PDF in browser storage: $e',
            );
          }
        }
      } else {
        // Android / Desktop / IO: Store inside internal files directory under study_mate_pdfs/
        final appDocDir = await getApplicationDocumentsDirectory();
        final pdfDir = io.Directory('${appDocDir.path}/$kPdfSubdir');
        if (!await pdfDir.exists()) {
          await pdfDir.create(recursive: true);
        }
        final destFile = io.File('${pdfDir.path}/$storedFileName');
        await destFile.writeAsBytes(bytes, flush: true);
        localPath = destFile.path;
      }

      final doc = PdfDocument(
        id: id,
        name: displayName,
        originalFileName: fileName,
        storedFileName: storedFileName,
        fileSizeBytes: bytes.length,
        importDate: DateTime.now(),
        localPath: localPath,
        webDataKey: webKey,
      );

      _pdfs.insert(0, doc);
      await _saveMetadata();
      return PdfStorageResult.success(doc);
    } catch (e) {
      debugPrint('Error importing PDF: $e');
      return PdfStorageResult.error('Failed to import PDF: $e');
    } finally {
      _isProcessingLock = false;
    }
  }

  String _generateDisplayName(String fileName) {
    var name = fileName;
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4);
    }
    return name.replaceAll('_', ' ').trim();
  }

  Future<bool> renamePdf(String id, String newName) async {
    await initialize();
    final index = _pdfs.indexWhere((p) => p.id == id);
    if (index == -1 || newName.trim().isEmpty) return false;

    _pdfs[index] = _pdfs[index].copyWith(name: newName.trim());
    await _saveMetadata();
    return true;
  }

  Future<bool> toggleFavorite(String id) async {
    await initialize();
    final index = _pdfs.indexWhere((p) => p.id == id);
    if (index == -1) return false;

    _pdfs[index] = _pdfs[index].copyWith(isFavorite: !_pdfs[index].isFavorite);
    await _saveMetadata();
    return true;
  }

  Future<bool> deletePdf(String id) async {
    await initialize();
    final index = _pdfs.indexWhere((p) => p.id == id);
    if (index == -1) return false;

    final doc = _pdfs[index];

    try {
      if (kIsWeb) {
        if (doc.webDataKey != null) {
          await pdfWebStorage.deletePdf(doc.webDataKey!);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(doc.webDataKey!);
        }
      } else {
        if (doc.localPath != null) {
          final file = io.File(doc.localPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting PDF file content: $e');
    }

    _pdfs.removeAt(index);
    await _saveMetadata();
    return true;
  }

  Future<bool> verifyFileExists(PdfDocument doc) async {
    try {
      if (kIsWeb) {
        if (doc.webDataKey == null) return false;
        final hasInIdb = await pdfWebStorage.hasPdf(doc.webDataKey!);
        if (hasInIdb) return true;
        final prefs = await SharedPreferences.getInstance();
        return prefs.containsKey(doc.webDataKey!);
      } else {
        if (doc.localPath == null) return false;
        final file = io.File(doc.localPath!);
        return await file.exists();
      }
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> getPdfBytes(PdfDocument doc) async {
    try {
      if (kIsWeb) {
        if (doc.webDataKey == null) return null;
        final bytesFromIdb = await pdfWebStorage.getPdf(doc.webDataKey!);
        if (bytesFromIdb != null && bytesFromIdb.isNotEmpty) {
          return bytesFromIdb;
        }
        // Fallback to legacy SharedPreferences if existing
        final prefs = await SharedPreferences.getInstance();
        final rawBase64 = prefs.getString(doc.webDataKey!);
        if (rawBase64 != null) {
          final decoded = base64Decode(rawBase64);
          // Auto-migrate to IndexedDB for performance
          await pdfWebStorage.savePdf(doc.webDataKey!, decoded);
          return decoded;
        }
        return null;
      } else {
        if (doc.localPath == null) return null;
        final file = io.File(doc.localPath!);
        if (!await file.exists()) return null;
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error reading PDF bytes: $e');
      return null;
    }
  }

  /// Opens the PDF document cross-platform:
  /// - On Web: Creates a Blob URL and opens it in a new browser tab/viewer.
  /// - On Android / Desktop / iOS: Opens with default system viewer via OpenFilex with FileProvider support.
  Future<PdfOpenResult> openPdfDocument(PdfDocument doc) async {
    final exists = await verifyFileExists(doc);
    if (!exists) {
      return const PdfOpenResult.error(
        'Document file not found in storage. The file may have been moved or deleted.',
      );
    }

    try {
      if (kIsWeb) {
        final bytes = await getPdfBytes(doc);
        if (bytes == null || bytes.isEmpty) {
          return const PdfOpenResult.error(
            'Failed to read document bytes from browser storage.',
          );
        }
        pdfWebStorage.openPdf(bytes, doc.originalFileName);
        return const PdfOpenResult.success('Document opened in browser.');
      } else {
        if (doc.localPath == null || doc.localPath!.isEmpty) {
          return const PdfOpenResult.error('Local file path is missing.');
        }

        final result = await OpenFilex.open(doc.localPath!);
        if (result.type == ResultType.done) {
          return const PdfOpenResult.success('Document opened.');
        } else if (result.type == ResultType.noAppToOpen) {
          return const PdfOpenResult.error(
            'No app available to open PDF files. Please install a PDF viewer app.',
          );
        } else if (result.type == ResultType.fileNotFound) {
          return const PdfOpenResult.error('Saved PDF file not found on device.');
        } else if (result.type == ResultType.permissionDenied) {
          return const PdfOpenResult.error('Permission denied to open the saved file.');
        } else {
          return PdfOpenResult.error('Could not open file: ${result.message}');
        }
      }
    } catch (e) {
      return PdfOpenResult.error('Error opening document: $e');
    }
  }

  @visibleForTesting
  Future<void> clearAllForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPdfMetadataKey);
    _pdfs = [];
    _isProcessingLock = false;
    _isInitialized = true;
    notifyListeners();
  }
}
