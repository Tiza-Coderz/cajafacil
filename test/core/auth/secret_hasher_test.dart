import 'dart:convert';
import 'dart:math';

import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // Vectores de prueba públicos (RFC 7914 §11 / referencia PBKDF2-SHA256).
    test('password/salt, 1 iteración', () {
      final out = SecretHasher.pbkdf2(
        utf8.encode('password'),
        utf8.encode('salt'),
        1,
        32,
      );
      expect(
        _hex(out),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('password/salt, 2 iteraciones', () {
      final out = SecretHasher.pbkdf2(
        utf8.encode('password'),
        utf8.encode('salt'),
        2,
        32,
      );
      expect(
        _hex(out),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });
  });

  group('SecretHasher', () {
    const hasher = SecretHasher(iterations: 10);

    test('verifica el PIN correcto y rechaza uno incorrecto', () {
      final salt = hasher.newSalt(Random(1));
      final hash = hasher.hash('1234', salt);
      expect(hasher.verify('1234', salt, hash), isTrue);
      expect(hasher.verify('1235', salt, hash), isFalse);
    });

    test('la misma clave con distinta sal da distinto hash', () {
      final a = hasher.hash('1234', hasher.newSalt(Random(1)));
      final b = hasher.hash('1234', hasher.newSalt(Random(2)));
      expect(a, isNot(b));
    });
  });

  group('PinRules', () {
    test('acepta 4 dígitos', () => expect(PinRules.validate('0420'), isNull));
    test('rechaza letras', () => expect(PinRules.validate('12a4'), isNotNull));
    test('rechaza largo', () => expect(PinRules.validate('12345'), isNotNull));
  });
}
