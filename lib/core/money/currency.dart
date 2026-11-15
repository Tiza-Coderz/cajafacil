/// Monedas soportadas por el negocio.
///
/// El precio base de todo producto es USD; CUP se obtiene con la tasa del día.
enum Currency {
  usd(code: 'USD', label: 'Dólar (USD)'),
  cup(code: 'CUP', label: 'Peso cubano (CUP)');

  const Currency({required this.code, required this.label});

  final String code;
  final String label;

  static Currency fromCode(String code) =>
      Currency.values.firstWhere((c) => c.code == code.toUpperCase());
}
