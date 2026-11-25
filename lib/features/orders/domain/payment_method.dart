/// Formas de pago (columna `payment_method` de la base).
enum PaymentMethod {
  qr('qr', 'QR'),
  transfer('transfer', 'Transferencia'),
  cash('cash', 'Efectivo'),

  /// Solo en la tienda web, en una pasarela segura.
  card('card', 'Tarjeta');

  const PaymentMethod(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static PaymentMethod fromApi(String value) =>
      values.firstWhere((m) => m.apiValue == value);
}
