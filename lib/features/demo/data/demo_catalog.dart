import 'package:cajafacil/core/domain/enums.dart';

/// Catálogo de ejemplo de "Mini-mercado La Esquina, Playa".
///
/// Precios en USD de referencia de mipymes habaneras. Algunos productos
/// tienen precio fijo en CUP (modo manual) y otros arrancan con poco stock
/// para que el reporte de "bajo stock" no salga vacío.
class DemoCategory {
  const DemoCategory(this.key, this.name, this.iconKey, this.color);

  final String key;
  final String name;
  final String iconKey;
  final int color;
}

class DemoProduct {
  const DemoProduct(
    this.name,
    this.category,
    this.unit,
    this.costCents,
    this.priceCents,
    this.stock,
    this.minStock, {
    this.manualCupPesos,
  });

  final String name;
  final String category;
  final ProductUnit unit;
  final int costCents;
  final int priceCents;

  /// En unidades enteras de la unidad de medida (se convierten a milésimas).
  final num stock;
  final num minStock;
  final int? manualCupPesos;
}

abstract final class DemoCatalog {
  static const categories = [
    DemoCategory('grains', 'Granos y cereales', 'grains', 0xFF8D6E63),
    DemoCategory('oil', 'Aceites y grasas', 'oil', 0xFFF9A825),
    DemoCategory('meat', 'Cárnicos', 'meat', 0xFFC62828),
    DemoCategory('dairy', 'Lácteos y huevos', 'dairy', 0xFF6D4C41),
    DemoCategory('drinks', 'Bebidas', 'drinks', 0xFF1565C0),
    DemoCategory('beer', 'Cervezas y licores', 'beer', 0xFFEF6C00),
    DemoCategory('canned', 'Conservas y salsas', 'canned', 0xFFAD1457),
    DemoCategory('snacks', 'Confituras', 'snacks', 0xFF6A1B9A),
    DemoCategory('cleaning', 'Aseo del hogar', 'cleaning', 0xFF00838F),
    DemoCategory('hygiene', 'Aseo personal', 'hygiene', 0xFF2E7D32),
  ];

  static const ProductUnit u = ProductUnit.unit;
  static const ProductUnit lb = ProductUnit.pound;
  static const ProductUnit paq = ProductUnit.pack;
  static const ProductUnit caja = ProductUnit.box;

