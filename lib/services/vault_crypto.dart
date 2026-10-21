import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class VaultCrypto {
  /// Generate cryptographically secure random salt encoded in Base64
  static String generateRandomSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Generate a 32-byte (256-bit) cryptographically secure master vault key
  static Uint8List generateMasterKey() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  /// Hash the PIN/password with a unique salt using multiple rounds of SHA-256
  static String hashPin(String pin, String salt) {
    List<int> bytes = utf8.encode('pin_hash:$salt:$pin:$salt');
    for (int i = 0; i < 2000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }

  /// Derive a 256-bit AES encryption key from user PIN and salt
  static Uint8List deriveKey(String pin, String salt) {
    List<int> bytes = utf8.encode('vault_aes_key:$salt:$pin:$salt');
    for (int i = 0; i < 2000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return Uint8List.fromList(bytes.sublist(0, 32));
  }

  /// Encrypt arbitrary bytes with AES-256-CBC, prepending a 16-byte random IV
  static Uint8List encryptBytes(Uint8List plainBytes, Uint8List keyBytes) {
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    final combined = Uint8List(16 + encrypted.bytes.length);
    combined.setRange(0, 16, iv.bytes);
    combined.setRange(16, combined.length, encrypted.bytes);
    return combined;
  }

  /// Decrypt bytes encrypted with [encryptBytes] by extracting IV and decrypting
  static Uint8List decryptBytes(Uint8List encryptedData, Uint8List keyBytes) {
    if (encryptedData.length < 16) {
      throw const FormatException('Corrupted or invalid encrypted payload');
    }
    final ivBytes = encryptedData.sublist(0, 16);
    final cipherBytes = encryptedData.sublist(16);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }
}
