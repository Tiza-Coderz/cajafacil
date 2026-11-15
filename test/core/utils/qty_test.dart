import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('format quita ceros sobrantes', () {
    expect(Qty.format(12000, ProductUnit.unit), '12 u');
    expect(Qty.format(1500, ProductUnit.pound), '1.5 lb');
    expect(Qty.format(250, ProductUnit.kilogram), '0.25 kg');
    expect(Qty.format(-2000, ProductUnit.unit), '-2 u');
  });

  test('parse con coma o punto', () {
    expect(Qty.parse('1,5', allowFraction: true), 1500);
    expect(Qty.parse('0.250', allowFraction: true), 250);
    expect(Qty.parse('3', allowFraction: false), 3000);
  });

  test('parse rechaza fracciones en unidades enteras', () {
    expect(Qty.parse('1.5', allowFraction: false), isNull);
    expect(Qty.parse('2.0', allowFraction: false), 2000);
  });

  test('parse rechaza texto y negativos', () {
    expect(Qty.parse('abc', allowFraction: true), isNull);
    expect(Qty.parse('-1', allowFraction: true), isNull);
    expect(Qty.parse('1.2345', allowFraction: true), isNull);
  });
}
