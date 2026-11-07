import 'dart:convert';
import 'dart:math';

import 'gesture_password_hasher.dart';

class GestureCredentials {
  static Map<String, dynamic>? decode(String? raw) {
    if (raw == null) return null;
    final saved = jsonDecode(raw) as Map<String, dynamic>;
    if (saved['version'] != 1 ||
        base64Decode(saved['salt'] as String).length != 32 ||
        base64Decode(saved['a'] as String).length != 32 ||
        base64Decode(saved['b'] as String).length != 32 ||
        saved['a'] == saved['b']) {
      throw const FormatException('Invalid gesture credentials');
    }
    return saved;
  }

  static Future<Map<String, dynamic>> create(
    List<int> a,
    List<int> b,
    GesturePasswordHasher hasher,
  ) async {
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    return {
      'version': 1,
      'salt': base64Encode(salt),
      'a': await hasher.hash(a, salt),
      'b': await hasher.hash(b, salt),
    };
  }
}
