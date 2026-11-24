import '../money/money.dart';

typedef Json = Map<String, dynamic>;

/// Lectores cortos para armar modelos desde la respuesta del backend.
extension JsonReaders on Json {
  String str(String key) => this[key] as String;
  String? strOrNull(String key) => this[key] as String?;

  int integer(String key) => (this[key] as num).toInt();
  int? integerOrNull(String key) => (this[key] as num?)?.toInt();

  bool flag(String key, {bool orElse = false}) => (this[key] as bool?) ?? orElse;

  Money money(String key) => Money.fromJson(this[key]);
  Money? moneyOrNull(String key) =>
      this[key] == null ? null : Money.fromJson(this[key]);

  /// Tasa como número (`0.40`) o como texto (`"0.40"`).
  double rate(String key) => switch (this[key]) {
        num n => n.toDouble(),
        String s => double.parse(s),
        final other => throw FormatException('Tasa inválida: $other'),
      };

  DateTime date(String key) => DateTime.parse(this[key] as String);
  DateTime? dateOrNull(String key) {
    final raw = this[key] as String?;
    return raw == null ? null : DateTime.parse(raw);
  }

  Json obj(String key) => Map<String, dynamic>.from(this[key] as Map);
  Json? objOrNull(String key) {
    final raw = this[key];
    return raw == null ? null : Map<String, dynamic>.from(raw as Map);
  }

  List<Json> list(String key) => [
        for (final item in (this[key] as List? ?? const []))
          Map<String, dynamic>.from(item as Map),
      ];
}
