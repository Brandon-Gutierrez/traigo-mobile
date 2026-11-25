import '../../../core/network/api_exception.dart';

/// El mensaje de un envío fallido. Sin conexión se puede reintentar sin miedo:
/// la clave contra duplicados no cambia mientras no cambie lo que se envía.
String submitErrorMessage(ApiException error) => error is NetworkException
    ? '${error.message} Puedes reintentar: no se enviará dos veces.'
    : error.message;
