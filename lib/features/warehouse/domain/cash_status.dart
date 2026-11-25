/// Estado del cierre de caja (columna `cash_closing_status` de la base).
enum CashStatus {
  open('open', 'Sin enviar a Jime'),
  sent('sent', 'Enviado a Jime'),
  validated('validated', 'Validado'),
  observed('observed', 'Con observaciones');

  const CashStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static CashStatus fromApi(String value) => values.firstWhere((s) => s.apiValue == value);
}
