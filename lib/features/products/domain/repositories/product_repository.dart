import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:meta/meta.dart';

class DuplicateBarcodeException implements Exception {
  const DuplicateBarcodeException(this.existingProductName);

  final String existingProductName;

  @override
  String toString() => 'El código de barras ya lo usa "$existingProductName".';
}

/// Filtros del listado de productos (clave de la familia de providers).
@immutable
class ProductFilter {
  const ProductFilter({
    this.query = '',
    this.categoryId,
    this.lowStockOnly = false,
    this.includeInactive = false,
  });

  final String query;
  final String? categoryId;
  final bool lowStockOnly;
  final bool includeInactive;

  @override
  bool operator ==(Object other) =>
      other is ProductFilter &&
      other.query == query &&
      other.categoryId == categoryId &&
      other.lowStockOnly == lowStockOnly &&
      other.includeInactive == includeInactive;

  @override
  int get hashCode =>
      Object.hash(query, categoryId, lowStockOnly, includeInactive);
}

abstract interface class ProductRepository {
  Stream<List<Product>> watchProducts([ProductFilter filter]);

  Stream<Product?> watchById(String id);

  Future<Product?> getById(String id);

  /// Solo productos activos y no borrados.
  Future<Product?> findByBarcode(String barcode);

  /// Crea (si `draft.id` es null) o actualiza. Lanza
  /// [DuplicateBarcodeException] si el código ya existe en otro producto.
  Future<Product> save(ProductDraft draft, {required String userId});

  Future<void> setActive(String id, {required bool active});

  Stream<List<Category>> watchCategories();

  Future<Category> createCategory(String name, {String iconKey, int? color});
}
