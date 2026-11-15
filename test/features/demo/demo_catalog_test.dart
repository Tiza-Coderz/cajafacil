import 'package:cajafacil/features/demo/data/demo_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

bool _validEan13(String code) {
  if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    sum += int.parse(code[i]) * (i.isEven ? 1 : 3);
  }
  return sum % 10 == 0;
}

void main() {
  test('el catálogo demo tiene 60 productos', () {
    expect(DemoCatalog.products, hasLength(60));
  });

  test('todos los productos usan una categoría existente', () {
    final keys = DemoCatalog.categories.map((c) => c.key).toSet();
    for (final p in DemoCatalog.products) {
      expect(keys, contains(p.category), reason: p.name);
    }
  });

  test('precio mayor que costo en todos los productos', () {
    for (final p in DemoCatalog.products) {
      expect(p.priceCents, greaterThan(p.costCents), reason: p.name);
    }
  });

  test('los códigos EAN-13 son válidos, cubanos (850) y únicos', () {
    final codes = [
      for (var i = 0; i < DemoCatalog.products.length; i++)
        DemoCatalog.barcodeFor(i),
    ];
    expect(codes.every(_validEan13), isTrue);
    expect(codes.every((c) => c.startsWith('850')), isTrue);
    expect(codes.toSet(), hasLength(codes.length));
  });

  test('hay productos con bajo stock para el reporte', () {
    expect(
      DemoCatalog.products.where((p) => p.stock <= p.minStock),
      isNotEmpty,
    );
  });
}
