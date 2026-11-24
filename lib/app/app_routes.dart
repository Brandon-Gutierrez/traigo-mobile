/// Rutas de la app. En un archivo aparte para que las pantallas puedan
/// navegar sin depender del router completo.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
  static const waste = '/home/waste';
  static const catalog = '/catalog';
  static const sell = '/sell';
  static const orders = '/orders';
  static String order(String id) => '/orders/$id';
  static const stock = '/stock';
}
