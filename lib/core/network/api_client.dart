import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'json.dart';
import 'upload_file.dart';

export 'json.dart';
export 'upload_file.dart';

/// Cliente HTTP de la app. Todo error sale como [ApiException].
class ApiClient {
  ApiClient(this._dio);

  /// Cliente real contra Laravel: agrega el token y avisa si vence.
  factory ApiClient.create({
    required AppConfig config,
    required TokenStorage tokens,
    required void Function() onUnauthorized,
    HttpClientAdapter? httpClientAdapter,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Accept-Language': 'es',
        },
      ),
    );
    if (httpClientAdapter != null) dio.httpClientAdapter = httpClientAdapter;
    dio.interceptors.add(_AuthInterceptor(tokens, onUnauthorized));
    return ApiClient(dio);
  }

  final Dio _dio;

  Future<Json> get(String path, {Json? query}) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query));

  Future<Json> post(
    String path, {
    Object? body,
    String? idempotencyKey,
  }) =>
      _send(
        () => _dio.post<Object?>(
          path,
          data: body,
          options: _options(idempotencyKey),
        ),
      );

  Future<Json> postMultipart(
    String path, {
    required Map<String, Object?> fields,
    UploadFile? file,
    String fileField = 'file',
    String? idempotencyKey,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      for (final entry in fields.entries)
        if (entry.value != null) entry.key: entry.value,
      if (file != null)
        fileField: await MultipartFile.fromFile(file.path, filename: file.filename),
    });
    return _send(
      () => _dio.post<Object?>(
        path,
        data: form,
        options: _options(idempotencyKey),
        onSendProgress: onProgress,
      ),
    );
  }

  /// Una acción sin respuesta (`204`).
  Future<void> postNoContent(String path, {Object? body}) async {
    try {
      await _dio.post<Object?>(path, data: body);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Descarga un archivo (los reportes de Excel).
  Future<List<int>> download(String path, {Json? query}) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      throw ApiException.fromDio(_decodeBytesError(e));
    }
  }

  /// En una descarga, el mensaje de error también llega como bytes.
  static DioException _decodeBytesError(DioException error) {
    final data = error.response?.data;
    if (data is List<int>) {
      try {
        error.response!.data = jsonDecode(utf8.decode(data));
      } on FormatException {
        error.response!.data = null;
      }
    }
    return error;
  }

  Options? _options(String? idempotencyKey) => idempotencyKey == null
      ? null
      : Options(headers: {'Idempotency-Key': idempotencyKey});

  Future<Json> _send(Future<Response<Object?>> Function() call) async {
    try {
      final response = await call();
      final data = response.data;
      if (data is Json) return data;
      return const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokens, this._onUnauthorized);

  final TokenStorage _tokens;
  final void Function() _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Los pasos del ingreso (login y verificación) responden 401 o 422 sin
    // que haya una sesión que cerrar.
    final path = err.requestOptions.path;
    final isSignIn = path.contains('/auth/login') || path.contains('/auth/two-factor');
    if (err.response?.statusCode == 401 && !isSignIn) {
      _onUnauthorized();
    }
    handler.next(err);
  }
}
