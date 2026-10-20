import 'dart:typed_data';

class PdfWebStorageImpl {
  Future<bool> savePdf(String key, Uint8List bytes) async => false;
  Future<Uint8List?> getPdf(String key) async => null;
  Future<bool> deletePdf(String key) async => false;
  Future<bool> hasPdf(String key) async => false;
  void openPdf(Uint8List bytes, String fileName) {}
}
