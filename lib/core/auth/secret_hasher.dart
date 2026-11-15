import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash de PIN y contraseñas con PBKDF2-HMAC-SHA256 y sal por usuario.
///
/// Implementado sobre `package:crypto` para funcionar igual en Android y
/// Web sin dependencias nativas. Las iteraciones se mantienen moderadas
/// porque en Web el hash corre en JavaScript.
class SecretHasher {
  const SecretHasher({this.iterations = 4096});

  final int iterations;

  static const _keyLength = 32;
  static const _saltLength = 16;

  String newSalt([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(_saltLength, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  String hash(String secret, String salt) => base64Encode(
    pbkdf2(utf8.encode(secret), base64Decode(salt), iterations, _keyLength),
  );

  /// Comparación en tiempo constante para no filtrar información.
  bool verify(String secret, String salt, String expectedHash) {
    final actual = base64Decode(hash(secret, salt));
    final expected = base64Decode(expectedHash);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// PBKDF2 (RFC 8018) con HMAC-SHA256.
  static Uint8List pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int length,
  ) {
    final hmac = Hmac(sha256, password);
    final blocks = (length / 32).ceil();
    final output = BytesBuilder(copy: false);
    for (var i = 1; i <= blocks; i++) {
      var u = hmac.convert([
        ...salt,
        (i >> 24) & 0xff,
        (i >> 16) & 0xff,
        (i >> 8) & 0xff,
        i & 0xff,
      ]).bytes;
      final block = Uint8List.fromList(u);
      for (var j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < block.length; k++) {
          block[k] ^= u[k];
        }
      }
      output.add(block);
    }
    return Uint8List.sublistView(output.takeBytes(), 0, length);
  }
}

/// Reglas de formato del PIN.
abstract final class PinRules {
  static const length = 4;

  static String? validate(String pin) {
    if (!RegExp(r'^\d+$').hasMatch(pin)) return 'El PIN solo lleva números';
    if (pin.length != length) return 'El PIN debe tener $length dígitos';
    return null;
  }
}
