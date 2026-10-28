import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'app_log.dart';

const _log = AppLog('ImageDecryptor');

class ImageDecryptor {
  static final _keyHex = 'f5d965df75336270';
  static final _ivHex = '97b60394abc2fbe1';

  late final encrypt.Key _key;
  late final encrypt.IV _iv;

  ImageDecryptor() {
    _key = encrypt.Key.fromUtf8(_keyHex);
    _iv = encrypt.IV.fromUtf8(_ivHex);
    _log.d(
      'initialized: keyLen=${_key.bytes.length}, ivLen=${_iv.bytes.length}',
    );
  }

  /// Decrypt cover image bytes
  Uint8List decrypt(Uint8List raw) {
    _log.d('decrypt: raw=${raw.length} bytes');

    if (raw.isEmpty) {
      _log.w('decrypt: empty input, returning as-is');
      return raw;
    }

    if (raw.length % 16 != 0) {
      _log.d(
        'decrypt: length not multiple of 16 (${raw.length}), returning as-is',
      );
      return raw;
    }

    final encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
    );

    Uint8List decrypted;
    try {
      final encrypted = encrypt.Encrypted(raw);
      decrypted = Uint8List.fromList(
        encrypter.decryptBytes(encrypted, iv: _iv),
      );
      _log.d('decrypt: AES-CBC done, ${decrypted.length} bytes');
    } catch (e, stack) {
      _log.e('decrypt: AES failed, returning original', e, stack);
      return raw;
    }

    if (!_hasImageSignature(decrypted)) {
      _log.d('decrypt: no image signature, returning original');
      return raw;
    }

    _log.d('decrypt: valid image signature detected');

    decrypted = _stripPkcs7(decrypted);
    _log.d('decrypt: after PKCS7 strip: ${decrypted.length} bytes');

    decrypted = _trimToImageEnd(decrypted);
    _log.d('decrypt: after trim: ${decrypted.length} bytes');

    return decrypted;
  }

  bool _hasImageSignature(Uint8List data) {
    if (data.length < 4) return false;

    // JPEG
    if (data[0] == 0xff && data[1] == 0xd8) {
      _log.d('signature: JPEG');
      return true;
    }
    // PNG
    if (data.length >= 8 &&
        data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4e &&
        data[3] == 0x47) {
      _log.d('signature: PNG');
      return true;
    }
    // WEBP
    if (data.length >= 12 &&
        data[0] == 0x52 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x46 &&
        data[8] == 0x57 &&
        data[9] == 0x45 &&
        data[10] == 0x42 &&
        data[11] == 0x50) {
      _log.d('signature: WEBP');
      return true;
    }
    // GIF
    if (data.length >= 6 &&
        data[0] == 0x47 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x38) {
      _log.d('signature: GIF');
      return true;
    }

    _log.d(
      'signature: unknown, first bytes: ${data.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    return false;
  }

  Uint8List _stripPkcs7(Uint8List data) {
    if (data.isEmpty) return data;
    final pad = data.last;
    if (pad > 0 && pad <= 16 && pad <= data.length) {
      bool valid = true;
      for (int i = data.length - pad; i < data.length; i++) {
        if (data[i] != pad) {
          valid = false;
          break;
        }
      }
      if (valid) {
        _log.d('PKCS7: stripped $pad bytes');
        return Uint8List.sublistView(data, 0, data.length - pad);
      }
    }
    return data;
  }

  Uint8List _trimToImageEnd(Uint8List data) {
    if (data.length < 4) return data;
    final isJpeg = data[0] == 0xff && data[1] == 0xd8;
    final isPng =
        data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4e &&
        data[3] == 0x47;
    // JPEG: last \xff\xd9
    int jpegEnd = -1;
    for (int i = isJpeg ? data.length - 2 : -1; i >= 0; i--) {
      if (data[i] == 0xff && data[i + 1] == 0xd9) {
        jpegEnd = i + 2;
        break;
      }
    }
    if (jpegEnd > 0 && jpegEnd < data.length) {
      _log.d('trim: JPEG end at $jpegEnd (was ${data.length})');
      return Uint8List.sublistView(data, 0, jpegEnd);
    }

    // PNG: IEND chunk
    for (int i = isPng ? data.length - 8 : -1; i >= 0; i--) {
      if (data[i] == 0x49 &&
          data[i + 1] == 0x45 &&
          data[i + 2] == 0x4e &&
          data[i + 3] == 0x44) {
        _log.d('trim: PNG IEND at ${i + 8} (was ${data.length})');
        return Uint8List.sublistView(data, 0, i + 8);
      }
    }

    return data;
  }
}
