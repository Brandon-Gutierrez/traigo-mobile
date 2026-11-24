import 'package:dio/dio.dart';

/// Errores que la app sabe explicar al vendedor. Todo error de red o de
/// servidor se convierte en uno de estos antes de llegar a la pantalla.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  /// Texto listo para mostrar en pantalla (el backend responde en español).
  final String message;

  @override
  String toString() => '$runtimeType: $message';

  /// Traduce un error de Dio al contrato descrito en docs/api-contract.md.
  static ApiException fromDio(DioException error) {
    final response = error.response;
    if (response == null) return const NetworkException();

    final body = response.data;
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final message = (map['message'] as String?)?.trim();
    final code = map['code'] as String?;
    final status = response.statusCode ?? 0;

    switch (status) {
      case 401:
        return UnauthorizedException(message ?? 'Tu sesión terminó. Ingresa otra vez.');
      case 404:
        return NotFoundException(message ?? 'No encontramos lo que buscabas.');
      case 409:
        return ConflictException(
          code: code ?? 'conflict',
          message: message ?? 'La operación ya no es posible.',
          data: map['data'],
        );
      case 422:
        return ValidationException(
          message: message ?? 'Revisa los datos ingresados.',
          code: code,
          fieldErrors: _fieldErrors(map['errors']),
          data: map['data'],
        );
      case 429:
        final retry = int.tryParse(response.headers.value('retry-after') ?? '');
        return RateLimitedException(
          message ?? 'Demasiados intentos. Espera un momento.',
          retryAfterSeconds: retry,
        );
      default:
        return ServerException(
          message ?? 'El servidor tuvo un problema. Intenta de nuevo.',
          statusCode: status,
        );
    }
  }

  static Map<String, List<String>> _fieldErrors(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): [
          if (entry.value is List) ...(entry.value as List).map((e) => e.toString()),
          if (entry.value is String) entry.value as String,
        ],
    };
  }
}

/// Sin internet, servidor caído o tiempo agotado.
final class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.',
  ]);
}

/// 401: token vencido, revocado o PIN incorrecto.
final class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message);
}

final class NotFoundException extends ApiException {
  const NotFoundException(super.message);
}

/// 409: la operación choca con el estado actual. Ej: `insufficient_stock`,
/// `not_cancellable`. El detalle viaja en [data].
final class ConflictException extends ApiException {
  const ConflictException({required this.code, required String message, this.data})
      : super(message);

  final String code;
  final Object? data;
}

/// 422: datos inválidos. Ej: `price_below_minimum`.
final class ValidationException extends ApiException {
  const ValidationException({
    required String message,
    this.code,
    this.fieldErrors = const {},
    this.data,
  }) : super(message);

  final String? code;
  final Map<String, List<String>> fieldErrors;
  final Object? data;

  String? firstErrorFor(String field) {
    final list = fieldErrors[field];
    return (list == null || list.isEmpty) ? null : list.first;
  }
}

final class RateLimitedException extends ApiException {
  const RateLimitedException(super.message, {this.retryAfterSeconds});

  final int? retryAfterSeconds;
}

final class ServerException extends ApiException {
  const ServerException(super.message, {required this.statusCode});

  final int statusCode;
}
