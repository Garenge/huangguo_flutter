import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class GesturePasswordHasher {
  GesturePasswordHasher(int iterations)
    : _algorithm = Pbkdf2.hmacSha256(iterations: iterations, bits: 256);

  final Pbkdf2 _algorithm;

  Future<String> hash(List<int> pattern, List<int> salt) async {
    final key = await _algorithm.deriveKeyFromPassword(
      password: pattern.join(),
      nonce: salt,
    );
    return base64Encode(await key.extractBytes());
  }

  bool equal(String left, String right) {
    final a = base64Decode(left);
    final b = base64Decode(right);
    var difference = a.length ^ b.length;
    for (var i = 0; i < a.length && i < b.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
