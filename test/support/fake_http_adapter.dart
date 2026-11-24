import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:traigo/core/config/app_config.dart';
import 'package:traigo/core/network/api_client.dart';
import 'package:traigo/core/storage/token_storage.dart';

typedef _Responder = ResponseBody Function(RequestOptions options);

/// Servidor HTTP falso: devuelve en orden las respuestas preparadas y guarda
/// cada petición recibida para poder revisarla.
class FakeHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<_Responder> _queue = [];

  RequestOptions get last => requests.last;

  void reply(int status, Object body, {Map<String, List<String>>? headers}) {
    _queue.add((_) => ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            ...?headers,
          },
        ));
  }

  /// Simula que no hay conexión (sin internet o servidor caído).
  void failConnection() {
    _queue.add((options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'sin conexión',
        ));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_queue.isEmpty) {
      throw StateError('No hay respuesta preparada para ${options.method} ${options.path}');
    }
    return _queue.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Cliente real de la app apuntando al servidor falso.
class ApiHarness {
  ApiHarness({String? token = 'tok'})
      : tokens = MemoryTokenStorage(token),
        adapter = FakeHttpAdapter() {
    api = ApiClient.create(
      config: const AppConfig(mode: DataMode.live, baseUrl: 'http://test.local/api/v1'),
      tokens: tokens,
      onUnauthorized: () => unauthorizedCalls++,
      httpClientAdapter: adapter,
    );
  }

  final MemoryTokenStorage tokens;
  final FakeHttpAdapter adapter;
  late final ApiClient api;
  int unauthorizedCalls = 0;
}
