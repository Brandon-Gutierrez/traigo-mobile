import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el token de sesión. La sesión dura hasta que la persona cierre
/// sesión o se revoque el token en el servidor (decisión de producto).
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Guarda el token cifrado en el almacén seguro del sistema
/// (Keystore en Android, Keychain en iOS).
class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  static const _key = 'auth_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Para pruebas: no toca el sistema.
class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
