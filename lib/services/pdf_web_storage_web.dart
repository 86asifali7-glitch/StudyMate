import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class PdfWebStorageImpl {
  static const String _dbName = 'study_mate_pdf_db';
  static const String _storeName = 'study_mate_pdfs';
  static const int _dbVersion = 1;

  web.IDBDatabase? _db;

  Future<web.IDBDatabase> _getDb() {
    if (_db != null) return Future.value(_db!);
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_dbName, _dbVersion);

    request.onupgradeneeded = ((web.IDBVersionChangeEvent event) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;

    request.onsuccess = ((web.Event event) {
      _db = request.result as web.IDBDatabase;
      completer.complete(_db!);
    }).toJS;

    request.onerror = ((web.Event event) {
      completer.completeError('Failed to open IndexedDB');
    }).toJS;

    return completer.future;
  }

  Future<bool> savePdf(String key, Uint8List bytes) async {
    try {
      final db = await _getDb();
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      final store = tx.objectStore(_storeName);
      final request = store.put(bytes.toJS, key.toJS);
      final completer = Completer<bool>();
      request.onsuccess = ((web.Event _) {
        completer.complete(true);
      }).toJS;
      request.onerror = ((web.Event _) {
        completer.complete(false);
      }).toJS;
      return await completer.future;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> getPdf(String key) async {
    try {
      final db = await _getDb();
      final tx = db.transaction(_storeName.toJS, 'readonly');
      final store = tx.objectStore(_storeName);
      final request = store.get(key.toJS);
      final completer = Completer<Uint8List?>();
      request.onsuccess = ((web.Event _) {
        final result = request.result;
        if (result != null && result.isA<JSUint8Array>()) {
          completer.complete((result as JSUint8Array).toDart);
        } else {
          completer.complete(null);
        }
      }).toJS;
      request.onerror = ((web.Event _) {
        completer.complete(null);
      }).toJS;
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deletePdf(String key) async {
    try {
      final db = await _getDb();
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      final store = tx.objectStore(_storeName);
      final request = store.delete(key.toJS);
      final completer = Completer<bool>();
      request.onsuccess = ((web.Event _) {
        completer.complete(true);
      }).toJS;
      request.onerror = ((web.Event _) {
        completer.complete(false);
      }).toJS;
      return await completer.future;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPdf(String key) async {
    try {
      final db = await _getDb();
      final tx = db.transaction(_storeName.toJS, 'readonly');
      final store = tx.objectStore(_storeName);
      final request = store.count(key.toJS);
      final completer = Completer<bool>();
      request.onsuccess = ((web.Event _) {
        final result = request.result;
        if (result != null && result.isA<JSNumber>()) {
          completer.complete((result as JSNumber).toDartInt > 0);
        } else {
          completer.complete(false);
        }
      }).toJS;
      request.onerror = ((web.Event _) {
        completer.complete(false);
      }).toJS;
      return await completer.future;
    } catch (_) {
      return false;
    }
  }

  void openPdf(Uint8List bytes, String fileName) {
    try {
      final jsArray = bytes.toJS;
      final blobParts = [jsArray].toJS;
      final options = web.BlobPropertyBag(type: 'application/pdf');
      final blob = web.Blob(blobParts, options);
      final url = web.URL.createObjectURL(blob);
      web.window.open(url, '_blank');
    } catch (_) {}
  }
}
