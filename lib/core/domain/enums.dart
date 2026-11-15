/// Enumeraciones del dominio compartidas entre features y persistencia.
///
/// Se guardan en la BD por su `name`, así que **no renombre** valores
/// existentes sin una migración.
library;

import 'package:cajafacil/core/money/currency.dart';

enum UserRole {
  owner('Dueño'),
  manager('Encargado'),
  cashier('Cajero');

  const UserRole(this.label);

  final String label;
}

enum ProductUnit {
  unit('u', 'Unidad', allowsFraction: false),
  pound('lb', 'Libra', allowsFraction: true),
  kilogram('kg', 'Kilogramo', allowsFraction: true),
  liter('L', 'Litro', allowsFraction: true),
  pack('paq', 'Paquete', allowsFraction: false),
  box('caja', 'Caja', allowsFraction: false);

  const ProductUnit(this.symbol, this.label, {required this.allowsFraction});

  final String symbol;
  final String label;
  final bool allowsFraction;
}

/// Cómo se obtiene el precio en CUP de un producto.
enum CupPriceMode {
  /// Precio USD x tasa del día (redondeado).
  auto('Calculado con la tasa'),

  /// Precio fijo en CUP definido por el administrador.
  manual('Precio fijo');

  const CupPriceMode(this.label);

  final String label;
}

enum StockMovementType {
  initial('Inventario inicial'),
  purchase('Entrada de mercancía'),
  sale('Venta'),
  saleVoid('Venta anulada'),
  adjustment('Ajuste');

  const StockMovementType(this.label);

  final String label;
}

enum AdjustmentReason {
  waste('Merma'),
  breakage('Rotura'),
  internalUse('Consumo interno'),
  theft('Robo'),
  recount('Conteo físico');

  const AdjustmentReason(this.label);

  final String label;
}

enum CashSessionStatus { open, closed }

enum CashMovementType {
  cashIn('Entrada de efectivo'),
  cashOut('Salida de efectivo');

  const CashMovementType(this.label);

  final String label;
}

enum SaleStatus { completed, voided }

enum DiscountType {
  percent('%'),
  amount('Monto');

  const DiscountType(this.label);

  final String label;
}

enum PaymentMethod {
  cashUsd('Efectivo USD', isCash: true, defaultCurrency: Currency.usd),
  cashCup('Efectivo CUP', isCash: true, defaultCurrency: Currency.cup),
  transfer('Transferencia', isCash: false, defaultCurrency: Currency.cup),
  transfermovil('Transfermóvil', isCash: false, defaultCurrency: Currency.cup),
  enzona('EnZona', isCash: false, defaultCurrency: Currency.cup);

  const PaymentMethod(
    this.label, {
    required this.isCash,
    required this.defaultCurrency,
  });

  final String label;

  /// Solo el efectivo cuenta para el cuadre físico de la caja.
  final bool isCash;
  final Currency defaultCurrency;
}

enum SyncOp { upsert, delete }

enum OutboxStatus { pending, sent, failed }
