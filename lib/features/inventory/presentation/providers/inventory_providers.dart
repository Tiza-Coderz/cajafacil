import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/features/inventory/data/inventory_repository_impl.dart';
import 'package:cajafacil/features/inventory/domain/entities/inventory_entities.dart';
import 'package:cajafacil/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inventory_providers.g.dart';

@Riverpod(keepAlive: true)
InventoryRepository inventoryRepository(Ref ref) => InventoryRepositoryImpl(
  ref.watch(appDatabaseProvider),
  ref.watch(stockLedgerProvider),
);

@riverpod
Stream<List<Supplier>> suppliers(Ref ref) =>
    ref.watch(inventoryRepositoryProvider).watchSuppliers();

@riverpod
Stream<List<PurchaseSummary>> purchases(Ref ref) =>
    ref.watch(inventoryRepositoryProvider).watchPurchases();

@riverpod
Stream<List<KardexEntry>> kardex(Ref ref, String productId) =>
    ref.watch(inventoryRepositoryProvider).watchKardex(productId);
