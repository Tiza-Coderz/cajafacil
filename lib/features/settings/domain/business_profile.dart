import 'dart:typed_data';

import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_profile.freezed.dart';

/// Datos del negocio que aparecen en tickets, reportes y la cabecera.
@freezed
abstract class BusinessProfile with _$BusinessProfile {
  const factory BusinessProfile({
    required String name,
    @Default('') String address,
    @Default('') String nit,
    @Default('') String phone,
    @Default('') String whatsapp,
    @Default(Currency.cup) Currency primaryCurrency,
    @Default('¡Gracias por su compra!') String receiptFooter,
    @Default(CupRounding.five) CupRounding cupRounding,
    Uint8List? logo,
  }) = _BusinessProfile;

  static const fallback = BusinessProfile(name: 'Mi negocio');
}