  static const products = [
    // Granos y cereales
    DemoProduct('Arroz 1 kg', 'grains', paq, 160, 220, 80, 20),
    DemoProduct('Arroz a granel', 'grains', lb, 70, 95, 150, 40),
    DemoProduct('Frijoles negros 1 kg', 'grains', paq, 240, 320, 45, 15),
    DemoProduct('Frijoles colorados 500 g', 'grains', paq, 140, 190, 30, 10),
    DemoProduct('Chícharos 500 g', 'grains', paq, 100, 140, 35, 10),
    DemoProduct('Espaguetis 500 g', 'grains', paq, 90, 130, 60, 20),
    DemoProduct('Coditos 500 g', 'grains', paq, 90, 130, 40, 15),
    DemoProduct('Harina de trigo 1 kg', 'grains', paq, 130, 180, 25, 10),
    DemoProduct('Azúcar blanca 1 kg', 'grains', paq, 150, 200, 50, 15),
    DemoProduct('Azúcar morena a granel', 'grains', lb, 55, 80, 8, 20),
    DemoProduct('Café Cubita 250 g', 'grains', paq, 320, 450, 24, 8),
    DemoProduct('Café Serrano 250 g', 'grains', paq, 280, 380, 18, 8),
    DemoProduct('Sal común 1 kg', 'grains', paq, 50, 80, 30, 10),
    // Aceites y grasas
    DemoProduct('Aceite de soya 1 L', 'oil', u, 260, 350, 6, 12),
    DemoProduct('Aceite de girasol 900 ml', 'oil', u, 290, 390, 20, 8),
    DemoProduct('Manteca de cerdo 1 lb', 'oil', paq, 180, 250, 15, 5),
    // Cárnicos
    DemoProduct('Muslo de pollo', 'meat', lb, 110, 150, 120, 30),
    DemoProduct('Caja de pollo 15 kg', 'meat', caja, 2200, 2800, 6, 2),
    DemoProduct('Picadillo de pollo 400 g', 'meat', paq, 90, 140, 40, 10),
    DemoProduct('Salchichas de pollo (10 u)', 'meat', paq, 160, 230, 35, 10),
    DemoProduct('Jamonada', 'meat', lb, 180, 260, 20, 8),
    DemoProduct('Hamburguesas de res (6 u)', 'meat', paq, 320, 450, 12, 5),
    DemoProduct('Lomo de cerdo', 'meat', lb, 240, 320, 30, 10),
    // Lácteos y huevos
    DemoProduct('Huevos (cartón de 30)', 'dairy', paq, 650, 850, 4, 6),
    DemoProduct('Leche en polvo entera 1 kg', 'dairy', paq, 680, 900, 14, 5),
    DemoProduct('Yogurt natural 1 L', 'dairy', u, 150, 220, 18, 6),
    DemoProduct('Queso gouda', 'dairy', lb, 380, 520, 10, 4),
    DemoProduct('Mantequilla 250 g', 'dairy', u, 170, 240, 12, 4),
    // Bebidas
    DemoProduct('Malta Bucanero 355 ml', 'drinks', u, 55, 85, 96, 24),
    DemoProduct(
      'Refresco de cola Ciego Montero (lata)',
      'drinks',
      u,
      45,
      70,
      120,
      24,
    ),
    DemoProduct(
      'Refresco de limón Ciego Montero 1.5 L',
      'drinks',
      u,
      110,
      160,
      30,
      10,
    ),
    DemoProduct('Jugo de mango 1 L', 'drinks', u, 130, 190, 24, 8),
    DemoProduct(
      'Agua mineral Ciego Montero 1.5 L',
      'drinks',
      u,
      60,
      95,
      48,
      12,
    ),
    DemoProduct('Néctar de guayaba 200 ml', 'drinks', u, 40, 65, 60, 20),
    DemoProduct(
      'Refresco instantáneo (sobre)',
      'drinks',
      u,
      15,
      30,
      100,
      30,
      manualCupPesos: 120,
    ),
    // Cervezas y licores
    DemoProduct('Cerveza Cristal (lata)', 'beer', u, 65, 100, 20, 48),
    DemoProduct('Cerveza Bucanero (lata)', 'beer', u, 70, 105, 140, 48),
    DemoProduct(
      'Cerveza Cristal (caja 24 latas)',
      'beer',
      caja,
      1500,
      2200,
      8,
      3,
    ),
    DemoProduct(
      'Ron Havana Club Añejo 3 Años 700 ml',
      'beer',
      u,
      650,
      900,
      12,
      4,
    ),
    DemoProduct('Ron Santiago Añejo 700 ml', 'beer', u, 600, 850, 10, 4),
    DemoProduct('Ron Mulata Carta Blanca 700 ml', 'beer', u, 450, 650, 10, 4),
    // Conservas y salsas
    DemoProduct('Puré de tomate 400 g', 'canned', u, 90, 140, 40, 12),
    DemoProduct('Salsa condimentada 250 g', 'canned', u, 70, 110, 25, 8),
    DemoProduct('Atún en aceite 160 g', 'canned', u, 140, 200, 30, 10),
    DemoProduct('Sardinas en tomate 125 g', 'canned', u, 90, 130, 36, 12),
    DemoProduct('Mayonesa 450 g', 'canned', u, 180, 260, 15, 6),
    DemoProduct('Leche condensada 397 g', 'canned', u, 140, 200, 28, 10),
    // Confituras
    DemoProduct('Galletas María (paquete)', 'snacks', paq, 60, 95, 50, 15),
    DemoProduct('Galletas de soda (paquete)', 'snacks', paq, 70, 105, 45, 15),
    DemoProduct('Chocolate en barra 100 g', 'snacks', u, 100, 150, 24, 8),
    DemoProduct('Mermelada de guayaba 500 g', 'snacks', u, 110, 160, 16, 6),
    DemoProduct(
      'Mariquitas de plátano 100 g',
      'snacks',
      paq,
      50,
      80,
      40,
      12,
      manualCupPesos: 350,
    ),
    // Aseo del hogar
    DemoProduct('Detergente en polvo 1 kg', 'cleaning', paq, 200, 280, 30, 10),
    DemoProduct('Jabón de lavar (barra)', 'cleaning', u, 45, 70, 60, 20),
    DemoProduct('Lavaplatos líquido 500 ml', 'cleaning', u, 110, 160, 20, 8),
    DemoProduct('Cloro 1 L', 'cleaning', u, 80, 120, 3, 8),
    // Aseo personal
    DemoProduct(
      'Jabón de tocador',
      'hygiene',
      u,
      50,
      80,
      70,
      20,
      manualCupPesos: 350,
    ),
    DemoProduct('Pasta dental 75 ml', 'hygiene', u, 90, 140, 30, 10),
    DemoProduct('Champú 400 ml', 'hygiene', u, 220, 310, 14, 5),
    DemoProduct('Papel higiénico (4 rollos)', 'hygiene', paq, 160, 230, 25, 10),
  ];

  /// EAN-13 con prefijo GS1 de Cuba (850) y dígito de control válido.
  static String barcodeFor(int index) {
    final base = '8501234${(index + 1).toString().padLeft(5, '0')}';
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(base[i]) * (i.isEven ? 1 : 3);
    }
    return '$base${(10 - sum % 10) % 10}';
  }
}
