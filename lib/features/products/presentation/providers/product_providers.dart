import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/exchange_rate/presentation/providers/exchange_rate_providers.dart';
import 'package:cajafacil/features/products/data/product_repository_impl.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/repositories/product_repository.dart';
import 'package:cajafacil/features/settings/domain/business_profile.dart';
import 'package:cajafacil/features/settings/presentation/settings_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'product_providers.g.dart';

@Riverpod(keepAlive: true)
StockLedger stockLedger(Ref ref) => StockLedger(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) => ProductRepositoryImpl(
  ref.watch(appDatabaseProvider),
  ref.watch(stockLedgerProvider),
);

@riverpod
Stream<List<Product>> products(Ref ref, ProductFilter filter) =>
    ref.watch(productRepositoryProvider).watchProducts(filter);

@riverpod
Stream<Product?> product(Ref ref, String id) =>
    ref.watch(productRepositoryProvider).watchById(id);

@Riverpod(keepAlive: true)
Stream<List<Category>> categories(Ref ref) =>
    ref.watch(productRepositoryProvider).watchCategories();

/// Tasa vigente + redondeo del negocio: todo lo necesario para mostrar
/// precios en CUP.
class PricingContext {
  const PricingContext({required this.rate, required this.rounding});

  final ExchangeRate? rate;
  final CupRounding rounding;

  Money? cupFor(Product product) => product.priceCup(rate, rounding);
}

@riverpod
PricingContext pricingContext(Ref ref) {
  final rate = ref.watch(currentRateProvider).value?.rate;
  final profile =
      ref.watch(businessProfileProvider).value ?? BusinessProfile.fallback;
  return PricingContext(rate: rate, rounding: profile.cupRounding);
}
