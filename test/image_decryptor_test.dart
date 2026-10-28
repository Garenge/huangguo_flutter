import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/image_decryptor.dart';

void main() {
  test(
    'PNG ciphertext retains embedded JPEG markers and its complete IEND',
    () {
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
        0,
        0,
        0,
        4,
        0x49,
        0x44,
        0x41,
        0x54,
        0xff,
        0xd9,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0x49,
        0x45,
        0x4e,
        0x44,
        0xae,
        0x42,
        0x60,
        0x82,
      ]);
      final cipher = encrypt.Encrypter(
        encrypt.AES(
          encrypt.Key.fromUtf8('f5d965df75336270'),
          mode: encrypt.AESMode.cbc,
        ),
      );
      final encrypted = cipher.encryptBytes(
        png,
        iv: encrypt.IV.fromUtf8('97b60394abc2fbe1'),
      );
      expect(ImageDecryptor().decrypt(encrypted.bytes), orderedEquals(png));
    },
  );
}
