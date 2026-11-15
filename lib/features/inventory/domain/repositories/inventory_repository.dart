import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/features/inventory/domain/entities/inventory_entities.dart';

abstract interface class InventoryRepository {
  Stream<List<Supplier>> watchSuppliers();

  Future<Supplier> createSupplier({required String name, String? phone});

  /// Registra la entrada: suma existencias (kardex) y actualiza el costo
  /// de cada producto con promedio ponderado. Devuelve el id de la entrada.
  Future<String> registerPurchase(
    PurchaseDraft draft, {
    required String userId,
  });

  Stream<List<PurchaseSummary>> watchPurchases({int limit});

  /// Ajuste por merma, rotura, consumo, robo o conteo físico.
  /// [quantityMilli]: lo perdido, o lo contado si es conteo.
  /// Devuelve la nueva existencia.
  Future<int> adjust({
    required String productId,
    required AdjustmentReason reason,
    required int quantityMilli,
    required String userId,
    String? note,
  });

  Stream<List<KardexEntry>> watchKardex(String productId, {int limit});
}
