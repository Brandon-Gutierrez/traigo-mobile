import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Último código de vendedor con el que se ingresó, para precargarlo en el
/// formulario. El código no es secreto (el PIN sí, y ese nunca se guarda).
abstract class LastCodeStorage {
  Future<String?> read();
  Future<void> write(String code);
}

class SecureLastCodeStorage implements LastCodeStorage {
  const SecureLastCodeStorage([this._storage = const FlutterSecureStorage()]);

  static const _key = 'last_seller_code';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String code) => _storage.write(key: _key, value: code);
}

/// Para pruebas.
class MemoryLastCodeStorage implements LastCodeStorage {
  MemoryLastCodeStorage([this._code]);

  String? _code;

  @override
  Future<String?> read() async => _code;

  @override
  Future<void> write(String code) async => _code = code;
}
